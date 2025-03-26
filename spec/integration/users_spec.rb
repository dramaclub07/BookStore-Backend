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
      

      # it 'returns email already taken error' do
      #   post '/api/v1/signup', params: duplicate_params.as_json, as: :json
      #   expect(response).to have_http_status(422)
      #   expect(json['errors']).to include('Email already taken. Please use a different email.')
      # end
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
    context 'when user is authenticated' do
      it 'returns the user profile' do
        allow(UserService).to receive(:get_profile).and_return({ success: true, name: 'Test User', email: 'test@example.com', mobile_number: '1234567890' })
        get '/api/v1/users/profile', headers: headers
        puts "Get Profile Status: #{response.status}"
        puts "Get Profile Body: #{response.body}"
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('name', 'email', 'mobile_number')
        expect(json_response['name']).to eq('Test User')
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
        puts "Patch Profile Status: #{response.status}"
        puts "Patch Profile Body: #{response.body}"
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Profile updated successfully')
        expect(user.reload.full_name).to eq('Updated User')
        expect(user.authenticate('newpass456')).to be_truthy
      end
    end

    context 'with incorrect current password' do
      it 'returns unprocessable entity' do
        patch '/api/v1/users/profile', params: { user: { current_password: 'wrongpass', new_password: 'newpass456', password_confirmation: 'newpass456' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Current password is incorrect')
      end
    end

    context 'with missing new password' do
      it 'returns unprocessable entity' do
        patch '/api/v1/users/profile', params: { user: { current_password: 'password123' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('New password cannot be blank')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch '/api/v1/users/profile', params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/user/profile' do
    let(:update_params) { { user: { full_name: 'Updated User' } } }

    context 'when user is authenticated' do
      it 'updates the profile via UserService' do
        allow(UserService).to receive(:update_profile).and_return({ success: true, user: { id: user.id, full_name: 'Updated User' } })
        put '/api/v1/user/profile', params: update_params, headers: headers
        puts "Put Profile Status: #{response.status}"
        puts "Put Profile Body: #{response.body}"
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Profile updated successfully')
        expect(json_response['user']).to be_present
      end
    end

    context 'when update fails' do
      it 'returns unprocessable entity' do
        allow(UserService).to receive(:update_profile).and_return({ success: false, error: ['Update failed'] })
        put '/api/v1/user/profile', params: { user: { email: '' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq(['Update failed'])
      end
    end
  end
end