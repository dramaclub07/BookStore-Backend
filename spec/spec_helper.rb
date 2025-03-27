require 'simplecov'
require 'simplecov_json_formatter'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/db/'
  add_group 'Services', 'app/services'
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  coverage_dir 'coverage'
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
end


# See https://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  # rspec-expectations config
  config.expect_with :rspec do |expectations|
    # Include chain clauses in custom matcher descriptions
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config
  config.mock_with :rspec do |mocks|
    # Verify partial doubles to prevent invalid mocks
    mocks.verify_partial_doubles = true
  end

  # Shared context metadata behavior
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Enable recommended RSpec settings for better testing experience
  # Filter specs with :focus tag
  config.filter_run_when_matching :focus

  # Persist example status between runs (ignore spec/examples.txt in git)
  # config.example_status_persistence_file_path = "spec/examples.txt"

  # Disable monkey patching for cleaner syntax
  config.disable_monkey_patching!

  # Enable warnings to catch potential issues
  config.warnings = true

  # Use documentation formatter for single-file runs
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  # Profile the 10 slowest examples
  # config.profile_examples = 10

  # Run specs in random order to detect order dependencies
  config.order = :random

  # Seed randomization for reproducible runs
  Kernel.srand config.seed
end