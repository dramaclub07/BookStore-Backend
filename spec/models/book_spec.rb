require 'rails_helper'

RSpec.describe Book, type: :model do
  # Factory setup
  let(:book) { build(:book, book_name: 'Test Book', author_name: 'John Doe', book_mrp: 100, discounted_price: 80, quantity: 5) }

  # Association tests
  describe 'associations' do
    it { should have_many(:orders).dependent(:destroy) }
    it { should have_many(:reviews).dependent(:destroy) }
  end

  # Validation tests
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(book).to be_valid
    end

    context 'book_name validation' do
      it { should validate_presence_of(:book_name) }

      it 'is invalid with a nil book_name' do
        book.book_name = nil
        expect(book).not_to be_valid
        expect(book.errors[:book_name]).to include("can't be blank")
      end

      it 'is invalid with an empty book_name' do
        book.book_name = ''
        expect(book).not_to be_valid
        expect(book.errors[:book_name]).to include("can't be blank")
      end
    end

    context 'author_name validation' do
      it { should validate_presence_of(:author_name) }

      it 'is invalid with a nil author_name' do
        book.author_name = nil
        expect(book).not_to be_valid
        expect(book.errors[:author_name]).to include("can't be blank")
      end

      it 'is invalid with an empty author_name' do
        book.author_name = ''
        expect(book).not_to be_valid
        expect(book.errors[:author_name]).to include("can't be blank")
      end
    end

    context 'book_mrp validation' do
      it { should validate_presence_of(:book_mrp) }
      it { should validate_numericality_of(:book_mrp).is_greater_than(0) }

      it 'is invalid with a nil book_mrp' do
        book.book_mrp = nil
        expect(book).not_to be_valid
        expect(book.errors[:book_mrp]).to include("can't be blank")
      end

      it 'is invalid with a book_mrp of 0' do
        book.book_mrp = 0
        expect(book).not_to be_valid
        expect(book.errors[:book_mrp]).to include('must be greater than 0')
      end

      it 'is invalid with a negative book_mrp' do
        book.book_mrp = -10
        expect(book).not_to be_valid
        expect(book.errors[:book_mrp]).to include('must be greater than 0')
      end

      it 'is invalid with a non-numeric book_mrp' do
        book.book_mrp = 'abc'
        expect(book).not_to be_valid
        expect(book.errors[:book_mrp]).to include('is not a number')
      end
    end

    context 'discounted_price validation' do
      it { should validate_numericality_of(:discounted_price).is_greater_than_or_equal_to(0).allow_nil }

      it 'is valid with a nil discounted_price' do
        book.discounted_price = nil
        expect(book).to be_valid
      end

      it 'is valid with a discounted_price of 0' do
        book.discounted_price = 0
        expect(book).to be_valid
      end

      it 'is valid with a positive discounted_price' do
        book.discounted_price = 50
        expect(book).to be_valid
      end

      it 'is invalid with a negative discounted_price' do
        book.discounted_price = -10
        expect(book).not_to be_valid
        expect(book.errors[:discounted_price]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with a non-numeric discounted_price' do
        book.discounted_price = 'abc'
        expect(book).not_to be_valid
        expect(book.errors[:discounted_price]).to include('is not a number')
      end
    end

    context 'quantity validation' do
      it { should validate_numericality_of(:quantity).only_integer.is_greater_than_or_equal_to(0).allow_nil }

      it 'is valid with a nil quantity' do
        book.quantity = nil
        expect(book).to be_valid
      end

      it 'is valid with a quantity of 0' do
        book.quantity = 0
        expect(book).to be_valid
      end

      it 'is valid with a positive integer quantity' do
        book.quantity = 5
        expect(book).to be_valid
      end

      it 'is invalid with a negative quantity' do
        book.quantity = -1
        expect(book).not_to be_valid
        expect(book.errors[:quantity]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with a non-integer quantity' do
        book.quantity = 5.5
        expect(book).not_to be_valid
        expect(book.errors[:quantity]).to include('must be an integer')
      end

      it 'is invalid with a non-numeric quantity' do
        book.quantity = 'abc'
        expect(book).not_to be_valid
        expect(book.errors[:quantity]).to include('is not a number')
      end
    end
  end

  # Instance method tests
  describe '#rating' do
    let(:book_with_reviews) { create(:book) }

    context 'when there are no reviews' do
      it 'returns 0' do
        expect(book_with_reviews.rating).to eq(0)
      end
    end

    context 'when there are reviews' do
      before do
        create(:review, book: book_with_reviews, rating: 4)
        create(:review, book: book_with_reviews, rating: 5)
        create(:review, book: book_with_reviews, rating: 3)
      end

      it 'returns the average rating rounded to 1 decimal place' do
        expect(book_with_reviews.rating).to eq(4.0) # (4 + 5 + 3) / 3 = 4.0
      end
    end
  end

  describe '#rating_count' do
    let(:book_with_reviews) { create(:book) }

    context 'when there are no reviews' do
      it 'returns 0' do
        expect(book_with_reviews.rating_count).to eq(0)
      end
    end

    context 'when there are reviews' do
      before do
        create_list(:review, 3, book: book_with_reviews)
      end

      it 'returns the total number of reviews' do
        expect(book_with_reviews.rating_count).to eq(3)
      end
    end
  end

  # Association behavior tests
  describe 'dependent: :destroy' do
    let(:book_with_orders) { create(:book) }
    let(:book_with_reviews) { create(:book) }

    it 'destroys associated orders when book is destroyed' do
      create(:order, book: book_with_orders)
      expect { book_with_orders.destroy }.to change(Order, :count).by(-1)
    end

    it 'destroys associated reviews when book is destroyed' do
      create(:review, book: book_with_reviews)
      expect { book_with_reviews.destroy }.to change(Review, :count).by(-1)
    end
  end
end