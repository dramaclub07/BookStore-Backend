require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  let!(:existing_user) { create(:user, full_name: 'Akshay Katoch', email: 'akshay@example.com', password: 'Test@123', mobile_number: '9876543210') }
  let!(:otp) { PasswordService.generate_otp }

  before do
    PasswordService::OTP_STORAGE[existing_user.email] = { otp: otp, otp_expiry: Time.now + 5 * 60 }
  end

  describe 'POST /api/v1/signup' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          user: {
            full_name: 'New User',
            email: 'newuser@example.com',
            password: 'Test@123',
            mobile_number: '9876543211'
          }
        }
      end

      it 'registers a new user successfully' do
        post '/api/v1/signup', params: valid_params, as: :json
        expect(response).to have_http_status(201)
        expect(json['message']).to eq('User registered successfully')
        expect(json['user']).to be_present
      end
    end

    context 'with duplicate email' do
      let(:duplicate_params) do
        {
          user: {
            full_name: 'Akshay Katoch',
            email: existing_user.email,
            password: 'Test@123',
            mobile_number: '9876543210'
          }
        }
      end

      it 'returns email already taken error' do
        post '/api/v1/signup', params: duplicate_params, as: :json
        expect(response).to have_http_status(422)
        expect(json['errors']).to include('Email has already been taken')
      end
    end
  end

  describe 'POST /api/v1/login' do
    context 'with valid credentials' do
      let(:valid_credentials) { { email: existing_user.email, password: 'Test@123' } }

      it 'logs in successfully' do
        post '/api/v1/login', params: valid_credentials, as: :json
        expect(response).to have_http_status(200)
        expect(json['message']).to eq('Login successful')
        expect(json['user']).to be_present
        expect(json['token']).to be_present
      end
    end

    context 'with invalid credentials' do
      let(:invalid_credentials) { { email: existing_user.email, password: 'WrongPass' } }

      it 'returns unauthorized error' do
        post '/api/v1/login', params: invalid_credentials, as: :json
        expect(response).to have_http_status(401)
        expect(json['errors']).to eq('Invalid email or password')
      end
    end
  end

  describe 'POST /api/v1/forgot_password' do
    context 'with existing email' do
      let(:valid_email) { { email: existing_user.email } }

      it 'sends OTP successfully' do
        # Stub the mailer to avoid actual email sending in tests
        allow(UserMailer).to receive(:send_otp).and_return(double(deliver_now: true))
        post '/api/v1/forgot_password', params: valid_email, as: :json
        expect(response).to have_http_status(200)
        expect(json['message']).to eq('OTP sent to your email')
      end
    end

    context 'with non-existent email' do
      let(:invalid_email) { { email: 'nonexistent@example.com' } }

      it 'returns user not found error' do
        post '/api/v1/forgot_password', params: invalid_email, as: :json
        expect(response).to have_http_status(422)
        expect(json['errors']).to eq('User not found')
      end
    end
  end

  describe 'POST /api/v1/reset_password' do
    context 'with valid data' do
      let(:valid_reset_data) { { email: existing_user.email, otp: otp, new_password: 'NewPass@123' } }

      it 'resets password successfully' do
        post '/api/v1/reset_password', params: valid_reset_data, as: :json
        expect(response).to have_http_status(200)
        expect(json['message']).to eq('Password reset successfully')
      end
    end

    context 'with invalid OTP' do
      let(:invalid_otp_data) { { email: existing_user.email, otp: 'wrong_otp', new_password: 'NewPass@123' } }

      it 'returns invalid OTP error' do
        post '/api/v1/reset_password', params: invalid_otp_data, as: :json
        expect(response).to have_http_status(422)
        expect(json['errors']).to eq('Invalid OTP')
      end
    end

    context 'with non-existent user' do
      let(:invalid_user_data) { { email: 'nonexistent@example.com', otp: '123456', new_password: 'NewPass@123' } }

      it 'returns user not found error' do
        post '/api/v1/reset_password', params: invalid_user_data, as: :json
        expect(response).to have_http_status(422)
        expect(json['errors']).to eq('User not found')
      end
    end
  end

  def json
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    puts "Failed to parse JSON response: #{response.body}"
    raise e
  end
end