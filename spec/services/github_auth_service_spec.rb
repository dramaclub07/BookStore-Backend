require 'rails_helper'
require 'webmock/rspec'

RSpec.describe GithubAuthService, type: :service do
  describe "#authenticate" do
    let(:github_code) { "valid_github_code" }
    let(:mock_access_token) { "mock_access" }
    let(:mock_refresh_token) { "mock_refresh" }
    let(:mock_github_token) { "mock_github_token" }

    # Common JWT stubbing
    before do
      allow(JwtService).to receive(:encode_access_token).and_return(mock_access_token)
      allow(JwtService).to receive(:encode_refresh_token).and_return(mock_refresh_token)
    end

    context "when GitHub code is valid and user exists" do
      let(:user) { create(:user, :with_github, github_id: "12345", email: "testuser#{SecureRandom.hex(4)}@gmail.com", full_name: "Test User", password: "temp12345") } # Unique email

      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: "12345", email: user.email, login: "testuser", name: "Test User" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns a success result with the existing user" do
        result = GithubAuthService.new(github_code).authenticate
        expect(result.success).to be true
        expect(result.user).to eq(user)
        expect(result.access_token).to eq(mock_access_token)
        expect(result.refresh_token).to eq(mock_refresh_token)
        expect(result.error).to be_nil
        expect(result.status).to eq(:ok)
      end
    end

    context "when GitHub code is valid and user doesn’t exist" do
      let(:new_user_email) { "newuser#{SecureRandom.hex(4)}@gmail.com" } # Unique email
      let(:new_user_github_id) { "67890" }

      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: new_user_github_id, email: new_user_email, login: "newuser", name: "New User" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "creates a user and returns success with tokens" do
        expect { GithubAuthService.new(github_code).authenticate }
          .to change(User, :count).by(1)
        result = GithubAuthService.new(github_code).authenticate
        expect(result.success).to be true
        expect(result.user.email).to eq(new_user_email)
        expect(result.access_token).to eq(mock_access_token)
        expect(result.refresh_token).to eq(mock_refresh_token)
        expect(result.error).to be_nil
        expect(result.status).to eq(:ok)
        expect(User.find_by(github_id: new_user_github_id)).to be_present
      end
    end

    context 'when GitHub API fails' do
      let(:service) { described_class.new(valid_code) }

      before do
        stub_request(:get, "https://api.github.com/user")
          .to_return(status: 500, body: '{}')
      end
    end

    context "when user creation fails due to missing email" do
      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: "99999", login: "noemailuser", name: "No Email" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, "https://api.github.com/user/emails")
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" }) # No emails
      end

      it "returns a failure result" do
        result = GithubAuthService.new(github_code).authenticate
        expect(result.success).to be false
        expect(result.error).to eq("Failed to create user")
        expect(result.status).to eq(:internal_server_error)
      end
    end

    context "when token generation fails" do
      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: "22222", email: "tokenfail#{SecureRandom.hex(4)}@gmail.com", login: "tokenfail", name: "Token Fail" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:encode_access_token).and_return(nil) # Simulate token generation failure
      end

      it "returns a failure result" do
        result = GithubAuthService.new(github_code).authenticate
        expect(result.success).to be false
        expect(result.error).to eq("Failed to generate authentication tokens")
        expect(result.status).to eq(:internal_server_error)
      end
    end

    context "when fetching user email fails" do
      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_API_URI)
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 200, body: { id: "33333", login: "noemailuser", name: "No Email" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, "https://api.github.com/user/emails")
          .with(headers: { 'Authorization' => "Bearer #{mock_github_token}", 'User-Agent' => "Rails GitHub OAuth" })
          .to_return(status: 403, body: { error: "forbidden" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns a failure result" do
        result = GithubAuthService.new(github_code).authenticate
        expect(result.success).to be false
        expect(result.error).to eq("Failed to create user")
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end