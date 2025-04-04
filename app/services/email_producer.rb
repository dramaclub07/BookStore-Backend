class EmailProducer
  def self.publish_email(email_type, payload)
    $exchange.publish(
      payload.to_json,
      routing_key: email_type,
      persistent: true
    )
  rescue StandardError => e
    raise
  end
end