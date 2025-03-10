require 'rails_helper'

RSpec.describe UserService, type: :service do
  let!(:user) { create(:user, password: "password123") }

  describe ".signup" do
    context "when valid details are provided" do
      it "creates a new user successfully" do
        params = { full_name: "Test User", email: "test@example.com", password: "password123", mobile_number: "1234567890" }
        result = UserService.signup(params)

        expect(result[:success]).to be true
        expect(result[:user].email).to eq("test@example.com")
      end
    end

    context "when email is already taken" do
      it "returns an error" do
        params = { full_name: "Test User", email: user.email, password: "password123", mobile_number: "1234567890" }
        result = UserService.signup(params)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Email has already been taken")
      end
    end
  end

  describe ".login" do
    context "when valid credentials are provided" do
      it "returns success and a token" do
        result = UserService.login(user.email, "password123")

        expect(result[:success]).to be true
        expect(result[:token]).not_to be_nil
      end
    end

    context "when invalid credentials are provided" do
      it "returns an error" do
        result = UserService.login(user.email, "wrongpassword")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid email or password")
      end
    end
  end
end
