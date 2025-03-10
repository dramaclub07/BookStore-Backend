require 'rails_helper'

RSpec.describe 'Addresses API', type: :request do
  let!(:user) { create(:user) }
  let!(:auth_token) { JwtService.encode(user_id: user.id) }
  let!(:headers) { { 'Authorization' => "Bearer #{auth_token}", 'Content-Type' => 'application/json' } }
  let!(:addresses) { create_list(:address, 5, user: user) }
  let(:address_id) { addresses.first.id }

  describe 'GET /api/v1/addresses' do
    it 'returns all addresses of the user' do
      get '/api/v1/addresses', headers: headers

      expect(response).to have_http_status(:ok)
      parsed_response = json
      expect(parsed_response[:success]).to eq(true)
      expect(parsed_response[:addresses].size).to eq(5)
    end
  end

  describe 'GET /api/v1/addresses/:id' do
    context 'when the address exists' do
      it 'returns the address' do
        get "/api/v1/addresses/#{address_id}", headers: headers

        expect(response).to have_http_status(:ok)
        parsed_response = json
        expect(parsed_response[:success]).to eq(true)
        expect(parsed_response[:address][:id]).to eq(address_id)
      end
    end

    context 'when the address does not exist' do
      it 'returns not found' do
        get "/api/v1/addresses/9999", headers: headers

        expect(response).to have_http_status(:not_found)
        parsed_response = json
        expect(parsed_response[:success]).to eq(false)
        expect(parsed_response[:error]).to eq('Address not found')
      end
    end
  end

  describe 'POST /api/v1/addresses/create' do
    let(:valid_attributes) { { address: attributes_for(:address) } }

    context 'when request is valid' do
      it 'creates an address' do
        post '/api/v1/addresses/create', params: valid_attributes.to_json, headers: headers

        expect(response).to have_http_status(:created)
        parsed_response = json
        expect(parsed_response[:success]).to eq(true)
        expect(parsed_response[:address][:street]).to eq(valid_attributes[:address][:street])
      end
    end

    context 'when request is invalid' do
      it 'returns validation errors' do
        post '/api/v1/addresses/create', params: { address: { street: '' } }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = json
        expect(parsed_response[:success]).to eq(false)
        expect(parsed_response[:errors]).to include("Street can't be blank")
      end
    end
  end

  describe 'PUT /api/v1/addresses/:id' do
    let(:updated_attributes) { { address: { city: 'Los Angeles' } } }

    context 'when the address exists' do
      it 'updates the address' do
        put "/api/v1/addresses/#{address_id}", params: updated_attributes.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        parsed_response = json
        expect(parsed_response[:success]).to eq(true)
        expect(parsed_response[:address][:city]).to eq('Los Angeles')
      end
    end

    context 'when the address does not exist' do
      it 'returns not found' do
        put "/api/v1/addresses/9999", params: updated_attributes.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
        parsed_response = json
        expect(parsed_response[:success]).to eq(false)
        expect(parsed_response[:error]).to eq('Address not found')
      end
    end
  end

  describe 'DELETE /api/v1/addresses/:id' do
    context 'when the address exists' do
      it 'deletes the address' do
        delete "/api/v1/addresses/#{address_id}", headers: headers

        expect(response).to have_http_status(:ok)
        parsed_response = json
        expect(parsed_response[:success]).to eq(true)
        expect(parsed_response[:message]).to eq('Address deleted successfully')
      end
    end

    context 'when the address does not exist' do
      it 'returns not found' do
        delete "/api/v1/addresses/9999", headers: headers

        expect(response).to have_http_status(:not_found)
        parsed_response = json
        expect(parsed_response[:success]).to eq(false)
        expect(parsed_response[:error]).to eq('Address not found')
      end
    end
  end

  # Helper method to parse JSON response
  def json
    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError => e
    puts "Failed to parse JSON response: #{response.body}"
    raise e
  end
end
