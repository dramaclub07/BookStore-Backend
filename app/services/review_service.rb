class ReviewService
  def self.create_review(book, user, params)
    review = book.reviews.create(user: user, rating: params[:rating], comment: params[:comment])
    if review.persisted?
      { success: true, review: review }
    else
      { success: false, errors: review.errors.full_messages }
    end
  end

  def self.get_reviews(book)
    book.reviews
  end

  def self.get_review(book, review_id)
    book.reviews.find_by(id: review_id)
  end

  def self.delete_review(book, review_id)
    review = book.reviews.find_by(id: review_id)
    return { success: false, message: "Review not found" } unless review

    review.destroy
    { success: true, message: "Review deleted successfully" }
  end
end