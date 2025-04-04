require 'bunny'

begin
  $bunny = Bunny.new(ENV["RABBITMQ_URL"], automatically_recover: true)
  $bunny.start
  $channel = $bunny.create_channel
  $exchange = $channel.direct("email_exchange", durable: true)
rescue Bunny::TCPConnectionFailed => e
  puts "Error connecting to RabbitMQ: #{e.message}"
end