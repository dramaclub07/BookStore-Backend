require 'rails_helper'
require 'redis'

RSpec.describe BooksService do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 10.0, is_deleted: false) }
  let(:redis) { BooksService::REDIS }
  let(:redis_key) { "books_page_1_sort_relevance_per_12" }

  before do
    # Clear Redis before each test
    redis.flushdb
  end

  describe '.get_books' do
    context 'when data is cached in Redis' do
      let(:cached_data) { { books: [{ id: book.id }], current_page: 1, total_pages: 1 }.to_json }

      before do
        redis.set(redis_key, cached_data)
      end

      it 'fetches from Redis without force_refresh' do
        result = BooksService.get_books(1, 12, false, 'relevance')
        expect(result[:books]).to eq([{ id: book.id }])
        expect(result[:current_page]).to eq(1)
      end
    end

    context 'when data is not cached or force_refresh is true' do
      before do
        # Ensure two books exist
        book # Create the first book
        create(:book, discounted_price: 5.0, is_deleted: false) # Second book
      end

      it 'fetches from database and caches when no cache exists' do
        expect(redis).to receive(:set).with(redis_key, anything)
        expect(redis).to receive(:expire).with(redis_key, 1.hour.to_i)
        result = BooksService.get_books(1, 12, false, 'relevance')
        expect(result[:books].size).to eq(2)
        expect(result[:total_pages]).to eq(1)
      end

      it 'fetches from database with force_refresh' do
        redis.set(redis_key, { books: [] }.to_json)
        expect(redis).to receive(:set).with(redis_key, anything)
        result = BooksService.get_books(1, 12, true, 'relevance')
        expect(result[:books].size).to eq(2)
      end

      context 'sorting' do
        let!(:book2) { create(:book, discounted_price: 15.0, is_deleted: false, created_at: 1.day.from_now) }

        before do
          # Ensure all books are created before sorting tests
          book # First book (10.0)
          create(:book, discounted_price: 5.0, is_deleted: false) # Second book (5.0)
        end

        it 'sorts by price_low_high' do
          result = BooksService.get_books(1, 12, true, 'price_low_high')
          expect(result[:books].size).to be > 0 # Debug: Ensure books are returned
          expect(result[:books].first[:discounted_price]).to eq(5.0)
        end

        it 'sorts by price_high_low' do
          result = BooksService.get_books(1, 12, true, 'price_high_low')
          expect(result[:books].size).to be > 0
          expect(result[:books].first[:discounted_price]).to eq(15.0)
        end

        it 'sorts by rating with reviews' do
          create(:review, book: book, rating: 5)
          create(:review, book: book2, rating: 3)
          result = BooksService.get_books(1, 12, true, 'rating')
          expect(result[:books].size).to be > 0
          expect(result[:books].first[:id]).to eq(book.id) # Higher avg rating
        end

        it 'sorts by rating without reviews' do
          result = BooksService.get_books(1, 12, true, 'rating')
          expect(result[:books].size).to be > 0
          expect(result[:books].map { |b| b[:rating] || 0 }).to all(eq(0))
        end

        it 'defaults to relevance for invalid sort_by' do
          result = BooksService.get_books(1, 12, true, 'invalid')
          expect(result[:books].size).to be > 0
          expect(result[:books].first[:id]).to eq(book2.id) # Newest first
        end
      end

      it 'handles empty result set' do
        Book.where(is_deleted: false).destroy_all
        result = BooksService.get_books(1, 12, true, 'relevance')
        expect(result[:books]).to be_empty
        expect(result[:total_count]).to eq(0)
      end
    end
  end

  describe '.create_book' do
    context 'with file' do
      let(:csv_file) { fixture_file_upload('books.csv', 'text/csv') }

      it 'calls create_books_from_csv' do
        expect(BooksService).to receive(:create_books_from_csv).with(csv_file)
        BooksService.create_book(file: csv_file)
      end
    end

    context 'without file' do
      it 'calls create_single_book' do
        params = { book_name: 'Test Book' }
        expect(BooksService).to receive(:create_single_book).with(params)
        BooksService.create_book(params)
      end
    end
  end

  describe '.create_single_book' do
    it 'creates a book successfully' do
      params = { book_name: 'New Book', author_name: 'Author', discounted_price: 10.0, book_mrp: 20.0 }
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.create_single_book(params)
      expect(result[:success]).to be true
      expect(result[:book].book_name).to eq('New Book')
    end

    it 'fails with invalid params' do
      params = { book_name: '' }
      result = BooksService.create_single_book(params)
      expect(result[:success]).to be false
      expect(result[:errors]).to include("Book name can't be blank")
    end
  end

  describe '.create_books_from_csv' do
    let(:valid_csv) { "book_name,author_name,book_mrp,discounted_price\nBook1,Author1,20,15" }
    let(:partial_csv) { "book_name,author_name,book_mrp,discounted_price\nBook1,Author1,20,15\n,,," }

    it 'creates books from valid CSV' do
      file = Tempfile.new('valid.csv')
      file.write(valid_csv)
      file.rewind
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.create_books_from_csv(file)
      expect(result[:success]).to be true
      expect(result[:books].size).to eq(1)
      expect(result[:books].first.book_name).to eq('Book1')
      file.close
      file.unlink
    end

    it 'handles partial success' do
      file = Tempfile.new('partial.csv')
      file.write(partial_csv)
      file.rewind
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.create_books_from_csv(file)
      expect(result[:success]).to be true
      expect(result[:books].size).to eq(1)
      expect(result[:books].first.book_name).to eq('Book1')
      file.close
      file.unlink
    end

    it 'fails with all invalid rows' do
      file = Tempfile.new('invalid.csv')
      file.write("book_name,author_name\n,Author1")
      file.rewind
      result = BooksService.create_books_from_csv(file)
      expect(result[:success]).to be false
      expect(result[:errors]).to eq(["Failed to create books from CSV"])
      file.close
      file.unlink
    end
  end

  describe '.update_book' do
    it 'updates a book successfully' do
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.update_book(book, { book_name: 'Updated Book' })
      expect(result[:success]).to be true
      expect(result[:book].book_name).to eq('Updated Book')
    end

    it 'fails with invalid params' do
      result = BooksService.update_book(book, { book_name: '' })
      expect(result[:success]).to be false
      expect(result[:errors]).to include("Book name can't be blank")
    end
  end

  describe '.toggle_is_deleted' do
    it 'toggles from false to true' do
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.toggle_is_deleted(book)
      expect(result[:success]).to be true
      expect(result[:book].is_deleted).to be true
    end

    it 'toggles from true to false' do
      book.update(is_deleted: true)
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.toggle_is_deleted(book)
      expect(result[:success]).to be true
      expect(result[:book].is_deleted).to be false
    end
  end

  describe '.destroy_book' do
    it 'marks book as deleted' do
      expect(BooksService).to receive(:clear_related_cache)
      result = BooksService.destroy_book(book)
      expect(result[:success]).to be true
      expect(book.reload.is_deleted).to be true
    end
  end

  describe '.clear_related_cache' do
    it 'clears all related cache keys' do
      redis.set('books_page_1_sort_relevance_per_12', 'data')
      redis.set('books_page_2_sort_price_per_12', 'data')
      BooksService.send(:clear_related_cache)
      expect(redis.keys('books_page_*')).to be_empty
    end

    it 'handles no cache keys' do
      expect { BooksService.send(:clear_related_cache) }.not_to raise_error
      expect(redis.keys('books_page_*')).to be_empty
    end
  end
end