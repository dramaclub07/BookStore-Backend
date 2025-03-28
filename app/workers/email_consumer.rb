require 'json'

class EmailConsumer
  def self.start
    $channel ||= $bunny.create_channel
    
    otp_queue = $channel.queue("otp_email_queue", durable: true)
    otp_queue.bind($exchange, routing_key: "send_otp")

    welcome_queue = $channel.queue("welcome_email_queue", durable: true)
    welcome_queue.bind($exchange, routing_key: "welcome_email")

    order_queue = $channel.queue("order_email_queue", durable: true)
    order_queue.bind($exchange, routing_key: "order_confirmation_email")

    cancel_queue = $channel.queue("cancel_email_queue", durable: true)
    cancel_queue.bind($exchange, routing_key: "cancel_order_email")

    # Added queue for reset confirmation
    reset_queue = $channel.queue("reset_email_queue", durable: true)
    reset_queue.bind($exchange, routing_key: "reset_confirmation_email")

    puts "Waiting for email messages. Press CTRL+C to exit."

    [otp_queue, welcome_queue, order_queue, cancel_queue, reset_queue].each do |queue|
      Thread.new do
        queue.subscribe(manual_ack: true, block: false) do |delivery_info, _properties, body|
          begin
            payload = JSON.parse(body)
            process_email(payload, delivery_info.routing_key)
            $channel.ack(delivery_info.delivery_tag)
          rescue StandardError => e
            $channel.nack(delivery_info.delivery_tag)
            raise
          end
        end
      end
    end

    begin
      loop { sleep 1 }
    rescue Interrupt
      $channel.close
      $bunny.close
      puts "Shutting down email consumer..."
    end
  end

  def self.process_email(payload, routing_key)
    user = User.find(payload["user_id"])

    case routing_key
    when "send_otp"
      UserMailer.send_otp(user, payload["otp"], Time.parse(payload["expiry_time"])).deliver_now
    when "welcome_email"
      UserMailer.welcome_email(user).deliver_now
    when "order_confirmation_email"
      order = Order.find(payload["order_id"])
      UserMailer.order_confirmation_email(user, order).deliver_now
    when "cancel_order_email"
      order = Order.find(payload["order_id"])
      UserMailer.cancel_order_email(user, order).deliver_now
    when "reset_confirmation_email"
      UserMailer.reset_confirmation_email(user).deliver_now
    else
      puts "Unknown email type: #{routing_key}"
    end

    puts "Processed email: #{routing_key} for user #{user.id}"
  rescue StandardError => e
    puts "Error processing email: #{e.message}"
    Rails.logger.error "Email processing failed: #{e.message}"
    raise
  end
end