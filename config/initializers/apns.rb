# APNS (Apple Push Notification Service) Configuration
require 'apnotic'

module APNS
  class << self
    def connection
      @connection ||= create_connection
    end

    private

    def create_connection
      # APNS環境を環境変数で制御（TestFlight対応）
      # APNS_ENVIRONMENT=production でProduction APNS使用
      # APNS_ENVIRONMENT=sandbox でSandbox APNS使用（デフォルト）
      use_production = ENV['APNS_ENVIRONMENT'] == 'production' || Rails.env.production?
      
      if use_production
        # 本番環境/TestFlight: Production APNS
        gateway = 'api.push.apple.com'
        Rails.logger.info "Using Production APNS: #{gateway}"
      else
        # 開発・テスト環境: Sandbox APNS
        gateway = 'api.sandbox.push.apple.com'
        Rails.logger.info "Using Sandbox APNS: #{gateway}"
      end

      # APNSの認証情報を環境変数から取得
      # 以下のいずれかの方法で認証可能:
      # 1. P8キーファイルを使用（推奨）
      # 2. P12証明書ファイルを使用

      if ENV['APNS_AUTH_KEY_PATH'] && ENV['APNS_KEY_ID'] && ENV['APNS_TEAM_ID']
        # P8キーファイルを使用
        Apnotic::Connection.new(
          auth_method: :token,
          cert_path: ENV['APNS_AUTH_KEY_PATH'],
          key_id: ENV['APNS_KEY_ID'],
          team_id: ENV['APNS_TEAM_ID'],
          url: "https://#{gateway}:443"
        )
      elsif ENV['APNS_CERT_PATH']
        # P12証明書ファイルを使用
        Apnotic::Connection.new(
          cert_path: ENV['APNS_CERT_PATH'],
          cert_pass: ENV['APNS_CERT_PASS'] || '',
          url: "https://#{gateway}:443"
        )
      else
        Rails.logger.warn "APNS credentials not configured. Set APNS_AUTH_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID or APNS_CERT_PATH environment variables."
        nil
      end
    rescue => e
      Rails.logger.error "Failed to create APNS connection: #{e.message}"
      nil
    end
  end
end
