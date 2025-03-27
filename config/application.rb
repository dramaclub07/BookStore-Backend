require_relative "boot"

require "rails/all"
require 'dotenv/load' 

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    config.autoload_paths << Rails.root.join('app/lib')
    config.autoload_paths << Rails.root.join('app/services')
    config.eager_load_paths << Rails.root.join('app/services')
    config.action_dispatch.cookies_same_site_protection = :none
    config.session_store :cookie_store, key: "_your_app_session", domain: :all, same_site: :none, secure: Rails.env.production?

    



    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    config.action_controller.raise_on_missing_callback_actions = false


    # Configuration for the application, engines, and railties goes here.
    #
    config.generators do |g|
      g.test_framework :rspec,
                       request_specs: false, # Disable request specs generation
                       integration_tool: :rspec # Explicitly define integration tool
    end
    
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    
  end
end
