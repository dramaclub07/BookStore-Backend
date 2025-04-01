require 'rails_helper'

# spec/models/oauth_state_spec.rb
RSpec.describe OauthState, type: :model do
  it { should validate_presence_of(:state) }
  it { should validate_uniqueness_of(:state) }
end
