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

    # Shared examples for successful authentication
    shared_examples "successful authentication" do |expected_email|
      it "returns a success result with tokens" do
        result = GithubAuthService.new(github_code).authenticate
        expect(result.success).to be true
        expect(result.user.email).to eq(expected_email)
        expect(result.access_token).to eq(mock_access_token)
        expect(result.refresh_token).to eq(mock_refresh_token)
        expect(result.error).to be_nil
        expect(result.status).to eq(:ok)
      end
    end

    context "when GitHub code is valid and user exists" do
      let(:user) { create(:user, :with_github, github_id: "12345", email: "testuser@gmail.com", full_name: "Test User", password: "temp12345") }

      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_USER_URI)
          .with(headers: { 'Authorization' => "token #{mock_github_token}" })
          .to_return(status: 200, body: { id: "12345", email: "testuser@gmail.com", login: "testuser", name: "Test User" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: user.id, exp: 15.minutes.from_now.to_i, role: "user" })
        allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: user.id, exp: 30.days.from_now.to_i, role: "user" })
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
      let(:new_user_email) { "newuser@gmail.com" }
      let(:new_user_github_id) { "67890" }

      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 200, body: { access_token: mock_github_token }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, GithubAuthService::GITHUB_USER_URI)
          .with(headers: { 'Authorization' => "token #{mock_github_token}" })
          .to_return(status: 200, body: { id: new_user_github_id, email: new_user_email, login: "newuser", name: "New User" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: 1, exp: 15.minutes.from_now.to_i, role: "user" })
        allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: 1, exp: 30.days.from_now.to_i, role: "user" })
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

    context "when GitHub code is invalid" do
      let(:invalid_code) { "invalid_code" }

      before do
        stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
          .to_return(status: 401, body: { error: "invalid_code" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns a failure result" do
        result = GithubAuthService.new(invalid_code).authenticate
        expect(result.success).to be false
        expect(result.error).to eq("invalid_code")
        expect(result.status).to eq(:unauthorized)
      end
    end
  end
end