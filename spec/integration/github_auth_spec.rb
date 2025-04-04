require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "GitHub Authentication Integration", type: :request do
  describe "POST /api/v1/github_auth/login" do # Updated to POST to match controller
    let(:github_code) { "valid_github_code" }

    context "when GitHub code is not provided" do
      it "returns an error for missing code" do
        post "/api/v1/github_auth/login", params: {} # No code param
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("GitHub code is required")
      end
    end

    context "when GitHub code is valid and user exists" do
      let!(:user) { create(:user, :with_github, github_id: "12345", email: "testuser@gmail.com") }

      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: "mock_github_token" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer mock_github_token", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: "12345", email: "testuser@gmail.com", login: "testuser", name: "Test User" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
      end

      it "returns success with tokens" do
        post "/api/v1/github_auth/login", params: { code: github_code }
        expect(response).to have_http_status(:ok), "Got #{response.status}: #{response.body}"
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Authentication successful")
        expect(json["access_token"]).to eq("mock_access")
        # expect(json["refresh_token"]).to eq("mock_refresh")
        expect(json["user"]["email"]).to eq("testuser@gmail.com")
      end
    end

    context "when GitHub code is valid and user doesn’t exist" do
      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: "mock_github_token" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer mock_github_token", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: "67890", email: "newuser@gmail.com", login: "newuser", name: "New User" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, "https://api.github.com/user/emails")
          .with(headers: { 'Authorization' => "Bearer mock_github_token", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: [{ "email" => "newuser@gmail.com", "primary" => true, "verified" => true }].to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
        allow(JwtService).to receive(:encode_refresh_token).and_return("mock_refresh")
      end

      it "creates a user and returns success with tokens" do
        expect { post "/api/v1/github_auth/login", params: { code: github_code } }
          .to change(User, :count).by(1)
        expect(response).to have_http_status(:ok), "Got #{response.status}: #{response.body}"
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Authentication successful")
        expect(json["access_token"]).to eq("mock_access")
        expect(json["refresh_token"]).to eq("mock_refresh")
        expect(json["user"]["email"]).to eq("newuser@gmail.com")
        expect(User.find_by(github_id: "67890")).to be_present
      end
    end

    context "when GitHub code is invalid" do
      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 401, body: { error: "invalid_code" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns an error" do
        post "/api/v1/github_auth/login", params: { code: "invalid_code" }
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Failed to obtain access token")
      end
    end
  end
end