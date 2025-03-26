require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123', full_name: 'Test User', mobile_number: '1234567890') }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'POST /api/v1/signup' do
    let(:valid_params) { { user: { full_name: 'New User', email: 'new@example.com', password: 'newpass123', mobile_number: '0987654321' } } }

    context 'with valid params' do
      it 'creates a new user' do
        allow(UserService).to receive(:signup).and_return(double(success?: true, user: User.new(id: 1, email: 'new@example.com', full_name: 'New User'), error: nil))
        post '/api/v1/signup', params: valid_params
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('User registered successfully')
        expect(json_response['user']).to include('id', 'email', 'full_name')
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity' do
        allow(UserService).to receive(:signup).and_return(double(success?: false, error: ['Invalid email']))
        post '/api/v1/signup', params: { user: { email: 'invalid', password: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq(['Invalid email'])
      end
    end
  end

  describe 'POST /api/v1/forgot_password' do
    context 'with valid email' do
      it 'initiates password reset' do
        allow(PasswordService).to receive(:forgot_password).and_return({ success: true, message: 'Password reset initiated' })
        post '/api/v1/forgot_password', params: { email: 'test@example.com' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Password reset initiated')
      end
    end

    context 'with invalid email' do
      it 'returns unprocessable entity' do
        allow(PasswordService).to receive(:forgot_password).and_return({ success: false, error: 'Email not found' })
        post '/api/v1/forgot_password', params: { email: 'unknown@example.com' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('Email not found')
      end
    end
  end

  describe 'POST /api/v1/reset_password' do
    let(:reset_params) { { email: 'test@example.com', otp: '123456', new_password: 'newpass123' } }

    context 'with valid OTP and params' do
      it 'resets the password' do
        allow(PasswordService).to receive(:reset_password).and_return({ success: true, message: 'Password reset successfully' })
        post '/api/v1/reset_password', params: reset_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Password reset successfully')
      end
    end

    context 'with invalid OTP' do
      it 'returns unprocessable entity' do
        allow(PasswordService).to receive(:reset_password).and_return({ success: false, error: 'Invalid OTP' })
        post '/api/v1/reset_password', params: reset_params.merge(otp: 'wrong')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('Invalid OTP')
      end
    end
  end

  describe 'GET /api/v1/users/profile' do
    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/users/profile'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/users/profile' do
    let(:update_params) { { user: { full_name: 'Updated User', current_password: 'password123', new_password: 'newpass456', password_confirmation: 'newpass456' } } }

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch '/api/v1/users/profile', params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/user/profile' do
    let(:update_params) { { user: { full_name: 'Updated User' } } }

    # context 'when update fails' do
    #   it 'returns unprocessable entity' do
    #     allow(UserService).to receive(:update_profile).and_return({ success: false, error: ['Update failed'] })
    #     put '/api/v1/user/profile', params: { user: { email: '' } }, headers: headers
    #     expect(response).to have_http_status(:unprocessable_entity)
    #     expect(JSON.parse(response.body)['errors']).to eq(['Update failed'])
    #   end
    # end
  end
end