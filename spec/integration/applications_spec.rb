require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  let(:user) { create(:user) }
  let(:valid_token) { JwtService.encode(user_id: user.id) }
  let(:invalid_token) { 'invalid.token.here' }

  # Helper method to make requests with or without token
  def request_with_token(token = nil)
    get '/protected_endpoint', headers: { 'Authorization' => token.present? ? "Bearer #{token}" : nil }
  end

  # Define a dummy controller and route for protected action
  before do
    # Ensure no duplicate definition warnings
    Object.send(:remove_const, :TestController) if defined?(TestController)

    # Dummy controller to test authentication
    class TestController < ApplicationController
      def protected_action
        render json: { success: true, message: 'Authorized access', user_id: current_user.id }
      end
    end

    Rails.application.routes.draw do
      get '/protected_endpoint', to: 'test#protected_action'
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe 'Authenticate Request' do
    context 'when token is missing' do
      it 'returns unauthorized with missing token message' do
        request_with_token(nil)

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Unauthorized - Missing token')
      end
    end

    context 'when token is valid' do
      it 'allows access to the protected action' do
        request_with_token(valid_token)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Authorized access')
        expect(json_response['user_id']).to eq(user.id)
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized with invalid token message' do
        request_with_token(invalid_token)

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Unauthorized - Invalid token')
      end
    end

    context 'when user is not found' do
      it 'returns unauthorized with user not found message' do
        deleted_user_token = JwtService.encode(user_id: user.id)
        user.destroy!

        request_with_token(deleted_user_token)

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Unauthorized - User not found')
      end
    end
  end
end
