# spec/integration/users_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :request do
  let(:user) { create(:user, password: 'password123') }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'POST /api/v1/signup' do
    let(:valid_params) { { user: { full_name: 'New User', email: 'new@example.com', password: 'newpass123', mobile_number: '9876543210' } } }
    let(:invalid_params) { { user: { email: 'invalid', password: '' } } }

    context 'with valid params' do
      it 'creates a new user' do
        post '/api/v1/signup', params: valid_params
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('User registered successfully')
        expect(json_response['user']).to include('id', 'email', 'full_name')
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity' do
        post '/api/v1/signup', params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("Email is invalid", "Password can't be blank")
      end
    end
  end

  describe 'POST /api/v1/login' do
    let(:valid_login_params) { { email: user.email, password: 'password123' } }
    let(:invalid_login_params) { { email: user.email, password: 'wrongpassword' } }

    context 'with valid credentials' do
      it 'logs in the user' do
        post '/api/v1/login', params: valid_login_params
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Login successful')
        expect(json_response['user']).to include('id', 'email', 'full_name')
        expect(json_response['token']).to be_present
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized' do
        post '/api/v1/login', params: invalid_login_params
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to eq('Invalid email or password')
      end
    end
  end

  describe 'POST /api/v1/forgot_password' do
    context 'with valid email' do
      it 'initiates password reset' do
        post '/api/v1/forgot_password', params: { email: user.email }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('OTP sent to your email')
      end
    end

    context 'with invalid email' do
      it 'returns unprocessable entity' do
        post '/api/v1/forgot_password', params: { email: 'unknown@example.com' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('User not found')
      end
    end
  end

  describe 'POST /api/v1/reset_password' do
    let(:reset_params) { { email: user.email, otp: '123456', new_password: 'newpass123' } }

    context 'with valid OTP and params' do
      it 'resets the password' do
        post '/api/v1/reset_password', params: reset_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Password reset successfully')
      end
    end

    context 'with invalid OTP' do
      it 'returns unprocessable entity' do
        post '/api/v1/reset_password', params: reset_params.merge(otp: 'wrong')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('OTP not found')
      end
    end
  end

  describe 'GET /api/v1/users/profile' do
    context 'when user is authenticated' do
      it 'returns the user profile' do
        get '/api/v1/users/profile', headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('email', 'full_name', 'mobile_number')
        expect(json_response['full_name']).to eq(user.full_name)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/users/profile'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/users/profile' do
    let(:update_params) { { user: { full_name: 'Updated User', current_password: 'password123', new_password: 'newpass456', password_confirmation: 'newpass456' } } }

    context 'when user is authenticated and params are valid' do
      it 'updates the profile and password' do
        patch '/api/v1/users/profile', params: update_params, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Profile updated successfully')
        expect(user.reload.full_name).to eq('Updated User')
        expect(user.authenticate('newpass456')).to be_truthy
      end
    end

    context 'with missing new password' do
      it 'returns unprocessable entity' do
        patch '/api/v1/users/profile', params: { user: { current_password: 'password123' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('New password cannot be blank')
      end
    end

    context 'with incorrect current password' do
      it 'returns unprocessable entity' do
        patch '/api/v1/users/profile', params: { user: { current_password: 'wrongpass', new_password: 'newpass456', password_confirmation: 'newpass456' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Current password is incorrect')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch '/api/v1/users/profile', params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/users/profile' do
    let(:update_params) { { user: { full_name: 'Updated User' } } }

    context 'when user is authenticated' do
      it 'updates the profile via UserService' do
        allow(UserService).to receive(:update_profile).and_return({ success: true, user: { id: user.id, full_name: 'Updated User' } })
        patch '/api/v1/users/profile', params: update_params, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Profile updated successfully')
        expect(json_response['user']).to be_present
      end
    end

    context 'when update fails' do
      it 'returns unprocessable entity' do
        allow(UserService).to receive(:update_profile).and_return({ success: false, error: ['Update failed'] })
        patch '/api/v1/users/profile', params: { user: { email: '' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq(['Update failed'])
      end
    end
  end
end