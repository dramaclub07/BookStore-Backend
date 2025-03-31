require 'net/http'
require 'json'

class GithubAuthService
  Result = Struct.new(:success, :user, :access_token, :refresh_token, :error, :status)

  GITHUB_AUTH_URI = 'https://github.com/login/oauth/authorize'
  GITHUB_TOKEN_URI = 'https://github.com/login/oauth/access_token'
  GITHUB_USER_URI = 'https://api.github.com/user'

  def initialize(code)
    @code = code
    @client_id = ENV['GITHUB_CLIENT_ID']
    @client_secret = ENV['GITHUB_CLIENT_SECRET']
  end

  def authenticate
    Rails.logger.info "Received GitHub code: #{@code}"
    return Result.new(false, nil, nil, nil, "No code provided", :bad_request) if @code.blank?

    token_response = exchange_code_for_token
    unless token_response[:success]
      Rails.logger.error "Token exchange failed: #{token_response[:error]}"
      return Result.new(false, nil, nil, nil, token_response[:error], token_response[:status])
    end

    access_token = token_response[:access_token]
    user_data = fetch_user_data(access_token)
    unless user_data[:success]
      Rails.logger.error "User data fetch failed: #{user_data[:error]}"
      return Result.new(false, nil, nil, nil, user_data[:error], user_data[:status])
    end

    user = find_or_create_user(user_data[:data])
    unless user.persisted?
      Rails.logger.error "Validation failed: #{user.errors.full_messages.inspect}"
      return Result.new(false, nil, nil, nil, "Validation failed: #{user.errors.full_messages.join(', ')}", :unprocessable_entity)
    end

    tokens = generate_tokens(user)
    decoded_access = JwtService.decode_access_token(tokens[:access_token])
    decoded_refresh = JwtService.decode_refresh_token(tokens[:refresh_token])
    if decoded_access.nil? || decoded_refresh.nil?
      Rails.logger.error "Token generation failed - Access: #{tokens[:access_token]}, Refresh: #{tokens[:refresh_token]}"
      return Result.new(false, nil, nil, nil, "Failed to generate valid tokens", :internal_server_error)
    end

    Result.new(true, user, tokens[:access_token], tokens[:refresh_token], nil, :ok)
  end

  private

  def exchange_code_for_token
    uri = URI(GITHUB_TOKEN_URI)
    response = Net::HTTP.post_form(uri, {
      client_id: @client_id,
      client_secret: @client_secret,
      code: @code,
      redirect_uri: 'http://localhost:3000/api/v1/github_auth/callback'
    })

    body = JSON.parse(response.body)
    if response.is_a?(Net::HTTPSuccess) && body['access_token']
      Rails.logger.info "GitHub access token received: #{body['access_token'][0..10]}..."
      { success: true, access_token: body['access_token'] }
    else
      { success: false, error: body['error'] || 'Token exchange failed', status: :unauthorized }
    end
  rescue StandardError => e
    { success: false, error: "Token exchange error: #{e.message}", status: :internal_server_error }
  end

  def fetch_user_data(access_token)
    uri = URI(GITHUB_USER_URI)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "token #{access_token}"
    request['Accept'] = 'application/json'
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "GitHub user data: #{response.body}"
      { success: true, data: JSON.parse(response.body) }
    else
      { success: false, error: 'Failed to fetch user data', status: :unauthorized }
    end
  rescue StandardError => e
    { success: false, error: "User data fetch error: #{e.message}", status: :internal_server_error }
  end

  def find_or_create_user(data)
    user = User.find_by(github_id: data['id']) || User.find_by(email: data['email'])
    if user
      user.update(github_id: data['id']) unless user.github_id
      Rails.logger.info "Updated existing user: #{user.id}"
    else
      user = User.new(
        github_id: data['id'],
        email: data['email'] || "#{data['login']}@github.com",
        full_name: data['name'] || data['login'],
        password: "temp12345"
      )
      Rails.logger.info "New user attributes: #{user.attributes.inspect}"
      user.save!
      Rails.logger.info "New user created: #{user.id}"
    end
    user
  end

  def generate_tokens(user)
    access_token_payload = { user_id: user.id }
    refresh_token_payload = { user_id: user.id }
    access_exp = 15.minutes.from_now.to_i
    refresh_exp = 30.days.from_now.to_i

    access_token = JwtService.encode_access_token(access_token_payload, access_exp)
    refresh_token = JwtService.encode_refresh_token(refresh_token_payload, refresh_exp)
    Rails.logger.info "Access token expires: #{Time.at(access_exp).utc}, Refresh: #{Time.at(refresh_exp).utc}"
    { access_token: access_token, refresh_token: refresh_token }
  end
end