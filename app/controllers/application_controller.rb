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
      @current_user = User.find_by(firebase_uid: firebase_uid)
      unless @current_user
          # firebase_uidをuidとして使用してユーザーを作成
          @current_user = User.create!(
            uid: firebase_uid,
            firebase_uid: firebase_uid, 
            email: firebase_email
          )
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