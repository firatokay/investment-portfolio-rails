# Configure Redis connection for Sidekiq and other services
# Note: Rails 8 uses Solid Queue by default, so Redis is optional
# This is here for future Sidekiq integration
REDIS = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
