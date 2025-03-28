require 'rails_helper'
#working fine with new routes

RSpec.describe "Google Authentication Integration", type: :request do
  let(:valid_token) { "valid_google_token" }
  let(:invalid_token) { "invalid_google_token" }
  let(:google_response) do
    {
      "sub" => "123",
      "email" => "akshay@gmail.com",
      "name" => "Akshay Katoch",
      "mobile_number" => "9876543210"
    }
  end

  before do
    # Mock with a proper HTTP success response
    allow(Net::HTTP).to receive(:get_response).and_return(
      double("HTTPResponse", code: "200", body: google_response.to_json, is_a?: ->(klass) { klass == Net::HTTPSuccess })
    )
  end

  describe "POST /api/v1/google_auth" do
    context "when Google token is valid and user already exists" do
      let!(:user) do
        User.create!(
          full_name: "Akshay Katoch",
          email: "akshay@gmail.com",
          mobile_number: "9876543210",
          google_id: "123"
        )
      end

      it "logs in and returns a JWT token" do
        post "/api/v1/google_auth", params: { token: valid_token }
        expect(response).to have_http_status(:ok), "Expected 200 but got #{response.status}: #{response.body}"
        expect(JSON.parse(response.body)["token"]).to be_present
      end
    end

    context "when Google token is valid and user does not exist" do
      it "creates a new user and returns a JWT token" do
        expect {
          post "/api/v1/google_auth", params: { token: valid_token }
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok), "Expected 200 but got #{response.status}: #{response.body}"
        expect(JSON.parse(response.body)["token"]).to be_present
      end
    end

    context "when Google token is invalid" do
      before do
        allow(Net::HTTP).to receive(:get_response).and_return(
          double("HTTPResponse", code: "400", body: { "error" => "Invalid Google token" }.to_json, is_a?: ->(klass) { klass != Net::HTTPSuccess })
        )
      end

      it "returns an unauthorized error with a specific message" do
        post "/api/v1/google_auth", params: { token: invalid_token }
        expect(response).to have_http_status(:unauthorized), "Expected 401 but got #{response.status}: #{response.body}"
        expect(JSON.parse(response.body)["error"]).to eq("Invalid Google token")
      end
    end

    context "when Google response is malformed" do
      before do
        allow(Net::HTTP).to receive(:get_response).and_return(
          double("HTTPResponse", code: "200", body: "{malformed_json}", is_a?: ->(klass) { klass == Net::HTTPSuccess })
        )
      end

      it "returns a bad request error due to JSON parsing failure" do
        post "/api/v1/google_auth", params: { token: valid_token }
        expect(response).to have_http_status(:bad_request), "Expected 400 but got #{response.status}: #{response.body}"
        expect(JSON.parse(response.body)["error"]).to eq("Invalid Google response format")
      end
    end

    context "when user creation fails due to validation errors" do
      let(:invalid_google_response) do
        {
          "sub" => "123",
          "email" => "invalid-email",
          "name" => "ab",
          "mobile_number" => "123"
        }
      end

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(
          double("HTTPResponse", code: "200", body: invalid_google_response.to_json, is_a?: ->(klass) { klass == Net::HTTPSuccess })
        )
      end

      it "returns an unprocessable entity error with validation details" do
        post "/api/v1/google_auth", params: { token: valid_token }
        expect(response).to have_http_status(:unprocessable_entity), "Expected 422 but got #{response.status}: #{response.body}"
        expect(JSON.parse(response.body)["error"]).to include("Validation failed")
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new("Unexpected error"))
      end

      it "returns an internal server error" do
        post "/api/v1/google_auth", params: { token: valid_token }
        expect(response).to have_http_status(:internal_server_error), "Expected 500 but got #{response.status}: #{response.body}"
        expect(JSON.parse(response.body)["error"]).to eq("Unexpected error")
      end
    end
  end
end