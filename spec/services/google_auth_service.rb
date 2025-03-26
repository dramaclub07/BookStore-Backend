require 'rails_helper'

RSpec.describe Api::V1::GoogleAuthController, type: :controller do
  let(:google_id) { "1234567890" }
  let(:email) { "testuser@gmail.com" }
  let(:full_name) { "Test User" }
  let(:mock_token) { "mock_google_token" }
  let(:mock_payload) { { "sub" => google_id, "email" => email, "name" => full_name } }
  let(:user) { create(:user, google_id: google_id, email: email, full_name: full_name) }

  before do
    allow(GoogleIDToken::Validator).to receive(:new).and_return(double(check: mock_payload))
    allow(JwtService).to receive(:encode).and_return("mock_jwt_token")
  end

  describe "POST #create" do
    context "when a valid token is provided" do
      it "authenticates the user and returns a JWT token" do
        post :create, params: { token: mock_token }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to eq("Authentication successful")
        expect(json_response["user"]["email"]).to eq(email)
        expect(json_response["token"]).to be_present
      end
    end

    context "when no token is provided" do
      it "returns a bad request error" do
        post :create, params: {}

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("No token provided")
      end
    end

    context "when an invalid token is provided" do
      before do
        allow_any_instance_of(GoogleIDToken::Validator).to receive(:check).and_raise(GoogleIDToken::ValidationError.new("Invalid token"))
      end

      it "returns an unauthorized error" do
        post :create, params: { token: "invalid_token" }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Invalid token")
      end
    end

    context "when user creation fails" do
      before do
        allow(User).to receive(:find_by).and_return(nil)
        allow(User).to receive(:new).and_raise(ActiveRecord::RecordInvalid.new(user))
      end

      it "returns an unprocessable entity error" do
        post :create, params: { token: mock_token }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Failed to create or update user")
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow_any_instance_of(Api::V1::GoogleAuthController).to receive(:authenticate_with_google).and_raise(StandardError.new("Unexpected error"))
      end

      it "returns an internal server error" do
        post :create, params: { token: mock_token }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("An unexpected error occurred")
      end
    end
  end
end
