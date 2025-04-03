class GithubAuthService
  GITHUB_TOKEN_URI = "https://github.com/login/oauth/access_token".freeze
  GITHUB_API_URI = "https://api.github.com/user".freeze

  def initialize(code)
    @code = code
  end

  def authenticate
    # Exchange code for access token
    token_response = exchange_code_for_token
    unless token_response.success?
      Rails.logger.error("Failed to obtain access token: #{token_response.code} - #{token_response.parsed_response}")
      return Result.new(false, :unauthorized, "Failed to obtain access token")
    end

    access_token = token_response.parsed_response["access_token"]
    Rails.logger.info("Access token obtained: #{access_token}")

    # Fetch user data from GitHub
    user_data = fetch_user_data(access_token)
    unless user_data.success?
      Rails.logger.error("Failed to fetch user data: #{user_data.code} - #{user_data.parsed_response}")
      return Result.new(false, :unauthorized, "Failed to fetch user data")
    end

    Rails.logger.info("User data fetched: #{user_data.parsed_response}")

    # Find or create user in your app using github_id
    user = find_or_create_user(user_data.parsed_response, access_token)
    unless user
      Rails.logger.error("Failed to create user with data: #{user_data.parsed_response}")
      return Result.new(false, :internal_server_error, "Failed to create user")
    end

    Rails.logger.info("User created/found: #{user.email}")

    # Generate tokens
    access_token, refresh_token = generate_tokens(user)
    unless access_token && refresh_token
      Rails.logger.error("Failed to generate tokens for user: #{user.email}")
      return Result.new(false, :internal_server_error, "Failed to generate authentication tokens")
    end

    Result.new(true, :ok, nil, user: user, access_token: access_token, refresh_token: refresh_token)
  end

  private

  def validate_code_presence
    return unless @code.empty?
    raise TokenExchangeError, "No authorization code provided"
  end

  def exchange_code_for_token
    HTTParty.post(
      GITHUB_TOKEN_URI,
      body: {
        client_id: ENV["GITHUB_CLIENT_ID"],
        client_secret: ENV["GITHUB_CLIENT_SECRET"],
        code: @code,
        redirect_uri: "http://127.0.0.1:5500/pages/login.html"
      },
      headers: { "Accept" => "application/json" }
    )
  end

  def fetch_user_data(access_token)
    HTTParty.get(
      GITHUB_API_URI,
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "User-Agent" => "Rails GitHub OAuth"
      }
    )
  end

  def find_or_create_user(user_data, access_token)
    github_id = user_data["id"].to_s
    unless github_id
      Rails.logger.error("No GitHub ID available in user data: #{user_data}")
      return nil
    end

    # Fetch email if not present in user_data
    email = user_data["email"] || fetch_user_email(access_token)
    email ||= "#{github_id}@github-no-email.com" # Fallback if no email is available

    # Find existing user by github_id or initialize a new one
    user = User.where(github_id: github_id).first_or_initialize do |u|
      u.full_name = user_data["name"] || user_data["login"]
      u.password = SecureRandom.hex(16) # Random password for OAuth users
      u.role = "user" # Set default role
    end

    # Set email and handle conflicts
    if user.new_record?
      user.email = email
      if User.exists?(email: email)
        existing_user = User.find_by(email: email)
        if existing_user.github_id.nil?
          # Link GitHub account to existing user if no github_id is set
          existing_user.update(github_id: github_id, full_name: user_data["name"] || user_data["login"])
          return existing_user
        else
          # Use a unique email to avoid conflict
          user.email = "#{github_id}+#{email}"
        end
      end
    end

    # Save the user and handle validation errors
    unless user.save
      Rails.logger.error("User validation errors: #{user.errors.full_messages}")
      return nil
    end

    user
  end

  def fetch_user_email(access_token)
    response = HTTParty.get(
      "https://api.github.com/user/emails",
      headers: {
        "Authorization" => "Bearer #{access_token}",
        "User-Agent" => "Rails GitHub OAuth"
      }
    )
    if response.success?
      emails = response.parsed_response
      primary_email = emails.find { |e| e["primary"] && e["verified"] }
      primary_email&.dig("email")
    else
      Rails.logger.error("Failed to fetch user emails: #{response.code} - #{response.parsed_response}")
      nil
    end
  end

  def generate_tokens(user)
    access_token = JwtService.encode_access_token({ user_id: user.id }, 15.minutes.from_now.to_i)
    refresh_token = JwtService.encode_refresh_token({ user_id: user.id }, 30.days.from_now.to_i)
    [access_token, refresh_token]
  end

  class Result
    attr_reader :success, :status, :error, :user, :access_token, :refresh_token

    def initialize(success, status, error = nil, user: nil, access_token: nil, refresh_token: nil)
      @success = success
      @status = status
      @error = error
      @user = user
      @access_token = access_token
      @refresh_token = refresh_token
    end
  end
end