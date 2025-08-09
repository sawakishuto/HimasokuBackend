require "redis"
require "json"
require "net/http"

# マイグレーション時やRedis URLが設定されていない場合はスキップ
unless ENV["REDIS_URL"].nil? || ENV["RAILS_ENV"] == "test" || defined?(Rails::Console)
  begin
    redis = Redis.new(url: ENV["REDIS_URL"] || "redis://redis:6379/1")

    uri = URI("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
    response = Net::HTTP.get(uri)
    certs = JSON.parse(response)

    # Redisに保存
    redis.set("firebase_auth_certificates", certs.to_json)
  rescue => e
    Rails.logger.warn "Redis connection failed: #{e.message}"
  end
end