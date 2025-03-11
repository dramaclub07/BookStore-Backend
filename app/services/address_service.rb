class AddressService
  def self.create_address(user, params)
    address = user.addresses.new(params)
    if address.save
      { success: true, address: address }
    else
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.update_address(address, params)
    if address.update(params)
      { success: true, address: address }
    else
      { success: false, errors: address.errors.full_messages }
    end
  end

  def self.destroy_address(address)
    if address.destroy
      { success: true, message: "Address deleted successfully" }
    else
      { success: false, errors: ["Failed to delete address"] }
    end
  end
end
