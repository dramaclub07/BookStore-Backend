class AddressService
  CACHE_EXPIRATION_TIME = 10.minutes.to_i

  def self.get_addresses(user)
    cache_key = "user_#{user.id}_addresses"
    cached_addresses = REDIS.get(cache_key)

    if cached_addresses
      addresses = JSON.parse(cached_addresses)
    else
      addresses = user.addresses.as_json
      REDIS.set(cache_key, addresses.to_json)
      REDIS.expire(cache_key, CACHE_EXPIRATION_TIME)
    end

    { success: true, addresses: addresses }
  end

  def self.create_address(user, params)
    address = user.addresses.new(params)
    if address.save
      REDIS.del("user_#{user.id}_addresses")
      Rails.logger.info("Address created successfully: #{address.inspect}")
      { success: true, address: address }
    else
      Rails.logger.error("Failed to create address: #{address.errors.full_messages.join(', ')}")
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.update_address(address, params)
    if address.update(params)
      REDIS.del("user_#{address.user_id}_addresses")
      Rails.logger.info("Address updated successfully: #{address.inspect}")
      { success: true, address: address }
    else
      Rails.logger.error("Failed to update address: #{address.errors.full_messages.join(', ')}")
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.destroy_address(address)
    if address.destroy
      REDIS.del("user_#{address.user_id}_addresses")
      Rails.logger.info("Address deleted successfully: #{address.id}")
      { success: true, message: "Address deleted successfully" }
    else
      Rails.logger.error("Failed to delete address: #{address.errors.full_messages.join(', ')}")
      { success: false, errors: ["Failed to delete address"] }
    end
  end
end