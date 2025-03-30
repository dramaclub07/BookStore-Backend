class AddressService
  CACHE_EXPIRATION_TIME = 12.hours.to_i

  def self.get_addresses(user)
    cache_key = "user_#{user.id}_addresses"
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
      { success: true, address: address }
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
      { success: true, address: address }
    else
      log_error("Address update failed", address)
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.destroy_address(address)
    if address.update(is_deleted: true)
      clear_address_cache(address.user_id)
      log_success("Address soft-deleted", address)
      { success: true, message: "Address deleted successfully" }
    else
      log_error("Address deletion failed", address)
      { success: false, errors: address.errors.full_messages }
    end
  end

  private

  def self.clear_address_cache(user_id)
    REDIS.del("user_#{user_id}_addresses")
  end

  def self.log_success(action, address)
    Rails.logger.info("#{action} successfully: #{address.inspect}")
  end

  def self.log_error(action, address)
    Rails.logger.error("#{action}: #{address.errors.full_messages.join(', ')}")
  end

  def self.invalid_params_error
    { 
      success: false, 
      errors: ["At least one address attribute must be provided"] 
    }
  end
end