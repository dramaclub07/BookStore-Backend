namespace :db do
  desc "Truncate the oauth_states table"
  task truncate_oauth_states: :environment do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE oauth_states")
    puts "oauth_states table truncated successfully."
  end
end