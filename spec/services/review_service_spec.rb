require 'rails_helper'

RSpec.describe ReviewService do
  let!(:user) { create(:user, full_name: "Demetrius Braun") }  
  let!(:book) { create(:book) }
  let!(:review) { create(:review, user: user, book: book, rating: 4, comment: "Good book") }
RSpec.describe UserService do
  describe '.signup' do
    let(:user_params) do
      {
        full_name: 'Akshay Katoch',
        email: 'testuser@gmail.com',
        password: 'Password@123',
        mobile_number: '9876543210'
      }
    end

    context 'when valid parameters are provided' do
      it 'creates a new user and returns a successful result' do
        result = UserService.signup(user_params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.error).to be_nil
      end
    end

    context 'when invalid parameters are provided' do
      it 'returns an error if email is missing' do
        user_params[:email] = nil

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include("Email can't be blank")
      end

      it 'returns an error if password is too short' do
        user_params[:password] = '123'

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include("Password is too short")
      end

      it 'returns an error if email is already taken' do
        create(:user, email: user_params[:email])

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include('Email has already been taken')
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an error message' do
        allow(User).to receive(:new).and_raise(StandardError.new('Unexpected error'))

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include('An unexpected error occurred: Unexpected error')
      end
    end
  end

  describe ".get_reviews" do
    it "returns all reviews for a book" do
      reviews = ReviewService.get_reviews(book)

      expect(reviews).to include(
        a_hash_including(
          id: review.id,
          user_id: review.user_id,
          user_name: review.user.full_name, # Ensure this matches your User model
          book_id: review.book_id,
          rating: review.rating,
          comment: review.comment
        )
      )
    end
  end
  describe '.login' do
    let(:user) { create(:user, password: 'Password@123') }

    context 'when valid credentials are provided' do
      it 'returns a success result with a token' do
        result = UserService.login(user.email, 'Password@123')

        expect(result).to be_success
        expect(result.user).to eq(user)
        expect(result.token).to be_present
      end
    end

    context 'when invalid credentials are provided' do
      it 'returns an error if email is incorrect' do
        result = UserService.login('wrongemail@gmail.com', 'Password@123')

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid email or password')
      end

      it 'returns an error if password is incorrect' do
        result = UserService.login(user.email, 'WrongPassword')

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid email or password')
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an error message' do
        allow(User).to receive(:find_by).and_raise(StandardError.new('Unexpected error'))

        result = UserService.login(user.email, 'Password@123')

        expect(result).not_to be_success
        expect(result.error).to include('An unexpected error occurred: Unexpected error')
      end
    end
  end
end
end