class NotificationsController < ApplicationController
  # グループ内の全ユーザー（送信者を除く）に通知を送信
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

    result = NotificationService.notify_group_except_sender(group_id, name, sender_firebase_uid, data)
    render_notification_result(result, 'Notifications sent successfully')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Group not found' }, status: :not_found
  rescue => e
    Rails.logger.error "Notification error: #{e.message}"
    render json: { error: 'Failed to send notifications' }, status: :internal_server_error
  end

  # 特定のユーザーに通知を送信
  def notification_for_user
    firebase_uid = params[:firebase_uid]
    title = params[:title] || 'ユーザー通知'
    body = params[:body] || '新しい通知があります'
    data = params[:data] || {}

    result = NotificationService.notify_user(firebase_uid, title, body, data)
    render_notification_result(result, 'Notification sent successfully')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  rescue => e
    Rails.logger.error "Notification error: #{e.message}"
    render json: { error: 'Failed to send notification' }, status: :internal_server_error
  end

  # カスタム通知（複数のデバイストークンに直接送信）
  def send_custom_notification
    device_tokens = params[:device_tokens] || []
    title = params[:title] || 'カスタム通知'
    body = params[:body] || 'カスタム通知です'
    data = params[:data] || {}

    result = NotificationService.send_notifications(device_tokens, title, body, data)
    render_notification_result(result, 'Notifications sent')
  end

  # インタラクティブ通知のアクションレスポンス（参加 / 辞退）を処理
  def handle_notification_response
    user = User.find(params[:firebase_uid])
    sender_name = params[:sender_name]
    sender_firebase_uid = params[:sender_firebase_uid]

    case params[:action_identifier]
    when 'JOIN_ACTION'
      handle_join_action(user, sender_name, sender_firebase_uid)
      render json: response_payload('参加しました！', 'joined', user), status: :ok
    when 'DECLINE_ACTION'
      handle_decline_action(user, sender_name, sender_firebase_uid)
      render json: response_payload('辞退しました', 'declined', user), status: :ok
    else
      render json: { error: 'Unknown action identifier' }, status: :bad_request
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  rescue => e
    Rails.logger.error "Notification response error: #{e.message}"
    render json: { error: 'Failed to process notification response' }, status: :internal_server_error
  end

  private

  def render_notification_result(result, success_message)
    if result[:success]
      render json: {
        message: success_message,
        total_tokens: result[:total_tokens],
        successful: result[:successful],
        failed: result[:failed],
        details: result[:results]
      }, status: :ok
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def response_payload(message, action, user)
    { message: message, action: action, user: display_name(user), group_id: params[:group_id] }
  end

  def handle_join_action(user, sender_name, sender_firebase_uid)
    Rails.logger.info "User #{user.firebase_uid} joined the activity from #{sender_name}"
    notify_sender(sender_firebase_uid, user, action: 'JOIN',
                  message: "#{display_name(user)}が共感しています！")
  end

  def handle_decline_action(user, sender_name, sender_firebase_uid)
    Rails.logger.info "User #{user.firebase_uid} declined the activity from #{sender_name}"
    notify_sender(sender_firebase_uid, user, action: 'DECLINE',
                  message: "#{display_name(user)}は今は忙しいみたいです😢")
  end

  # 反応した相手（暇を共有した送信者）へ結果を通知する
  def notify_sender(sender_firebase_uid, responder, action:, message:)
    sender = User.find(sender_firebase_uid)
    device_tokens = sender.user_devices.pluck(:device_id)

    if device_tokens.empty?
      Rails.logger.warn "No device tokens found for sender #{sender_firebase_uid}"
      return
    end

    data = { user_id: responder.id, user_name: display_name(responder), action: action }
    NotificationService.send_simple_notification(device_tokens, 'HimaSoku速報', message, data)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Sender user not found: #{sender_firebase_uid}"
  rescue => e
    Rails.logger.error "Error notifying sender: #{e.message}"
  end

  def display_name(user)
    user.name.presence || user.firebase_uid
  end
end
