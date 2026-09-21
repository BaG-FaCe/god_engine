# CORS for the Vite/React SPA.
#
# In development the SPA runs on :5173 and proxies /api to Rails, so CORS is not
# strictly required. It is enabled anyway so the SPA can also be pointed directly
# at the API via VITE_API_BASE_URL (and for the Playwright suite).
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      *ENV.fetch(
        'CORS_ORIGINS',
        'http://localhost:5173,http://127.0.0.1:5173,http://localhost:4173'
      ).split(',').map(&:strip)
    )

    resource '/api/*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Content-Disposition X-Request-Id X-Total-Count],
             credentials: false,
             max_age: 600
  end
end
