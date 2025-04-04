require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "Google Authentication Integration", type: :request do
  describe "POST /api/v1/google_auth" do
    let(:google_token) { "valid_google_token" }

    context "when Google token is valid and user exists" do
      let!(:user) { create(:user, :with_google, google_id: "12345", email: "testuser@gmail.com", full_name: "Test User", password: "temp12345") }

      before do
        stub_request(:get, /oauth2.googleapis.com\/tokeninfo/)
          .with(query: { id_token: google_token })
          .to_return(status: 200, body: { sub: "12345", email: "testuser@gmail.com", name: "Test User" }.to_json, headers: { "Content-Type" => "application/json" })
        allow(JwtService).to receive(:encode_access_token).and_return("mock_access")
        allow(JwtService).to receive(:encode_refresh_token).and_return("mock_refresh")
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: user.id, exp: 15.minutes.from_now.to_i, role: "user" })
        allow(JwtService).to receive(:decode_refresh_token).and_return({ user_id: user.id, exp: 30.days.from_now.to_i, role: "user" })
      end

      it "returns success with tokens" do
        post "/api/v1/google_auth", params: { token: google_token }
        expect(response).to have_http_status(:ok), "Got #{response.status}: #{response.body}"
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Authentication successful")
        expect(json["access_token"]).to eq("mock_access")
        expect(json["refresh_token"]).to eq("mock_refresh")
        expect(json["user"]["email"]).to eq("testuser@gmail.com")
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
        expect { post "/api/v1/google_auth", params: { token: google_token } }
          .to change(User, :count).by(1)
        expect(response).to have_http_status(:ok), "Got #{response.status}: #{response.body}"
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Authentication successful")
        expect(json["access_token"]).to eq("mock_access")
        expect(json["refresh_token"]).to eq("mock_refresh")
        expect(json["user"]["email"]).to eq("newuser@gmail.com")
        expect(User.find_by(google_id: "67890")).to be_present
      end
    end
  end
end