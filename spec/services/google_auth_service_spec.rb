require 'rails_helper'
require 'webmock/rspec'

RSpec.describe GoogleAuthService, type: :service do
  describe "#authenticate" do
    let(:google_token) { "valid_google_token" }

    context "when Google token is valid and user exists" do
      let(:user) { create(:user, :with_google, google_id: "12345", email: "testuser@gmail.com", full_name: "Test User", password: "temp12345") }

      before do
        stub_request(:get, /oauth2.googleapis.com\/tokeninfo/)
          .with(query: { id_token: google_token })
          .to_return(status: 200, body: { sub: "12345", email: "testuser@gmail.com", name: "Test User" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
        allow(JwtService).to receive(:encode_refresh_token).and_return("mock_refresh")
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: user.id, exp: 15.minutes.from_now.to_i, role: "user" })
        allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: user.id, exp: 30.days.from_now.to_i, role: "user" })
      end

      it "returns a success result with tokens" do
        result = GoogleAuthService.new(google_token).authenticate
        expect(result.success).to be true
        expect(result.user).to eq(user)
        expect(result.access_token).to eq("mock_access")
        expect(result.refresh_token).to eq("mock_refresh")
        expect(result.error).to be_nil
        expect(result.status).to eq(:ok)
      end
    end

    context "when Google token is valid and user doesn’t exist" do
      before do
        stub_request(:get, /oauth2.googleapis.com\/tokeninfo/)
          .with(query: { id_token: google_token })
          .to_return(status: 200, body: { sub: "67890", email: "newuser@gmail.com", name: "New User" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
        allow(JwtService).to receive(:encode_refresh_token).and_return("mock_refresh")
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: 1, exp: 15.minutes.from_now.to_i, role: "user" })
        allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: 1, exp: 30.days.from_now.to_i, role: "user" })
      end

      it "creates a user and returns success with tokens" do
        expect { GoogleAuthService.new(google_token).authenticate }
          .to change(User, :count).by(1)
        result = GoogleAuthService.new(google_token).authenticate
        expect(result.success).to be true
        expect(result.user.email).to eq("newuser@gmail.com")
        expect(result.access_token).to eq("mock_access")
        expect(result.refresh_token).to eq("mock_refresh")
        expect(result.error).to be_nil
        expect(result.status).to eq(:ok)
      end
    end

    context "when Google token is invalid" do
      before do
        stub_request(:get, /oauth2.googleapis.com\/tokeninfo/)
          .with(query: { id_token: google_token })
          .to_return(status: 401, body: { error: "Invalid token" }.to_json)
      end

      it "returns a failure result" do
        result = GoogleAuthService.new(google_token).authenticate
        expect(result.success).to be false
        expect(result.error).to eq("Invalid Google token: Invalid token")
        expect(result.status).to eq(:unauthorized)
      end
    end
  end
end