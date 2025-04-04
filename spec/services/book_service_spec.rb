require 'rails_helper'

RSpec.describe BooksService, type: :service do
  let(:redis) { double("Redis") }

  before do
    stub_const("BooksService::REDIS", redis)
    allow(redis).to receive(:get)
    allow(redis).to receive(:set)
    allow(redis).to receive(:expire)
    allow(redis).to receive(:keys).and_return(["books_page_1_sort_relevance_per_12"])
    allow(redis).to receive(:del)
  end

  describe '.get_books' do
    let!(:books) { create_list(:book, 15) }

    context 'when data is not in Redis' do
      it 'fetches books from the database and caches them' do
        result = described_class.get_books(1, 12, false, 'relevance')
        expect(result[:books].count).to eq(12)
        expect(result[:total_count]).to eq(15)
        expect(redis).to have_received(:set).with("books_page_1_sort_relevance_per_12", anything)
      end
    end

    context 'when data is in Redis' do
      let(:books_data) { described_class.get_books(1, 12, true, 'relevance') }

      before do
        allow(redis).to receive(:get).with("books_page_1_sort_relevance_per_12").and_return(books_data.to_json)
      end

      it 'fetches books from Redis' do
        result = described_class.get_books(1, 12, false, 'relevance')
        expect(result[:books].count).to eq(12)
      end
    end

    context 'with force_refresh' do
      it 'ignores Redis cache and refreshes data' do
        allow(redis).to receive(:get).with("books_page_1_sort_relevance_per_12").and_return({ books: [] }.to_json)
        described_class.get_books(1, 12, false, 'relevance')
        allow(redis).to receive(:get)
        result = described_class.get_books(1, 12, true, 'relevance')
      end
    end

  end

  describe '.create_single_book' do
    let(:params) { attributes_for(:book, book_name: 'Test Book', author_name: 'Test Author', book_mrp: 10.00) }

    it 'creates a book and clears cache' do
      result = described_class.create_single_book(params)
      expect(result[:success]).to be true
      expect(Book.count).to eq(1)
      expect(redis).to have_received(:keys).with("books_page_*")
      expect(redis).to have_received(:del).with("books_page_1_sort_relevance_per_12")
    end

    it 'returns errors if book creation fails' do
      result = described_class.create_single_book(params.merge(book_name: nil))
      expect(result[:success]).to be false
      expect(result[:errors]).to include("Book name can't be blank")
    end
  end

  describe '.create_books_from_csv' do
    let(:csv_content) do
      "book_name,author_name,book_mrp,discounted_price,quantity,book_details,genre,book_image\n" \
      "Test Book,Test Author,10.00,8.00,5,Details,Fiction,http://example.com/image.jpg"
    end
    let(:csv_file) { Tempfile.new(['books', '.csv']) }

    before do
      File.write(csv_file.path, csv_content)
      allow(csv_file).to receive(:path).and_return(csv_file.path)
    end

    after do
      csv_file.unlink
    end

    it 'creates books from CSV and clears cache' do
      result = described_class.create_books_from_csv(csv_file)
      expect(result[:success]).to be true
      expect(Book.count).to eq(1)
      expect(Book.first.book_name).to eq('Test Book')
      expect(redis).to have_received(:keys).with("books_page_*")
      expect(redis).to have_received(:del).with("books_page_1_sort_relevance_per_12")
    end
  end

  describe '.update_book' do
    let(:book) { create(:book) }

    it 'updates a book and clears cache' do
      result = described_class.update_book(book, { book_name: 'Updated Book' })
      expect(result[:success]).to be true
      expect(book.reload.book_name).to eq('Updated Book')
      expect(redis).to have_received(:keys).with("books_page_*")
      expect(redis).to have_received(:del).with("books_page_1_sort_relevance_per_12")
    end
  end

  describe '.toggle_is_deleted' do
    let(:book) { create(:book) }

    it 'toggles is_deleted and clears cache' do
      result = described_class.toggle_is_deleted(book)
      expect(result[:success]).to be true
      expect(book.reload.is_deleted).to be true
      expect(redis).to have_received(:keys).with("books_page_*")
      expect(redis).to have_received(:del).with("books_page_1_sort_relevance_per_12")
    end
  end

  describe '.destroy_book' do
    let(:book) { create(:book) }

    it 'soft deletes a book and clears cache' do
      result = described_class.destroy_book(book)
      expect(result[:success]).to be true
      expect(book.reload.is_deleted).to be true
      expect(redis).to have_received(:keys).with("books_page_*")
      expect(redis).to have_received(:del).with("books_page_1_sort_relevance_per_12")
    end
  end
end