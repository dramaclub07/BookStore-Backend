# require 'rails_helper'
# require 'webmock/rspec'

# RSpec.describe "GitHub Authentication Integration", type: :request do
#   describe "GET /api/v1/github_auth/callback" do
#     let(:github_code) { "valid_github_code" }

#     context "when GitHub code is valid and user exists" do
#       let!(:user) { create(:user, :with_github, github_id: "12345", email: "testuser@gmail.com", full_name: "Test User", password: "temp12345") }

#       before do
#         stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
#           .to_return(status: 200, body: { access_token: "mock_github_token" }.to_json, headers: { "Content-Type" => "application/json" })
#         stub_request(:get, GithubAuthService::GITHUB_USER_URI)
#           .with(headers: { 'Authorization' => "token mock_github_token" })
#           .to_return(status: 200, body: { id: "12345", email: "testuser@gmail.com", login: "testuser", name: "Test User" }.to_json, headers: { "Content-Type" => "application/json" })
#         allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
#         allow(JwtService).to receive(:encode_refresh_token).and_return("mock_refresh")
#         allow(JwtService).to receive(:decode_access_token).and_return({ user_id: user.id, exp: 15.minutes.from_now.to_i, role: "user" })
#         allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: user.id, exp: 30.days.from_now.to_i, role: "user" })
#       end

#       it "returns success with tokens" do
#         get "/api/v1/github_auth/callback", params: { code: github_code }
#         expect(response).to have_http_status(:ok), "Got #{response.status}: #{response.body}"
#         json = JSON.parse(response.body)
#         expect(json["message"]).to eq("Authentication successful")
#         expect(json["access_token"]).to eq("mock_access")
#         expect(json["refresh_token"]).to eq("mock_refresh")
#         expect(json["user"]["email"]).to eq("testuser@gmail.com")
#       end
#     end

#     context "when GitHub code is valid and user doesn’t exist" do
#       before do
#         stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
#           .to_return(status: 200, body: { access_token: "mock_github_token" }.to_json, headers: { "Content-Type" => "application/json" })
#         stub_request(:get, GithubAuthService::GITHUB_USER_URI)
#           .with(headers: { 'Authorization' => "token mock_github_token" })
#           .to_return(status: 200, body: { id: "67890", email: "newuser@gmail.com", login: "newuser", name: "New User" }.to_json, headers: { "Content-Type" => "application/json" })
#         allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
#         allow(JwtService).to receive(:encode_refresh_token).and_return("mock_refresh")
#         allow(JwtService).to receive(:decode_access_token).and_return({ user_id: 1, exp: 15.minutes.from_now.to_i, role: "user" })
#         allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: 1, exp: 30.days.from_now.to_i, role: "user" })
#       end

#       it "creates a user and returns success with tokens" do
#         expect { get "/api/v1/github_auth/callback", params: { code: github_code } }
#           .to change(User, :count).by(1)
#         expect(response).to have_http_status(:ok), "Got #{response.status}: #{response.body}"
#         json = JSON.parse(response.body)
#         expect(json["message"]).to eq("Authentication successful")
#         expect(json["access_token"]).to eq("mock_access")
#         expect(json["refresh_token"]).to eq("mock_refresh")
#         expect(json["user"]["email"]).to eq("newuser@gmail.com")
#         expect(User.find_by(github_id: "67890")).to be_present
#       end
#     end

#     context "when GitHub code is invalid" do
#       before do
#         stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
#           .to_return(status: 401, body: { error: "invalid_code" }.to_json, headers: { "Content-Type" => "application/json" })
#       end

#       it "returns an error" do
#         get "/api/v1/github_auth/callback", params: { code: "invalid_code" }
#         expect(response).to have_http_status(:unauthorized)
#         json = JSON.parse(response.body)
#         expect(json["error"]).to eq("invalid_code")
#       end
#     end
#   end
# end
# spec/integration/github_auth_spec.rb
require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "GitHub Authentication Integration", type: :request do
  let(:github_code) { "valid_github_code" }
  let(:state) { SecureRandom.hex(16) }

  before do
    # Set up state cookie
    cookies[:oauth_state] = state
  end

  describe "GET /api/v1/github_auth/callback" do
    context "when GitHub code is valid and user exists" do
      let!(:user) { create(:user, :with_github, github_id: "12345", email: "testuser@gmail.com") }

      before do
        stub_request(:post, "https://github.com/login/oauth/access_token")
          .to_return(status: 200, body: { access_token: "mock_token" }.to_json)

        stub_request(:get, "https://api.github.com/user")
          .to_return(status: 200, body: { id: "12345", email: "testuser@gmail.com" }.to_json)

        allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
      end

      it "returns success with tokens" do
        get "/api/v1/github_auth/callback", params: { code: github_code, state: state }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["access_token"]).to eq("mock_access")
      end
    end

    context "when state parameter is missing" do
      it "returns error" do
        get "/api/v1/github_auth/callback", params: { code: github_code }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("Missing state parameter")
      end
    end
  end
end