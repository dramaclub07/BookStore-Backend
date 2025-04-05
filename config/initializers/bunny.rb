require 'bunny'

begin
  raise "RABBITMQ_URL is not set" unless ENV["RABBITMQ_URL"]

  $bunny = Bunny.new(
    ENV["RABBITMQ_URL"],
    ssl: true,                  
    port: 5671,                   
    verify_peer: true,            
    ssl_ca_file: "C:/path/to/ca_certificate.pem",     
    ssl_cert_file: "C:/path/to/client_certificate.pem", 
    ssl_key_file: "C:/path/to/client_key.pem",       
    automatically_recover: true,  
    recovery_attempts: 3,         
    recovery_interval: 30       
  )
  $bunny.start
  puts "Connected to RabbitMQ successfully!"
  
  $channel = $bunny.create_channel
  $exchange = $channel.direct("email_exchange", durable: true)
rescue Bunny::TCPConnectionFailed => e
  puts "TCP connection failed: #{e.message}"
rescue Bunny::PossibleAuthenticationFailureError => e
  puts "Authentication error: #{e.message}"
rescue StandardError => e
  puts "Error connecting to RabbitMQ: #{e.message}"
ensure
end