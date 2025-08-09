class NotificationsController < ApplicationController
    # グループ内の全ユーザーに通知を送信
  def notification_for_group
    sender_firebase_uid = params[:firebase_uid]
    group_id = params[:group_id]
    name = params[:name] || '名無しさん'
    data = {
      durationTime: params[:durationTime],
      sender_firebase_uid: sender_firebase_uid,
      group_id: group_id,
      sender_name: name
    }

    begin
      result = NotificationService.notify_group_except_sender(group_id, name, sender_firebase_uid, data)

      if result[:success]
        render json: {
          message: 'Notifications sent successfully',
          total_tokens: result[:total_tokens],
          successful: result[:successful],
          failed: result[:failed],
          details: result[:results]
        }, status: :ok
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Group not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Notification error: #{e.message}"
      render json: { error: 'Failed to send notifications' }, status: :internal_server_error
    end
  end

  # 特定のユーザーに通知を送信
  def notification_for_user
    firebase_uid = params[:firebase_uid]
    title = params[:title] || 'ユーザー通知'
    body = params[:body] || '新しい通知があります'
    data = params[:data] || {}

    begin
      result = NotificationService.notify_user(firebase_uid, title, body, data)

      if result[:success]
        render json: {
          message: 'Notification sent successfully',
          total_tokens: result[:total_tokens],
          successful: result[:successful],
          failed: result[:failed],
          details: result[:results]
        }, status: :ok
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Notification error: #{e.message}"
      render json: { error: 'Failed to send notification' }, status: :internal_server_error
    end
  end

  # カスタム通知（複数のデバイストークンに直接送信）
  def send_custom_notification
    device_tokens = params[:device_tokens] || []
    title = params[:title] || 'カスタム通知'
    body = params[:body] || 'カスタム通知です'
    data = params[:data] || {}

    result = NotificationService.send_notifications(device_tokens, title, body, data)

    if result[:success]
      render json: {
        message: 'Notifications sent',
        total_tokens: result[:total_tokens],
        successful: result[:successful],
        failed: result[:failed],
        details: result[:results]
      }, status: :ok
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  # インタラクティブ通知のアクションレスポンスを処理
  def handle_notification_response
    firebase_uid = params[:firebase_uid]
    action_identifier = params[:action_identifier]
    group_id = params[:group_id]
    sender_name = params[:sender_name]
    sender_firebase_uid = params[:sender_firebase_uid]
    duration_time = params[:duration_time]

    begin
      user = User.find(firebase_uid)
      # 参加の場合のみ処理
      case action_identifier
      when 'JOIN_ACTION'
        # 「参加する」アクションの処理
        handle_join_action(user, sender_name, sender_firebase_uid)
        render json: { 
          message: '参加しました！', 
          action: 'joined',
          user: user.name || user.firebase_uid,
          group_id: group_id
        }, status: :ok

      else
        render json: { error: 'Unknown action identifier' }, status: :bad_request
      end

    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Notification response error: #{e.message}"
      render json: { error: 'Failed to process notification response' }, status: :internal_server_error
    end
  end

  private

    def handle_join_action(user, sender_name, sender_firebase_uid)
    # 参加処理のロジック
    Rails.logger.info "User #{user.firebase_uid} joined the activity from #{sender_name}"
 
    # 送信元（暇を共有した人）に参加通知を送信
    participant_name = user.name || user.firebase_uid
    participant_id = user.id
    message = "#{participant_name}が共感しています！"
    data = {
      user_id: participant_id,
      user_name: participant_name
    }

    # シンプルな通知でメッセージを送信
    begin
      sender_user = User.find(sender_firebase_uid)
      device_tokens = sender_user.user_devices.pluck(:device_id)

      if device_tokens.any?
        NotificationService.send_simple_notification(device_tokens, "HimaSoku速報", message, data)
      else
        Rails.logger.warn "No device tokens found for sender #{sender_firebase_uid}"
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Sender user not found: #{sender_firebase_uid}"
    rescue => e
      Rails.logger.error "Error notifying sender: #{e.message}"
    end
    
    # ここで実際のアプリのビジネスロジックを実装
    # 例：活動に参加者を追加、データベースを更新など
  end

  def handle_decline_action(user, sender_name, sender_firebase_uid)
    # 辞退処理のロジック
    Rails.logger.info "User #{user.firebase_uid} declined the activity from #{sender_name}"
    
    # 送信元（暇を共有した人）に辞退通知を送信
    notify_original_sender(sender_firebase_uid, user, '辞退', sender_name)
    
    # ここで実際のアプリのビジネスロジックを実装
  end

  def notify_original_sender(sender_firebase_uid, responding_user, action, original_sender)
    begin
      # 送信元（暇を共有した人）を取得
      sender_user = User.find(sender_firebase_uid)
      device_tokens = sender_user.user_devices.pluck(:device_id)
      
      if device_tokens.any?
        response_message = "#{responding_user.name || responding_user.firebase_uid}さんがあなたの誘いに#{action}しました"

        # シンプルな通知を送信（インタラクティブではない）
        NotificationService.send_simple_notification(device_tokens, "HimaSoku情報", response_message)
        Rails.logger.info "Notified sender #{sender_firebase_uid} about #{action} from #{responding_user.firebase_uid}"
      else
        Rails.logger.warn "No device tokens found for sender #{sender_firebase_uid}"
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Sender user not found: #{sender_firebase_uid}"
    rescue => e
      Rails.logger.error "Error notifying original sender: #{e.message}"
    end
  end
end
