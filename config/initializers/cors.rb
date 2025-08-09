# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # 本番環境: 許可するドメインを明示的に指定
    if Rails.env.production?
      origins ENV.fetch('ALLOWED_ORIGINS', '').split(',').map(&:strip)
    else
      # 開発環境: 全てのオリジンを許可
      origins '*'
    end

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
