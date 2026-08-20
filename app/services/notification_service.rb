class NotificationService
  class << self
    # グループ内の全ユーザーに「暇共有」通知を送信
    def notify_group(group_id, name, data = {})
      users = Group.find(group_id).users
      deliver(device_tokens_for(users), invite_content(name, data), data)
    end

    # グループ内の全ユーザーに「暇共有」通知を送信（送信者を除く）
    def notify_group_except_sender(group_id, name, sender_firebase_uid, data = {})
      users = Group.find(group_id).users.where.not(firebase_uid: sender_firebase_uid)
      deliver(device_tokens_for(users), invite_content(name, data), data)
    end

    # 特定のユーザーに通知を送信
    def notify_user(firebase_uid, title, body, data = {})
      tokens = User.find(firebase_uid).user_devices.pluck(:device_id)
      deliver(tokens, interactive_content(title, body), data)
    end

    # 複数のデバイストークンにインタラクティブ通知を送信
    def send_notifications(device_tokens, title, body, data = {})
      deliver(device_tokens, interactive_content(title, body), data)
    end

    # 複数のデバイストークンにシンプル通知（インタラクティブではない）を送信
    def send_simple_notification(device_tokens, title, body, data = {})
      deliver(device_tokens, simple_content(title, body), data)
    end

    private

    # 通知本体を各デバイストークンへ送信し、結果サマリを返す。
    # content: APNS.push へ渡すキーワード引数のハッシュ（alert/badge/category など）
    def deliver(device_tokens, content, data = {})
      device_tokens = Array(device_tokens).compact.uniq
      return { success: false, error: 'No device tokens provided' } if device_tokens.empty?

      results = device_tokens.map { |token| deliver_one(token, content, data) }

      {
        success:      true,
        total_tokens: device_tokens.size,
        results:      results,
        successful:   results.count { |r| r[:status] == 'success' },
        failed:       results.count { |r| r[:status] != 'success' }
      }
    end

    def deliver_one(token, content, data)
      notification_id = SecureRandom.uuid
      custom = data.to_h.symbolize_keys.merge(notification_id: notification_id)

      response = APNS.push(token, custom: custom, **content)

      if response[:success]
        Rails.logger.info "✅ Notification sent to #{token} (notification_id=#{notification_id})"
        { token: token, status: 'success', notification_id: notification_id, apns_id: response[:apns_id] }
      else
        Rails.logger.error "❌ Failed to send to #{token}: #{response[:body] || response[:error]}"
        { token: token, status: 'failed', error: response[:body] || response[:error] }
      end
    rescue => e
      Rails.logger.error "💥 Error sending to #{token}: #{e.message}"
      { token: token, status: 'error', error: e.message }
    end

    def device_tokens_for(users)
      users.flat_map { |user| user.user_devices.pluck(:device_id) }
    end

    # ---- 通知テンプレート ---------------------------------------------------

    # 「暇共有」通知（グループ向け・インタラクティブ）
    def invite_content(name, data)
      interactive_content(
        'HimaSoku情報',
        "#{name}が暇を共有しています。\n #{data[:durationTime]}"
      )
    end

    # インタラクティブ通知（Join/Decline アクション付き）
    def interactive_content(title, body)
      {
        alert:             { title: title, body: body },
        badge:             1,
        sound:             'default',
        category:          'HIMASOKU_INVITE',
        mutable_content:   true,
        content_available: true
      }
    end

    # シンプル通知（カテゴリなし）
    def simple_content(title, body)
      {
        alert:             { title: title, body: body },
        badge:             1,
        sound:             'default',
        content_available: true
      }
    end
  end
end
