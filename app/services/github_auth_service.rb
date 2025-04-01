require 'net/http'
require 'json'

class GithubAuthService
  Result = Struct.new(:success, :user, :access_token, :refresh_token, :error, :status, keyword_init: true)

  GITHUB_AUTH_URI = 'https://github.com/login/oauth/authorize'.freeze
  GITHUB_TOKEN_URI = 'https://github.com/login/oauth/access_token'.freeze
  GITHUB_USER_URI = 'https://api.github.com/user'.freeze
  GITHUB_USER_EMAILS_URI = 'https://api.github.com/user/emails'.freeze

  class AuthenticationError < StandardError; end
  class TokenExchangeError < AuthenticationError; end
  class UserDataFetchError < AuthenticationError; end
  class UserCreationError < AuthenticationError; end
  class TokenGenerationError < AuthenticationError; end

  def initialize(code)
    @code = code.to_s.strip
    @client_id = ENV.fetch('GITHUB_CLIENT_ID') { raise "GITHUB_CLIENT_ID not set" }
    @client_secret = ENV.fetch('GITHUB_CLIENT_SECRET') { raise "GITHUB_CLIENT_SECRET not set" }
    @redirect_uri = ENV.fetch('GITHUB_CALLBACK_URL', 'http://localhost:3000/api/v1/github_auth/callback')
    Rails.logger.debug "GitHub Auth init - client_id: #{@client_id}, redirect_uri: #{@redirect_uri}"
  end

  def authenticate
    validate_code_presence
    token_response = exchange_code_for_token
    user_data = fetch_user_data(token_response[:access_token])
    user = find_or_create_user(user_data[:data]) # FIXED: Pass the inner hash
    tokens = generate_tokens(user)

    Result.new(
      success: true,
      user: user,
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token],
      status: :ok
    )
  rescue AuthenticationError => e
    log_error(e)
    Result.new(
      success: false,
      error: e.message,
      status: :unauthorized
    )
  rescue StandardError => e
    log_error(e, "Unexpected error during GitHub authentication")
    Result.new(
      success: false,
      error: 'Internal authentication error',
      status: :internal_server_error
    )
  end

  private

  def validate_code_presence
    return unless @code.empty?
    raise TokenExchangeError, "No authorization code provided"
  end

  def exchange_code_for_token
    uri = URI(GITHUB_TOKEN_URI)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Accept'] = 'application/json'
    request.set_form_data({
      client_id: @client_id,
      client_secret: @client_secret,
      code: @code,
      redirect_uri: @redirect_uri
    })

    response = http.request(request)
    Rails.logger.debug "GitHub token response: #{response.body}"
    handle_token_response(response)
  rescue Timeout::Error, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
    raise TokenExchangeError, "GitHub connection failed: #{e.message}"
  end

  def handle_token_response(response)
    body = parse_json_response(response.body)

    if response.is_a?(Net::HTTPSuccess)
      access_token = body['access_token']
      raise TokenExchangeError, "Missing access token in response" unless access_token

      Rails.logger.info "GitHub access token received successfully"
      { success: true, access_token: access_token }
    else
      error_message = body['error_description'] || body['error'] || "Token exchange failed with status #{response.code}"
      log_error("GitHub token exchange failed", error_message)
      raise TokenExchangeError, error_message
    end
  end

  def fetch_user_data(access_token)
    user_info = fetch_from_github(GITHUB_USER_URI, access_token)
    user_emails = fetch_from_github(GITHUB_USER_EMAILS_URI, access_token)

    primary_email = find_primary_email(user_emails)
    user_info['verified_email'] = primary_email || user_info['email']
    Rails.logger.info "GitHub user data: #{user_info.inspect}, emails: #{user_emails.inspect}"
    { success: true, data: user_info }
  rescue StandardError => e
    raise UserDataFetchError, "Failed to fetch user data: #{e.message}"
  end

  def fetch_from_github(url, access_token)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "token #{access_token}"
    request['Accept'] = 'application/vnd.github.v3+json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 10) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise UserDataFetchError, "GitHub API request failed with status #{response.code}"
    end

    parse_json_response(response.body)
  end

  def find_primary_email(emails)
    emails.find { |email| email['primary'] && email['verified'] }&.fetch('email', nil)
  end

  def find_or_create_user(data)
    email = data['verified_email']
    github_id = data['id']
    Rails.logger.info "Authenticating GitHub user - email: #{email}, github_id: #{github_id}"

    unless email.present?
      Rails.logger.error "No verified email provided by GitHub: #{data.inspect}"
      raise UserCreationError, "GitHub did not provide a verified email"
    end

    user = User.find_by(email: email)
    if user
      Rails.logger.info "Found existing user with email #{email} (id: #{user.id}), linking github_id: #{github_id}"
      user.update(github_id: github_id) if user.github_id.nil?
      return user
    end

    Rails.logger.info "No user found with email #{email}, creating new user with github_id: #{github_id}"
    create_new_user(data)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Validation error: #{e.record.errors.full_messages}"
    raise UserCreationError, "Failed to create user: #{e.record.errors.full_messages.join(', ')}"
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error "Duplicate email error: #{email}"
    raise UserCreationError, "Email '#{email}' is already taken and cannot be linked"
  end

  def create_new_user(data)
    user = User.new(
      github_id: data['id'],
      email: data['verified_email'],
      full_name: data['name'] || data['login'],
      role: 'user'
    )
    user.save!(validate: false)
    Rails.logger.info "Created new GitHub user: #{user.attributes.inspect}"
    UserMailer.welcome_github_user(user).deliver_later if defined?(UserMailer)
    user
  end

  def generate_tokens(user)
    access_token = JwtService.encode_access_token(
      user_id: user.id,
      jti: SecureRandom.uuid,
      exp: 15.minutes.from_now.to_i
    )

    refresh_token = JwtService.encode_refresh_token(
      user_id: user.id,
      jti: SecureRandom.uuid,
      exp: 30.days.from_now.to_i
    )

    { access_token: access_token, refresh_token: refresh_token }
  rescue StandardError => e
    raise TokenGenerationError, "Token generation failed: #{e.message}"
  end

  def parse_json_response(body)
    return {} if body.nil? || body.empty?
    JSON.parse(body)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse GitHub response: #{body.inspect}. Error: #{e.message}"
    raise AuthenticationError, "Invalid JSON response from GitHub"
  end

  def log_error(error, context = nil)
    message = context ? "#{context}: #{error.message}" : error.message
    Rails.logger.error(message)
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
    Sentry.capture_exception(error) if defined?(Sentry)
  end
end