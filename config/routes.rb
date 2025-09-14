Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Swagger API Documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :users, only: [:index, :show, :create]
  resources :devices, only: [:show, :create]
  resources :groups, only: [:index, :show, :create]
  
  # グループとユーザーの関係
  resources :users_groups, only: [:index, :show, :create]
  
  # 特定のグループに所属するユーザー一覧を取得
  get 'groups/:group_id/users', to: 'users_groups#group_users', as: 'group_users'
  
  # 特定のユーザーが所属するグループ一覧を取得
  get 'users/:user_id/groups', to: 'users_groups#user_groups', as: 'user_groups'
  
  # APNS通知
  post 'notifications/group/:group_id', to: 'notifications#notification_for_group', as: 'notification_for_group'
  post 'notifications/user/:firebase_uid', to: 'notifications#notification_for_user', as: 'notification_for_user'
  post 'notifications/custom', to: 'notifications#send_custom_notification', as: 'send_custom_notification'
  
  # インタラクティブ通知のレスポンス処理
  post 'notifications/response', to: 'notifications#handle_notification_response', as: 'handle_notification_response'
  
  # APNS test endpoint
  get 'test/apns', to: 'application#test_apns', as: 'test_apns'

  # Defines the root path route ("/")
  # root "posts#index"
end
