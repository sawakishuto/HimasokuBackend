class ApplicationController < ActionController::API
  before_action :authenticate_firebase_user, except: [:test_apns]

  attr_reader :current_user

  # APNS の JWT(プロバイダトークン) 生成が成功するかを確認する簡易ヘルスチェック。
  # 秘匿情報（Team ID / Key ID / トークン本体）は返さない。
  def test_apns
    APNS.generate_jwt_token
    render json: { success: true, message: 'APNS JWT generation successful' }
  rescue => e
    Rails.logger.error "APNS JWT generation failed: #{e.class}: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  # Firebase の ID トークンを検証し、対応するユーザーを @current_user に設定する。
  # 未認証・検証失敗時は 401 を返す。
  def authenticate_firebase_user
    token = bearer_token
    return unauthorized if token.blank?

    payload = FirebaseIdToken::TokenVerifier.new.verify_id_token(token)
    @current_user = find_or_provision_user(payload)
  rescue => e
    Rails.logger.warn "Firebase auth error: #{e.message}"
    unauthorized
  end

  def bearer_token
    request.headers['Authorization'].to_s.split(' ').last
  end

  # 検証済みペイロードからユーザーを取得。未登録なら作成し、
  # 既存ユーザーで name が未設定なら Firebase の名前で補完する。
  def find_or_provision_user(payload)
    firebase_uid = payload['sub']
    email        = payload['email']
    name         = payload['name'] || payload['display_name'] || email&.split('@')&.first

    user = User.find_by(firebase_uid: firebase_uid)
    if user.nil?
      User.create!(firebase_uid: firebase_uid, email: email, name: name)
    else
      user.update!(name: name) if user.name.blank? && name.present?
      user
    end
  end

  def unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
