# APNS (Apple Push Notification Service) Configuration
require 'apnotic'
require 'jwt'
require 'openssl'
require 'net/http'
require 'uri'
require 'json'
require 'socket'

module APNS
  class << self
    def connection
      # JWTトークンの期限切れ問題を回避するため、毎回新しい接続を作成
      create_connection
    end
    
    # curlと同じ方式でJWTトークンを生成
    def generate_jwt_token
      team_id = ENV.fetch('APNS_TEAM_ID')
      key_id = ENV.fetch('APNS_KEY_ID')
      p8_content = ENV.fetch('APNS_P8_CONTENT')
      
      Rails.logger.info "--- JWT Token Generation ---"
      Rails.logger.info "Team ID: #{team_id}"
      Rails.logger.info "Key ID: #{key_id}"
      
      begin
        # P8キーを読み込む（正しい方法）
        private_key = OpenSSL::PKey.read(p8_content)
        Rails.logger.info "Private key loaded successfully"
        
        # JWT ペイロード
        iat = Time.now.to_i
        jwt_payload = {
          "iss": team_id,
          "iat": iat
        }
        
        # JWT ヘッダー
        jwt_header = {
          "alg": "ES256",
          "kid": key_id
        }
        
        Rails.logger.info "JWT Payload: #{jwt_payload.inspect}"
        Rails.logger.info "JWT Header: #{jwt_header.inspect}"
        Rails.logger.info "JWT will be valid from: #{Time.at(iat)} to #{Time.at(iat + 3600)}"
        
        # JWTトークンを生成
        token = JWT.encode(jwt_payload, private_key, 'ES256', jwt_header)
        
        Rails.logger.info "Generated JWT Token: #{token[0..50]}..."
        Rails.logger.info "JWT Token length: #{token.length}"
        
        # JWTトークンの構造を確認（デコードは不要）
        parts = token.split('.')
        if parts.length == 3
          Rails.logger.info "JWT structure is valid (3 parts)"
          header = Base64.decode64(parts[0])
          payload = Base64.decode64(parts[1])
          Rails.logger.info "JWT Header (decoded): #{header}"
          Rails.logger.info "JWT Payload (decoded): #{payload}"
        end
        
        token
      rescue => e
        Rails.logger.error "JWT generation failed: #{e.message}"
        Rails.logger.error "Error class: #{e.class}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(3).join("\n")}"
        raise e
      end
    end
    
    # 直接HTTP/2でAPNSに送信（curlと同じ方式）
    def send_notification_direct(device_token, payload, bundle_id = nil)
      use_production = Rails.env.production?
      gateway = use_production ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'
      # 環境変数からBundle IDを取得
      topic = ENV.fetch('APNS_BUNDLE_ID', 'com.sawaki.HimaSoku')
      
      jwt_token = generate_jwt_token
      
      # URLとトークンをクリーンアップ
      clean_device_token = device_token.strip.gsub(/[\r\n]/, '')
      clean_topic = topic.strip.gsub(/[\r\n]/, '')
      clean_jwt_token = jwt_token.strip.gsub(/[\r\n]/, '')
      
      uri = URI("https://#{gateway}/3/device/#{clean_device_token}")
      
      Rails.logger.info "--- Direct APNS Request ---"
      Rails.logger.info "URL: #{uri}"
      Rails.logger.info "Topic: #{clean_topic}"
      Rails.logger.info "Payload: #{payload.to_json}"
      Rails.logger.info "JWT Token: #{clean_jwt_token[0..50]}..."
      Rails.logger.info "Device Token Clean: #{clean_device_token}"
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      
      request = Net::HTTP::Post.new(uri)
      request['authorization'] = "bearer #{clean_jwt_token}"
      request['apns-topic'] = clean_topic
      request['content-type'] = 'application/json'
      request.body = payload.to_json
      
      response = http.request(request)
      
      Rails.logger.info "--- Direct APNS Response ---"
      Rails.logger.info "Status: #{response.code}"
      Rails.logger.info "Headers: #{response.to_hash.inspect}"
      Rails.logger.info "Body: #{response.body}"
      
      {
        status: response.code.to_i,
        success: response.code.to_i == 200,
        body: response.body.empty? ? {} : JSON.parse(response.body),
        headers: response.to_hash
      }
    rescue => e
      Rails.logger.error "Direct APNS request failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(3).join(', ')}"
      {
        status: 500,
        success: false,
        error: e.message
      }
    end

    # 確実に動作するシンプルなAPNS送信（Apnoticを正しく使用）
    def send_notification_with_custom_jwt(device_token, payload, bundle_id = nil)
      # 環境を明示的に設定（デバイストークンの環境に合わせる）
      # まずはSandboxで試す
      use_production = true
      
      # 環境変数から値を取得
      team_id = ENV.fetch('APNS_TEAM_ID')
      key_id = ENV.fetch('APNS_KEY_ID')
      bundle_id = ENV.fetch('APNS_BUNDLE_ID', 'com.sawaki.HimaSoku')
      
        Rails.logger.info "--- APNS Request with Environment Variables ---"
      Rails.logger.info "Team ID: #{team_id}"
      Rails.logger.info "Key ID: #{key_id}"
      Rails.logger.info "Bundle ID: #{bundle_id}"
      Rails.logger.info "Device Token: #{device_token}"
      Rails.logger.info "Device Token Length: #{device_token.length}"
      Rails.logger.info "Environment: #{use_production ? 'Production' : 'Sandbox'} (FORCED TO SANDBOX)"
      
      begin
        # 毎回新しい接続を作成（JWTトークンを最新に保つ）
        connection = nil
        
        # 一時ファイルを作成してP8キー内容を書き込み
        require 'tempfile'
        temp_file = Tempfile.new(['apns_key', '.p8'])
        p8_content = ENV.fetch('APNS_P8_CONTENT')
        temp_file.write(p8_content)
        temp_file.close
        
        gateway = use_production ? 'api.push.apple.com' : 'api.sandbox.push.apple.com'
        Rails.logger.info "Using gateway: #{gateway}"
        
        # P8キーの内容を検証
        begin
          test_key = OpenSSL::PKey.read(p8_content)
          Rails.logger.info "P8 key validation: SUCCESS"
          Rails.logger.info "P8 key type: #{test_key.class}"
        rescue => key_error
          Rails.logger.error "P8 key validation: FAILED - #{key_error.message}"
        end
        
        # Apnoticの接続を作成（毎回新規作成）
        connection = Apnotic::Connection.new(
          auth_method: :token,
          cert_path: temp_file.path,
          key_id: key_id,
          team_id: team_id,
          url: "https://#{gateway}:443"
        )
        
        Rails.logger.info "Apnotic connection created with hardcoded values"
        Rails.logger.info "Connection URL: #{connection.url}" if connection.respond_to?(:url)
        
        # 通知を作成
        notification = Apnotic::Notification.new(device_token)
        notification.topic = bundle_id
        
        # ペイロードを設定
        if payload[:aps]
          notification.alert = payload[:aps][:alert] if payload[:aps][:alert]
          notification.badge = payload[:aps][:badge] if payload[:aps][:badge]
          notification.sound = payload[:aps][:sound] if payload[:aps][:sound]
          notification.category = payload[:aps][:category] if payload[:aps][:category]
          notification.mutable_content = true if payload[:aps][:"mutable-content"]
          notification.content_available = true if payload[:aps][:"content-available"]
          notification.priority = 6
          notification.push_type = 'alert'
        end
        
        # カスタムデータを追加
        payload.each do |key, value|
          next if key == :aps
          notification.custom_payload = notification.custom_payload || {}
          notification.custom_payload[key] = value
        end
        
        Rails.logger.info "Notification prepared:"
        Rails.logger.info "  - Topic: #{notification.topic}"
        Rails.logger.info "  - Alert: #{notification.alert.inspect}"
        Rails.logger.info "  - Custom payload: #{notification.custom_payload.inspect}"
        
        # 通知を送信
        response = connection.push(notification)
        
        Rails.logger.info "--- APNS Response ---"
        Rails.logger.info "Status: #{response.status}"
        Rails.logger.info "OK?: #{response.ok?}"
        Rails.logger.info "Headers: #{response.headers.inspect}"
        
        if response.body && !response.body.empty?
          Rails.logger.info "Body: #{response.body}"
          error_info = JSON.parse(response.body) rescue nil
          if error_info && error_info['reason']
            Rails.logger.error "APNS Error Reason: #{error_info['reason']}"
            
            # エラーの詳細情報
            case error_info['reason']
            when 'InvalidProviderToken'
              Rails.logger.error "InvalidProviderToken - Check Team ID (#{team_id}) and Key ID (#{key_id})"
            when 'BadDeviceToken'
              Rails.logger.error "BadDeviceToken - Device token is invalid or for wrong environment"
            when 'TopicDisallowed'
              Rails.logger.error "TopicDisallowed - Bundle ID (#{bundle_id}) is not allowed"
            end
          end
        end
        
        # 一時ファイルを削除
        temp_file.unlink if temp_file
        
        # 接続を閉じる
        connection.close if connection
        
        {
          status: response.status,
          success: response.ok?,
          body: response.body.empty? ? {} : (JSON.parse(response.body) rescue response.body),
          headers: response.headers
        }
        
      rescue => e
        Rails.logger.error "APNS request failed: #{e.message}"
        Rails.logger.error "Error class: #{e.class}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
        
        # リソースのクリーンアップ
        temp_file.unlink if temp_file && File.exist?(temp_file.path)
        connection.close if connection
        
        {
          status: 500,
          success: false,
          error: e.message
        }
      end
    end

    private

    def create_connection
      # APNS環境の決定
      # APNS_ENVIRONMENT=production でProduction APNS使用
      # それ以外はSandbox APNS使用
      use_production = Rails.env.production?
      
      if use_production
        gateway = 'api.push.apple.com'
        Rails.logger.info "🚀 Using Production APNS: #{gateway}"
      else
        gateway = 'api.sandbox.push.apple.com'
        Rails.logger.info "🛠️ Using Sandbox APNS: #{gateway}"
      end

      # P8キーファイル認証（推奨方式）
      # 環境変数から値を取得
      team_id = ENV['APNS_TEAM_ID']
      key_id = ENV['APNS_KEY_ID']
      auth_key_content = ENV['APNS_P8_CONTENT']
      
      if auth_key_content && key_id && team_id
        Rails.logger.info "📱 Initializing APNS with P8 Token Authentication"
        Rails.logger.info "   Key ID: #{key_id}"
        Rails.logger.info "   Team ID: #{team_id}"
        Rails.logger.info "   Bundle ID: com.sawaki.HimaSoku"
        Rails.logger.info "   Using environment variables for APNS config"
        Rails.logger.info "   Environment: #{use_production ? 'PRODUCTION' : 'SANDBOX'}"
        Rails.logger.info "   Gateway URL: https://#{gateway}:443"
        
        # 一時ファイルを作成してP8キー内容を書き込み
        require 'tempfile'
        temp_file = Tempfile.new(['apns_key', '.p8'])
        temp_file.write(auth_key_content.strip)
        temp_file.close
        
        Rails.logger.info "   Temp P8 file: #{temp_file.path}"
                 Rails.logger.info "   P8 content length: #{auth_key_content.strip.length} characters"
         Rails.logger.info "   P8 content preview: #{auth_key_content.strip[0..50]}..."
         Rails.logger.info "   File exists: #{File.exist?(temp_file.path)}"
         Rails.logger.info "   File size: #{File.size(temp_file.path)} bytes"
         
         # P8キーの詳細検証
         begin
           require 'openssl'
           key_content = auth_key_content.strip
           pkey = OpenSSL::PKey.read(key_content)
           Rails.logger.info "   ✅ P8 key is valid OpenSSL private key"
           Rails.logger.info "   Key type: #{pkey.class}"
           Rails.logger.info "   Key algorithm: #{pkey.respond_to?(:group) ? 'EC' : 'Unknown'}"
         rescue OpenSSL::PKey::PKeyError => e
           Rails.logger.error "   ❌ P8 key validation failed: #{e.message}"
         rescue => e
           Rails.logger.error "   ❌ Error validating P8 key: #{e.message}"
         end
        
        begin
          connection = Apnotic::Connection.new(
            auth_method: :token,
            cert_path: temp_file.path,
            key_id: key_id,
            team_id: team_id,
            url: "https://#{gateway}:443"
          )
          
          Rails.logger.info "✅ APNS Connection established successfully"
          Rails.logger.info "   Connection class: #{connection.class}"
          Rails.logger.info "   Connection object ID: #{connection.object_id}"
          
          # JWTトークンをデバッグ出力
          if connection.respond_to?(:jwt_token)
            token = connection.jwt_token
            Rails.logger.info "   JWT Token: #{token[0..50]}..." if token
          end
          
          # Apnoticの内部設定を確認
          Rails.logger.info "   Connection URL: #{connection.instance_variable_get(:@url)}"
          Rails.logger.info "   Auth Method: #{connection.instance_variable_get(:@auth_method)}"
          Rails.logger.info "   Key ID: #{connection.instance_variable_get(:@key_id)}"
          Rails.logger.info "   Team ID: #{connection.instance_variable_get(:@team_id)}"
          
          connection
        rescue => connection_error
          Rails.logger.error "❌ Failed to create Apnotic::Connection"
          Rails.logger.error "   Error: #{connection_error.message}"
          Rails.logger.error "   Error class: #{connection_error.class}"
          raise connection_error
        end
        
      elsif ENV['APNS_CERT_PATH']
        # P12証明書認証（古い方式）
        Rails.logger.info "📱 Initializing APNS with P12 Certificate"
        
        Apnotic::Connection.new(
          cert_path: ENV['APNS_CERT_PATH'],
          cert_pass: ENV['APNS_CERT_PASS'] || '',
          url: "https://#{gateway}:443"
        )
      else
        Rails.logger.error "❌ APNS credentials not configured!"
        Rails.logger.error "Required environment variables:"
        Rails.logger.error "  - APNS_AUTH_KEY_CONTENT (P8 key content)"
        Rails.logger.error "  - APNS_KEY_ID (P8 key ID)"
        Rails.logger.error "  - APNS_TEAM_ID (Apple Developer Team ID)"
        Rails.logger.error "  - APNS_ENVIRONMENT (production or sandbox)"
        Rails.logger.error "  - APNS_BUNDLE_ID (optional, defaults to com.sawaki.HimaSoku)"
        nil
      end
      
    rescue => e
      Rails.logger.error "💥 Failed to create APNS connection: #{e.message}"
      Rails.logger.error "   Error class: #{e.class}"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join(', ')}"
      nil
    end
  end
end
