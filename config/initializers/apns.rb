# frozen_string_literal: true

# APNS (Apple Push Notification Service) 設定
#
# P8 トークン認証（推奨方式）で apnotic を使い、コネクションプール経由で送信する。
# ES256 署名の不具合は config/initializers/apnotic_es256_patch.rb で修正済み。
#
# 必須 ENV:
#   APNS_TEAM_ID    Apple Developer の Team ID
#   APNS_KEY_ID     P8 認証キーの Key ID
#   APNS_P8_CONTENT P8 認証キーの内容（PEM 文字列）
# 任意 ENV:
#   APNS_BUNDLE_ID    トピック（既定: com.sawaki.HimaSoku）
#   APNS_ENVIRONMENT  "production" | "sandbox"（既定: Rails.env が production なら production）
#   APNS_POOL_SIZE    コネクションプールのサイズ（既定: 5）
require 'apnotic'
require 'openssl'
require 'stringio'

module APNS
  DEFAULT_BUNDLE_ID = 'com.sawaki.HimaSoku'

  class << self
    # 通知を 1 件送信し、正規化した結果ハッシュを返す。
    #
    # 返り値: { success:, status:, body:, headers:, apns_id: }
    #         失敗時: { success: false, status:, error: }
    def push(device_token, alert:, badge: 1, sound: 'default', category: nil,
             mutable_content: false, content_available: false, custom: {},
             priority: 10, topic: bundle_id)
      token = device_token.to_s.strip
      pool.with do |connection|
        notification = build_notification(
          token,
          alert: alert, badge: badge, sound: sound, category: category,
          mutable_content: mutable_content, content_available: content_available,
          custom: custom, priority: priority, topic: topic
        )
        normalize(connection.push(notification))
      end
    rescue => e
      Rails.logger.error "APNS push failed for #{device_token}: #{e.class}: #{e.message}"
      { success: false, status: nil, error: e.message }
    end

    # test/apns エンドポイント用: 現在の設定でプロバイダトークン(JWT)を生成する。
    def generate_jwt_token
      Apnotic::ProviderToken.new(p8_content, team_id, key_id).token
    end

    def bundle_id
      ENV.fetch('APNS_BUNDLE_ID', DEFAULT_BUNDLE_ID)
    end

    private

    def pool
      @pool ||= Apnotic::ConnectionPool.new(
        {
          auth_method: :token,
          cert_path:   cert_path,
          key_id:      key_id,
          team_id:     team_id,
          url:         gateway_url
        },
        size: pool_size, timeout: 5
      ) do |connection|
        connection.on(:error) { |exception| Rails.logger.error "APNS connection error: #{exception}" }
      end
    end

    def build_notification(token, alert:, badge:, sound:, category:,
                           mutable_content:, content_available:, custom:, priority:, topic:)
      Apnotic::Notification.new(token).tap do |n|
        n.topic             = topic
        n.alert             = alert
        n.badge             = badge   if badge
        n.sound             = sound   if sound
        n.category          = category if category
        n.mutable_content   = 1 if mutable_content
        n.content_available = 1 if content_available
        n.priority          = priority
        n.push_type         = 'alert'
        n.custom_payload     = custom if custom && !custom.empty?
      end
    end

    def normalize(response)
      return { success: false, status: nil, error: 'no response from APNS' } unless response

      unless response.ok?
        reason = (response.body.is_a?(Hash) ? response.body['reason'] : nil)
        Rails.logger.error "APNS rejected (status=#{response.status}, reason=#{reason || 'unknown'})"
      end

      {
        success: response.ok?,
        status:  response.status.to_i,
        body:    response.body,
        headers: response.headers,
        apns_id: response.headers && response.headers['apns-id']
      }
    end

    # ---- 設定値 -------------------------------------------------------------

    def team_id
      ENV.fetch('APNS_TEAM_ID')
    end

    def key_id
      ENV.fetch('APNS_KEY_ID')
    end

    def p8_content
      ENV.fetch('APNS_P8_CONTENT').strip
    end

    def pool_size
      ENV.fetch('APNS_POOL_SIZE', 5).to_i
    end

    def production?
      env = ENV.fetch('APNS_ENVIRONMENT', Rails.env).to_s
      env == 'production'
    end

    def gateway_url
      production? ? Apnotic::APPLE_PRODUCTION_SERVER_URL : Apnotic::APPLE_DEVELOPMENT_SERVER_URL
    end

    # P8 の内容をプロセス起動中に一度だけ一時ファイルへ書き出し、そのパスを使う。
    # （apnotic はコネクションごとに cert_path を遅延読み込みするため、共有 IO の
    #   競合を避ける目的で実ファイルにする。Tempfile 参照は GC による unlink を
    #   防ぐため保持しておく。）
    def cert_path
      @cert_path ||= begin
        require 'tempfile'
        file = Tempfile.new(['apns_auth_key', '.p8'])
        file.write(p8_content)
        file.flush
        file.close
        @cert_tempfile = file
        file.path
      end
    end
  end
end
