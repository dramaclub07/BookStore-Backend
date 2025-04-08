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

  # def self.create_address(user, params)
  #   address = user.addresses.new(params)
  #   if address.save
  #     REDIS.del("user_#{user.id}_addresses")
  #     { success: true, address: address }
  #   else
  #     { success: false, errors: address.errors.full_messages }
  #   end
  # end
  # app/services/address_service.rb
def self.create_address(user, params)
  address = user.addresses.new(params)
  if address.save
    if REDIS
      REDIS.del("user_#{user.id}_addresses") rescue Rails.logger.error("Failed to invalidate Redis cache: #{$!.message}")
    else
      Rails.logger.warn("Redis is not available, skipping cache invalidation for user_#{user.id}_addresses")
    end
    { success: true, address: address }
  else
    { success: false, errors: address.errors.full_messages }
  end
end
  

  def self.update_address(address, params)
    if params.blank? || params.to_h.empty?
      return { success: false, errors: ["At least one address attribute must be provided"] }
    end

    if address.update(params)
      REDIS.del("user_#{address.user_id}_addresses")
      { success: true, address: address }
    else
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.destroy_address(address)
    if address.destroy
      REDIS.del("user_#{address.user_id}_addresses")
      { success: true, message: "Address deleted successfully" }
    else
      { success: false, errors: ["Failed to delete address"] }
    end
  end
end