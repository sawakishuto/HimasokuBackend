class ApplicationController < ActionController::API
  before_action :authenticate_firebase_user

  attr_reader :current_user

  private

  def authenticate_firebase_user
    header = request.headers["Authorization"]
    return unauthorized unless header.present?
    token = header.split(" ").last
    begin
      puts "start verify"
      firebase_id_token = FirebaseIdToken::TokenVerifier.new
      payload = firebase_id_token.verify_id_token(token)
      # puts payload
      firebase_uid = payload["sub"]
      firebase_email = payload["email"]
      firebase_name = payload["name"] || payload["display_name"] || firebase_email&.split('@')&.first
      @current_user = User.find_by(firebase_uid: firebase_uid)
      unless @current_user
          # firebase_uidを使用してユーザーを作成
          @current_user = User.create!(
            firebase_uid: firebase_uid, 
            email: firebase_email,
            name: firebase_name
          )
      else
          # 既存ユーザーのnameが空の場合は更新
          if @current_user.name.blank? && firebase_name.present?
            @current_user.update!(name: firebase_name)
          end
      end
    end
    rescue => e
      # 検証エラー時は 401 を返す
      Rails.logger.warn "Firebase auth error: #{e.message}"
      unauthorized
    end

  def unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end