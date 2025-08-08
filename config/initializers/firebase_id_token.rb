require "net/http"
require "json"
require "redis"
require "jwt"
require "openssl"

module FirebaseIdToken
  class TokenVerifier
    CERTS_URI = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

    def initialize
      redis_url = ENV["REDIS_URL"] || "redis://redis:6379/1"
      @redis = Redis.new(url: redis_url)
    end

    # Redisから公開鍵を取得
    def get_certs_from_redis
      @redis.get("firebase_auth_certificates")
    end

    # Redisに公開鍵を保存
    def save_certs_to_redis
      uri = URI.parse(CERTS_URI)
      response = Net::HTTP.get_response(uri)
      certs = JSON.parse(response)
      @redis.set("firebase_auth_certificates", certs.to_json)
    rescue => e
      Rails.logger.error "Failed to fetch Firebase certs: #{e.message}"
      nil
    end

    # IDトークンを検証
    def verify_id_token(id_token)
      return nil if id_token.nil?

      certs = get_certs_from_redis

      if certs.nil?
        puts "No certificates found in Redis"
        puts "Fetching certificates from Google"
        certs = save_certs_to_redis
        return nil if certs.nil?
      end
      certs = JSON.parse(certs)
      header = JWT.decode(id_token, nil, false)[1]
      # puts header
      # puts certs
      kid = header["kid"]
      cert = certs[kid]
      # puts cert

      if cert.nil?
        Rails.logger.error "No certificate found for kid: #{kid}"
        return nil
      end

      public_key = OpenSSL::X509::Certificate.new(cert).public_key
      # puts public_key
      begin
        payload = JWT.decode(id_token, public_key, true, { algorithm: "RS256" })
        payload.first
      rescue JWT::DecodeError => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        nil
      end
    end
  end
end