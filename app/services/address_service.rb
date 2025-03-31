class AddressService
  CACHE_EXPIRATION_TIME = 12.hours.to_i

  def self.get_addresses(user)
    cache_key = "user_#{user.id}_#{jwt_fingerprint(user)}_addresses"
    cached_addresses = REDIS.get(cache_key)

    if cached_addresses
      { success: true, addresses: JSON.parse(cached_addresses) }
    else
      addresses = user.addresses.where(is_deleted: false).order(created_at: :desc).as_json
      REDIS.set(cache_key, addresses.to_json)
      REDIS.expire(cache_key, CACHE_EXPIRATION_TIME)
      { success: true, addresses: addresses }
    end
  end

  def self.create_address(user, params)
    address = user.addresses.new(params)
    if address.save
      clear_address_cache(user.id)
      log_success("Address created", address)
      { 
        success: true, 
        address: address,
        access_token: refresh_user_token(user)
      }
    else
      log_error("Address creation failed", address)
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.update_address(address, params)
    return invalid_params_error if params.blank?
    
    if address.update(params)
      clear_address_cache(address.user_id)
      log_success("Address updated", address)
      { 
        success: true, 
        address: address,
        access_token: refresh_user_token(address.user)
      }
    else
      log_error("Address update failed", address)
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.destroy_address(address)
    if address.update(is_deleted: true)
      clear_address_cache(address.user_id)
      log_success("Address soft-deleted", address)
      { 
        success: true, 
        message: "Address deleted successfully",
        access_token: refresh_user_token(address.user)
      }
    else
      log_error("Address deletion failed", address)
      { success: false, errors: address.errors.full_messages }
    end
  end

  private

  def self.clear_address_cache(user_id)
    user = User.find_by(id: user_id)
    return unless user

    REDIS.del("user_#{user_id}_#{jwt_fingerprint(user)}_addresses")
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to clear address cache: #{e.message}"
  end

  def self.log_success(action, address)
    Rails.logger.info("[AddressService] #{action} successfully for user #{address.user_id}")
  end

  def self.log_error(action, address)
    Rails.logger.error("[AddressService] #{action} for user #{address.user_id}: #{address.errors.full_messages.join(', ')}")
  end

  def self.invalid_params_error
    { 
      success: false, 
      errors: ["At least one address attribute must be provided"] 
    }
  end

  def self.refresh_user_token(user)
    JwtService.encode_access_token(
      user_id: user.id,
      role: user.role,
      address_updated_at: Time.now.to_i
    )
  end

  def self.jwt_fingerprint(user)
    # Use user's JWT token first 16 chars + their ID + current minute
    token_part = JwtService.encode_access_token(user_id: user.id)[0..15] rescue 'default'
    Digest::SHA256.hexdigest("#{user.id}-#{token_part}-#{Time.now.to_i / 60}")
  end
end