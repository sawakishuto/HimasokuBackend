class NotificationService
  class << self
    # グループ内の全ユーザーに通知を送信
    def notify_group(group_id, name, data = {})
      group = Group.find(group_id)
      users = group.users

      device_tokens = users.flat_map { |user| user.user_devices.pluck(:device_id) }

      send_notifications(device_tokens, name, data)
    end

    # グループ内の全ユーザーに通知を送信（送信者を除く）
    def notify_group_except_sender(group_id, name, sender_firebase_uid, data = {})
      group = Group.find(group_id)
      # 送信者以外のユーザーのみに送信
      users = group.users.where.not(firebase_uid: sender_firebase_uid)

      device_tokens = users.flat_map { |user| user.user_devices.pluck(:device_id) }

      send_notifications(device_tokens, name, data)
    end

    # 特定のユーザーに通知を送信
    def notify_user(firebase_uid, name, data = {})
      user = User.find(firebase_uid)
      device_tokens = user.user_devices.pluck(:device_id)
      
      send_notifications(device_tokens, name, data)
    end

    # 複数のデバイストークンに通知を送信
    def send_notifications(device_tokens, name, data = {})
      return { success: false, error: 'No device tokens provided' } if device_tokens.empty?

      results = []

      device_tokens.each do |token|
        begin
          # 通知IDを生成
          notification_id = SecureRandom.uuid

          # curlと同じ形式のペイロードを作成
          payload = {
            aps: {
              alert: {
                title: "HimaSoku情報",
                body: "#{name}が暇を共有しています。\n #{data[:durationTime]}"
              },
              badge: 1,
              sound: "default",
              category: "HIMASOKU_INVITE",
              "mutable-content": 1,
              "content-available": 1
            },
            notification_id: notification_id  # 通知IDを追加
          }

          # カスタムデータを追加
          data.each do |key, value|
            payload[key] = value
          end

          Rails.logger.info "Sending notification using custom JWT method..."
          Rails.logger.info "Attempting to send to device token: #{token}"
          Rails.logger.info "Token length: #{token.length} characters"
          Rails.logger.info "Notification ID: #{notification_id}"
          response = APNS.send_notification_with_custom_jwt(token, payload)

          if response[:success]
            results << { 
              token: token, 
              status: 'success',
              notification_id: notification_id,
              apns_id: response.dig(:headers, 'apns-id')
            }
            Rails.logger.info "✅ Notification sent successfully to #{token}"
          else
            results << { token: token, status: 'failed', error: response[:body] }
            Rails.logger.error "❌ Failed to send notification to #{token}: #{response[:body]}"
          end
        rescue => e
          results << { token: token, status: 'error', error: e.message }
          Rails.logger.error "💥 Error sending notification to #{token}: #{e.message}"
        end
      end

      {
        success: true,
        total_tokens: device_tokens.count,
        results: results,
        successful: results.count { |r| r[:status] == 'success' },
        failed: results.count { |r| r[:status] != 'success' }
      }
    end

    # シンプルな通知（インタラクティブではない）を送信
    def send_simple_notification(device_tokens, title, body, data = {})
      return { success: false, error: 'No device tokens provided' } if device_tokens.empty?

      # デバッグ情報をログ出力
      Rails.logger.info "=== Simple Notification Debug Info ==="
      Rails.logger.info "Target Device Tokens: #{device_tokens.inspect}"
      Rails.logger.info "Title: #{title}"
      Rails.logger.info "Body: #{body}"
      Rails.logger.info "Custom Data: #{data.inspect}"

      results = []

      device_tokens.each_with_index do |token, index|
        begin
          # 通知IDを生成
          notification_id = SecureRandom.uuid

          Rails.logger.info "--- Processing token #{index + 1}/#{device_tokens.count} ---"
          Rails.logger.info "Device Token: #{token}"
          Rails.logger.info "Token Length: #{token.length} characters"
          Rails.logger.info "Token Environment Guess: #{guess_token_environment(token)}"
          Rails.logger.info "Notification ID: #{notification_id}"

          # curlと同じ形式のペイロードを作成
          payload = {
            aps: {
              alert: {
                title: title,
                body: body
              },
              badge: 1,
              sound: "default",
              "content-available": 1
            },
            notification_id: notification_id  # 通知IDを追加
          }
          
          # カスタムデータを追加
          data.each do |key, value|
            payload[key] = value
          end
          
          Rails.logger.info "Notification Payload: #{payload.inspect}"
          Rails.logger.info "Sending simple notification using custom JWT method..."
          
          response = APNS.send_notification_with_custom_jwt(token, payload)
          
          if response[:success]
            results << { 
              token: token, 
              status: 'success',
              notification_id: notification_id,
              apns_id: response.dig(:headers, 'apns-id')
            }
            Rails.logger.info "✅ Simple notification sent successfully to #{token}"
          else
            results << { token: token, status: 'failed', error: response[:body] }
            Rails.logger.error "❌ Failed to send simple notification to #{token}"
            Rails.logger.error "Response Body: #{response[:body]}"
            Rails.logger.error "Response Status: #{response[:status]}"
          end
        rescue => e
          results << { token: token, status: 'error', error: e.message }
          Rails.logger.error "💥 Error sending simple notification to #{token}: #{e.message}"
          Rails.logger.error "Error Backtrace: #{e.backtrace.first(5).join("\n")}"
        end
      end

      {
        success: true,
        total_tokens: device_tokens.count,
        results: results,
        successful: results.count { |r| r[:status] == 'success' },
        failed: results.count { |r| r[:status] != 'success' }
      }
    end

    private

    def create_notification(device_token, name, data = {})
      notification = Apnotic::Notification.new(device_token)
      
      # ハードコードされたバンドルIDを使用
      notification.topic = 'com.sawaki.HimaSoku'
      
      # 基本的な通知設定
      notification.alert = {
        title: "HimaSoku情報",
        body: "#{name}が暇を共有しています。\n #{data[:durationTime]}"
      }
      notification.badge = 1
      notification.sound = 'default'
      notification.category = 'HIMASOKU_INVITE'
      notification.mutable_content = true
      notification.content_available = true
      notification.priority = 6
      
      # カスタムデータを追加（Apnoticの正しい方法）
      data.each do |key, value|
        notification.custom_payload = notification.custom_payload || {}
        notification.custom_payload[key] = value
      end
      
      notification
    end

    def create_simple_notification(device_token, title, body, data = {})
      Rails.logger.info "--- Creating Simple Notification ---"
      Rails.logger.info "Device Token: #{device_token}"
      Rails.logger.info "Topic (Bundle ID): com.sawaki.HimaSoku"
      
      notification = Apnotic::Notification.new(device_token)
      
      # ハードコードされたバンドルIDを使用
      topic = 'com.sawaki.HimaSoku'
      notification.topic = topic
      Rails.logger.info "Notification Topic set to: #{topic}"
      
      # 基本的な通知設定
      alert_payload = {
        title: title,
        body: body
      }
      notification.alert = alert_payload
      notification.badge = 1
      notification.sound = 'default'
      notification.content_available = true
      notification.priority = 6
      
      Rails.logger.info "Alert Payload: #{alert_payload.inspect}"
      Rails.logger.info "Badge: 1, Sound: 'default'"
      
      # カスタムデータを追加（Apnoticの正しい方法）
      if data.any?
        Rails.logger.info "Adding custom data: #{data.inspect}"
        data.each do |key, value|
          notification.custom_payload = notification.custom_payload || {}
          notification.custom_payload[key] = value
        end
        Rails.logger.info "Final custom payload: #{notification.custom_payload.inspect}"
      end
      
      Rails.logger.info "Notification creation completed"
      notification
    end

    # デバイストークンから環境を推測（参考用）
    def guess_token_environment(token)
      # 一般的な特徴（完全ではない）
      if token.length == 64
        # Productionトークンは通常64文字
        # Sandboxトークンも64文字だが、統計的にProductionが多い
        "Production (likely)"
      elsif token.length < 64
        "Development/Sandbox (likely)"
      else
        "Unknown format"
      end
    end
  end
end