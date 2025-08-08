class NotificationService
  class << self
    # グループ内の全ユーザーに通知を送信
    def notify_group(group_id, name, data = {})
      group = Group.find(group_id)
      users = group.users

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
      
      connection = APNS.connection
      return { success: false, error: 'APNS connection not available' } unless connection

      results = []
      
      device_tokens.each do |token|
        begin
          notification = create_notification(token, name, data)
          response = connection.push(notification)
          
          if response.ok?
            results << { token: token, status: 'success' }
            Rails.logger.info "Notification sent successfully to #{token}"
          else
            results << { token: token, status: 'failed', error: response.body }
            Rails.logger.error "Failed to send notification to #{token}: #{response.body}"
          end
        rescue => e
          results << { token: token, status: 'error', error: e.message }
          Rails.logger.error "Error sending notification to #{token}: #{e.message}"
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
      
      connection = APNS.connection
      return { success: false, error: 'APNS connection not available' } unless connection

      results = []
      
      device_tokens.each do |token|
        begin
          notification = create_simple_notification(token, title, body, data)
          response = connection.push(notification)
          
          if response.ok?
            results << { token: token, status: 'success' }
            Rails.logger.info "Simple notification sent successfully to #{token}"
          else
            results << { token: token, status: 'failed', error: response.body }
            Rails.logger.error "Failed to send simple notification to #{token}: #{response.body}"
          end
        rescue => e
          results << { token: token, status: 'error', error: e.message }
          Rails.logger.error "Error sending simple notification to #{token}: #{e.message}"
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
      
      # バンドルIDを環境変数から取得（必須）
      notification.topic = ENV['APNS_BUNDLE_ID'] || 'com.sawaki.HimaSoku'
      
      # 基本的な通知設定
      notification.alert = {
        title: "HimaSoku情報",
        body: "#{name}が暇を共有しています。\n #{data[:durationTime]}"
      }
      notification.badge = 1
      notification.sound = 'default'
      notification.category = 'HIMASOKU_INVITE'
      notification.mutable_content = true
      
      # カスタムデータを追加（Apnoticの正しい方法）
      data.each do |key, value|
        notification.custom_payload = notification.custom_payload || {}
        notification.custom_payload[key] = value
      end
      
      notification
    end

    def create_simple_notification(device_token, title, body, data = {})
      notification = Apnotic::Notification.new(device_token)
      
      # バンドルIDを環境変数から取得（必須）
      notification.topic = ENV['APNS_BUNDLE_ID'] || 'com.sawaki.HimaSoku'
      
      # 基本的な通知設定
      notification.alert = {
        title: title,
        body: body
      }
      notification.badge = 1
      notification.sound = 'default'
      
      # カスタムデータを追加（Apnoticの正しい方法）
      data.each do |key, value|
        notification.custom_payload = notification.custom_payload || {}
        notification.custom_payload[key] = value
      end
      
      notification
    end
  end
end
