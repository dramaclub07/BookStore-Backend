require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{access_token}" } }

  describe 'POST /api/v1/signup' do
    let(:valid_params) { { user: { full_name: 'New User', email: 'newuser@gmail.com', password: 'newpass123', mobile_number: '9876543210' } } }

    context 'with valid params' do
      it 'creates a new user' do
        post '/api/v1/signup', params: valid_params
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('User registered successfully')
        expect(json_response['user']).to include('id', 'email', 'full_name')
        expect(User.find_by(email: 'newuser@gmail.com')).to be_present
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity for invalid email' do
        post '/api/v1/signup', params: { user: { full_name: 'User', email: 'invalid@domain.com', password: 'newpass123', mobile_number: '9876543210' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("Email is invalid")
      end

      it 'returns unprocessable entity for blank password' do
        post '/api/v1/signup', params: { user: { full_name: 'User', email: 'new2@gmail.com', password: '', mobile_number: '9876543210' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("Password can't be blank")
      end

      it 'returns unprocessable entity for invalid mobile number' do
        post '/api/v1/signup', params: { user: { full_name: 'User', email: 'new3@gmail.com', password: 'newpass123', mobile_number: '1234567890' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("Mobile number is invalid")
      end

      it 'handles unexpected errors gracefully' do
        allow(User).to receive(:new).and_raise(StandardError.new('DB error'))
        post '/api/v1/signup', params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('An unexpected error occurred: DB error')
      end
    end
  end

  describe 'POST /api/v1/login' do
    context 'with valid credentials' do
      it 'logs in the user and returns a token' do
        post '/api/v1/login', params: { email: user.email, password: 'Password@123' }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Login successful')
        expect(json_response['user']).to include('id', 'email', 'full_name')
        expect(json_response['access_token']).to be_present
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post '/api/v1/login', params: { email: user.email, password: 'wrongpass' }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to eq('Invalid email or password')
      end

      it 'returns unauthorized for non-existent email' do
        post '/api/v1/login', params: { email: 'unknown@gmail.com', password: 'Password@123' }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to eq('Invalid email or password')
      end

      it 'handles unexpected errors gracefully' do
        allow(User).to receive(:find_by).and_raise(StandardError.new('DB error'))
        post '/api/v1/login', params: { email: user.email, password: 'Password@123' }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('An unexpected error occurred: DB error')
      end
    end
  end

  describe 'POST /api/v1/users/password/forgot' do
    context 'with existing email' do
      let(:valid_email) { { email: existing_user.email } }

      it 'sends OTP successfully' do
        allow(UserMailer).to receive(:send_otp).and_return(double(deliver_now: true))
        post '/api/v1/users/password/forgot', params: valid_email.as_json, as: :json
        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'POST /api/v1/reset_password' do
    let(:reset_params) { { email: user.email, otp: '123456', new_password: 'Newpass@123' } }

    context 'with valid OTP and params' do
      before do
        PasswordService::OTP_STORAGE[user.email] = { otp: '123456', otp_expiry: Time.now + 5.minutes }
      end

      it 'resets the password' do
        post '/api/v1/reset_password', params: reset_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Password reset successfully')
        expect(PasswordService::OTP_STORAGE[user.email]).to be_nil
        expect(user.reload.authenticate('Newpass@123')).to be_present
      end
    end

    context 'with invalid OTP' do
      before do
        PasswordService::OTP_STORAGE[user.email] = { otp: '654321', otp_expiry: Time.now + 5.minutes }
      end

      it 'returns unprocessable entity for wrong OTP' do
        post '/api/v1/reset_password', params: reset_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('Invalid OTP')
      end
    end

    context 'with expired OTP' do
      before do
        PasswordService::OTP_STORAGE[user.email] = { otp: '123456', otp_expiry: Time.now - 1.minute }
      end

      it 'returns unprocessable entity' do
        post '/api/v1/reset_password', params: reset_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('OTP expired')
      end
    end

    context 'with missing OTP' do
      before { PasswordService::OTP_STORAGE.clear }
      it 'returns unprocessable entity' do
        post '/api/v1/reset_password', params: reset_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('OTP not found')
      end
    end
  end

  describe 'GET /api/v1/users/profile' do
    context 'when user is authenticated' do
      it 'returns user profile' do
        get '/api/v1/users/profile', headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['name']).to eq(user.full_name)
        expect(json_response['email']).to eq(user.email)
        expect(json_response['mobile_number']).to eq(user.mobile_number)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/users/profile'
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
   
        expect(json_response['success']).to be_falsey
        expect(json_response['message']).to match(/Unauthorized/)
      end
    end
  end

  describe 'PATCH /api/v1/users/profile' do
    let(:update_params) { { user: { full_name: 'Updated User', current_password: 'Password@123', new_password: 'Newpass@456' } } }

    context 'when user is authenticated' do
      it 'updates profile with password change' do
        patch '/api/v1/users/profile', params: update_params, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Profile updated successfully')
        expect(user.reload.full_name).to eq('Updated User')
        expect(user.authenticate('Newpass@456')).to be_present
      end

      # it 'updates profile without password change' do
      #   patch '/api/v1/users/profile', params: { user: { full_name: 'New Name' } }, headers: headers
      #   expect(response).to have_http_status(:ok)
      #   json_response = JSON.parse(response.body)
      #   puts "PATCH response: #{response.body}" if response.status != 200 # Debug
      #   expect(json_response['success']).to be true
      #   expect(json_response['message']).to eq('Profile updated successfully')
      #   expect(user.reload.full_name).to eq('New Name')
      #   expect(user.authenticate('Password@123')).to be_present
      # end

      it 'fails with incorrect current password' do
        patch '/api/v1/users/profile', params: { user: { current_password: 'wrongpass', new_password: 'Newpass@456' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq(['Current password is incorrect'])
      end

      it 'fails with blank new password' do
        patch '/api/v1/users/profile', params: { user: { current_password: 'Password@123', new_password: '' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq(['New password cannot be blank'])
      end

      it 'fails with invalid email' do
        patch '/api/v1/users/profile', params: { user: { email: 'invalid@domain.com' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("Email is invalid")
      end

      it 'handles server errors gracefully' do
        allow_any_instance_of(User).to receive(:update).and_raise(StandardError.new('DB error'))
        patch '/api/v1/users/profile', params: { user: { full_name: 'New Name' } }, headers: headers
        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['error']).to eq('Server error: DB error')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch '/api/v1/users/profile', params: update_params
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        puts "PATCH unauthenticated response: #{response.body}" # Debug
        expect(json_response['success']).to be_falsey
        expect(json_response['message']).to match(/Unauthorized/)
      end
    end
  end

  describe 'PUT /api/v1/users/profile' do
    let(:update_params) { { user: { full_name: 'Updated User' } } }

    # context 'when user is authenticated' do
    #   # it 'updates profile' do
    #   #   put '/api/v1/users/profile', params: update_params, headers: headers
    #   #   expect(response).to have_http_status(:ok)
    #   #   json_response = JSON.parse(response.body)
    #   #   expect(json_response['success']).to be_true
    #   #   expect(json_response['message']).to eq('Profile updated successfully')
    #   #   expect(user.reload.full_name).to eq('Updated User')
    #   # end

    #   # it 'fails when update is unsuccessful' do
    #   #   put '/api/v1/users/profile', params: { user: { email: 'invalid@domain.com' } }, headers: headers
    #   #   expect(response).to have_http_status(:unprocessable_entity)
    #   #   expect(JSON.parse(response.body)['errors']).to include("Email is invalid")
    #   # end
    # end

    # context 'when user is not authenticated' do
    #   # it 'returns unauthorized' do
    #   #   put '/api/v1/users/profile', params: update_params
    #   #   expect(response).to have_http_status(:unauthorized)
    #   #   json_response = JSON.parse(response.body)
    #   #   puts "PUT unauthenticated response: #{response.body}" # Debug
    #   #   expect(json_response['success']).to be_falsey
    #   #   expect(json_response['message']).to match(/Unauthorized/)
    #   # end
    # end
  end
end