class OauthState < ApplicationRecord
  validates :state, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.cleanup_expired
    where('expires_at < ?', Time.current).delete_all
  end
end