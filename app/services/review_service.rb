class ReviewService
  def self.create_review(book, user, params)
    review = book.reviews.create(user: user, rating: params[:rating], comment: params[:comment])
    if review.persisted?
      BooksService.clear_related_cache # Clear the books cache after creating a review
      { success: true, review: review }
    else
      { success: false, errors: review.errors.full_messages }
    end
  end

  def self.get_reviews(book)
    book.reviews.includes(:user).map do |review|
      {
        id: review.id,
        user_id: review.user_id,
        user_name: review.user.full_name, # Include username (adjust to your User model field)
        book_id: review.book_id,
        rating: review.rating,
        comment: review.comment,
        created_at: review.created_at,
        updated_at: review.updated_at
      }
    end
  end

  def self.get_review(book, review_id)
    book.reviews.find_by(id: review_id)
  end

  def self.delete_review(book, review_id)
    review = book.reviews.find_by(id: review_id)
    return { success: false, message: "Review not found" } unless review

    review.destroy
    BooksService.clear_related_cache # Clear cache after deleting a review
    { success: true, message: "Review deleted successfully" }
  end
end