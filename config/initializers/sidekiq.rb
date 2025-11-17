require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Load the schedule from the YAML file
  schedule_file = Rails.root.join('config', 'sidekiq_schedule.yml')

  if File.exist?(schedule_file)
    schedule = YAML.load_file(schedule_file)
    Sidekiq.schedule = schedule if schedule
    Rails.logger.info "Sidekiq scheduler loaded: #{schedule.keys.join(', ')}"
  else
    Rails.logger.warn "Sidekiq schedule file not found: #{schedule_file}"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
