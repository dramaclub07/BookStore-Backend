# config/initializers/redis.rb
require 'redis'

Rails.logger.info("REDIS_URL environment variable: #{ENV['REDIS_URL'].inspect}")
if ENV["REDIS_URL"].present?
  REDIS = Redis.new(url: ENV["REDIS_URL"])
  Rails.logger.info("Successfully initialized Redis with URL: #{ENV['REDIS_URL']}")
else
  Rails.logger.warn("REDIS_URL is not set. Redis functionality will be disabled.")
  REDIS = nil
end