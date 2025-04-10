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
      return Result.new(false, :unauthorized, "Failed to obtain access token")
    end

    access_token = token_response.parsed_response["access_token"]

    # Fetch user data from GitHub
    user_data = fetch_user_data(access_token)
    unless user_data.success?
      return Result.new(false, :unauthorized, "Failed to fetch user data")
    end


    # Find or create user in your app using github_id
    user = find_or_create_user(user_data.parsed_response, access_token)
    unless user
      return Result.new(false, :internal_server_error, "Failed to create user")
    end


    # Generate tokens
    access_token, refresh_token = generate_tokens(user)
    unless access_token && refresh_token
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
        redirect_uri: "https://book-store-frontend-three-azure.vercel.app/"
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
      return nil
    end

    # Fetch email if not present in user_data
    email = user_data["email"] || fetch_user_email(access_token)
    email ||= "#{github_id}@github-no-email.com" # Fallback if no email is available

    # Find or create user by github_id
    user = User.where(github_id: github_id).first_or_initialize

    if user.new_record?
      user.github_id = github_id # Explicitly set github_id
      user.email = generate_unique_email(email, github_id)
      user.full_name = user_data["name"] || user_data["login"] || "GitHub User"
      user.password = SecureRandom.hex(16) # Random password for OAuth users
      user.role = "user" # Set default role
    else
      # Update full_name if changed
      new_full_name = user_data["name"] || user_data["login"] || "GitHub User"
      user.full_name = new_full_name if user.full_name != new_full_name
    end

    # Attempt to save the user with validation bypass if necessary
    unless user.save
      # If email is the only issue, force a unique email and retry
      if user.errors[:email].present?
        user.email = generate_unique_email(email, github_id + "-retry")
        unless user.save
          return nil
        end
      else
        return nil
      end
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
      email = primary_email&.dig("email")
      email
    else
      nil
    end
  end

  def generate_unique_email(base_email, github_id)
    email = base_email
    counter = 1
    while User.exists?(email: email) && !User.exists?(github_id: github_id, email: email)
      email = "#{base_email.split('@')[0]}+#{github_id}-#{counter}@#{base_email.split('@')[1]}"
      counter += 1
    end
    email
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