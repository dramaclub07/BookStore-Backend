# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
require 'rails_helper'
require 'simplecov'
SimpleCov.start 'rails'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
Rails.application.eager_load!
require 'rspec/rails'
require 'rswag/specs'
require 'database_cleaner/active_record'
require 'shoulda/matchers'

# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods  

  # Set fixture paths
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  # Use transactional fixtures for better performance
  config.use_transactional_fixtures = true

  # DatabaseCleaner setup (for JS/system tests only)
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  # Use truncation for JavaScript and system tests
  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :deletion
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Allow focus on specific tests with `:focus` metadata
  config.filter_run_when_matching :focus

  # Randomize test order to identify order dependencies
  config.order = :random

  # Allow using `byebug` or `binding.irb` in tests
  config.include ActiveSupport::Testing::TimeHelpers

  # Remove Rails internal backtrace lines from errors
  config.filter_rails_from_backtrace!
end

# Shoulda Matchers Configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
