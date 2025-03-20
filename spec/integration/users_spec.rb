# spec/integration/users_spec.rb
require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  let!(:existing_user) { create(:user, email: Faker::Internet.email(domain: 'gmail.com'), password: 'Test@123') }
  let!(:otp) { PasswordService.generate_otp }

  before do
    PasswordService::OTP_STORAGE[existing_user.email.downcase] = { otp: otp, otp_expiry: Time.now + 5 * 60 }
  end

  describe 'POST /api/v1/signup' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          user: attributes_for(:user, password: 'Test@123', password_confirmation: 'Test@123')
        }
      end

      it 'registers a new user successfully' do
        post '/api/v1/signup', params: valid_params.as_json, as: :json
        expect(response).to have_http_status(201)
        expect(json['message']).to eq('User registered successfully')
      end
    end

    context 'with duplicate email' do
      let(:duplicate_params) do
        {
          user: {
            full_name: existing_user.full_name,
            email: existing_user.email,
            password: 'Test@123',
            password_confirmation: 'Test@123',
            mobile_number: '9876543210' # Use a unique mobile number
          }
        }
      end

      it 'returns email already taken error' do
        post '/api/v1/signup', params: duplicate_params.as_json, as: :json
        expect(response).to have_http_status(422)
        expect(json['errors']).to include('Email already taken. Please use a different email.')
      end
    end
  end

  describe 'POST /api/v1/forgot_password' do
    context 'with existing email' do
      let(:valid_email) { { email: existing_user.email } }

      it 'sends OTP successfully' do
        allow(UserMailer).to receive(:send_otp).and_return(double(deliver_now: true))
        post '/api/v1/forgot_password', params: valid_email.as_json, as: :json
        expect(response).to have_http_status(200)
      end
    end
  end
  
  describe 'POST /api/v1/reset_password' do
    context 'with valid data' do
      let(:valid_reset_data) { { email: existing_user.email, otp: otp, new_password: 'NewPass@123', password_confirmation: 'NewPass@123' } }

      it 'resets password successfully' do
        post '/api/v1/reset_password', params: valid_reset_data.as_json, as: :json
        expect(response).to have_http_status(200)
        expect(json['message']).to eq('Password reset successfully')
      end
    end
  end

  def json
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end
end