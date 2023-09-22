# frozen_string_literal:true

REDIS_CLIENT = Redis.new(db: Rails.application.config.redis_db)
