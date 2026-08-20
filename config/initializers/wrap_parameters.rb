# Be sure to restart your server when you modify this file.

# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.

# iOS クライアントはフラットな JSON（例: {"firebase_uid": "...", "name": "..."}）を
# 送信するため、ParamsWrapper を有効にして各コントローラのモデルキー
# （:user / :device / :users_group など）配下へ自動ラップする。
# これにより params.require(:user) 形式のストロングパラメータがそのまま機能する。
# トップレベルのキーは保持されるため、params[:x] を直接読むコントローラ
# （groups / notifications）には影響しない。
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: [:json]
end
