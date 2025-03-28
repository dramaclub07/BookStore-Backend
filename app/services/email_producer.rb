class EmailProducer
  def self.publish_email(email_type, payload)
    $exchange.publish(
      payload.to_json,
      routing_key: email_type,
      persistent: true
    )
    puts "Published email job to exchange with type '#{email_type}'"
  rescue StandardError => e
    puts "Error publishing email: #{e.message}"
    Rails.logger.error "Email publishing failed: #{e.message}"
    raise # Re-raise to allow calling code to handle
  end
end