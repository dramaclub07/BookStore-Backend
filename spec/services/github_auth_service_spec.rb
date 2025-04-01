# require 'rails_helper'
# require 'webmock/rspec'

# RSpec.describe GithubAuthService, type: :service do  # Changed from GitHubAuthService
#   describe "#authenticate" do
#     let(:github_code) { "valid_github_code" }

#     context "when GitHub code is valid and user exists" do
#       let(:user) { create(:user, :with_github, github_id: "12345", email: "testuser@gmail.com", full_name: "Test User", password: "temp12345") }

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

#       it "returns a success result with tokens" do
#         result = GithubAuthService.new(github_code).authenticate
#         expect(result.success).to be true
#         expect(result.user).to eq(user)
#         expect(result.access_token).to eq("mock_access")
#         expect(result.refresh_token).to eq("mock_refresh")
#         expect(result.error).to be_nil
#         expect(result.status).to eq(:ok)
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
#         expect { GithubAuthService.new(github_code).authenticate }
#           .to change(User, :count).by(1)
#         result = GithubAuthService.new(github_code).authenticate
#         expect(result.success).to be true
#         expect(result.user.email).to eq("newuser@gmail.com")
#         expect(result.access_token).to eq("mock_access")
#         expect(result.refresh_token).to eq("mock_refresh")
#         expect(result.error).to be_nil
#         expect(result.status).to eq(:ok)
#       end
#     end

#     context "when GitHub code is invalid" do
#       before do
#         stub_request(:post, GithubAuthService::GITHUB_TOKEN_URI)
#           .to_return(status: 401, body: { error: "invalid_code" }.to_json, headers: { "Content-Type" => "application/json" })
#       end

#       it "returns a failure result" do
#         result = GithubAuthService.new("invalid_code").authenticate
#         expect(result.success).to be false
#         expect(result.error).to eq("invalid_code")
#         expect(result.status).to eq(:unauthorized)
#       end
#     end
#   end
# end

# spec/services/github_auth_service_spec.rb
require 'rails_helper'

RSpec.describe GithubAuthService do
  let(:valid_code) { 'valid_code' }
  let(:invalid_code) { 'invalid_code' }
  let(:access_token) { 'mock_github_token' }
  let(:user_data) { { 'id' => 12345, 'login' => 'testuser', 'name' => 'Test User' } }
  let(:user_emails) { [{ 'email' => 'test@example.com', 'primary' => true, 'verified' => true }] }

  before do
    # Stub token exchange
    stub_request(:post, "https://github.com/login/oauth/access_token")
      .with(body: {
        client_id: Rails.application.credentials.github[:client_id],
        client_secret: Rails.application.credentials.github[:client_secret],
        code: valid_code,
        redirect_uri: Rails.application.credentials.github[:callback_url]
      })
      .to_return(status: 200, body: { access_token: access_token }.to_json)

    stub_request(:post, "https://github.com/login/oauth/access_token")
      .with(body: hash_including(code: invalid_code))
      .to_return(status: 401, body: { error: 'invalid_code' }.to_json)

    # Stub user data requests
    stub_request(:get, "https://api.github.com/user")
      .with(headers: { 'Authorization' => "token #{access_token}" })
      .to_return(status: 200, body: user_data.to_json)

    stub_request(:get, "https://api.github.com/user/emails")
      .with(headers: { 'Authorization' => "token #{access_token}" })
      .to_return(status: 200, body: user_emails.to_json)
  end

  describe '#authenticate' do
    context 'with valid code' do
      let(:service) { described_class.new(valid_code) }

      context 'when user does not exist' do
        it 'creates a new user and returns tokens' do
          expect {
            result = service.authenticate
            expect(result).to be_success
            expect(result.user).to be_persisted
            expect(result.access_token).to be_present
            expect(result.refresh_token).to be_present
          }.to change(User, :count).by(1)
        end
      end

      context 'when user exists' do
        let!(:user) { create(:user, email: 'test@example.com') }

        it 'returns existing user and tokens' do
          expect {
            result = service.authenticate
            expect(result).to be_success
            expect(result.user).to eq(user)
          }.not_to change(User, :count)
        end
      end
    end

    context 'with invalid code' do
      let(:service) { described_class.new(invalid_code) }

      it 'returns error result' do
        result = service.authenticate
        expect(result).not_to be_success
        expect(result.error).to eq('invalid_code')
      end
    end

    context 'when GitHub API fails' do
      let(:service) { described_class.new(valid_code) }

      before do
        stub_request(:get, "https://api.github.com/user")
          .to_return(status: 500, body: '{}')
      end

      it 'returns error result' do
        result = service.authenticate
        expect(result).not_to be_success
        expect(result.error).to include('Failed to fetch user data')
      end
    end
  end
end