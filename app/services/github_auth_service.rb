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
  
    # Find or create user in your app
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
    email = user_data["email"]
    unless email
      # If email is not public, fetch it using the emails API
      email = fetch_user_email(access_token)
      Rails.logger.info("Fetched email: #{email}")
    end
    unless email
      Rails.logger.error("No email available for user: #{user_data['login']}")
      return nil
    end
  
    user = User.find_or_create_by(email: email) do |u|
      u.full_name = user_data["name"] || user_data["login"]
      u.password = SecureRandom.hex(16) # Random password for OAuth users
      u.github_id = user_data["id"].to_s # Set github_id to the GitHub user ID
      u.role = "user" # Set default role
    end
  
    unless user.persisted?
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
    access_token = JwtService.encode_access_token({ user_id: user.id }, 15.minutes.from_now.to_i) # Use JwtService
    refresh_token = JwtService.encode_refresh_token({ user_id: user.id }, 30.days.from_now.to_i) # Use JwtService
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