# Smoke test for the running API.
#
#   cd api && bundle exec rails smoke:api
#
# Hits a *running* server over HTTP (default http://127.0.0.1:3000, override with
# SMOKE_BASE_URL) and prints one PASS/FAIL line per endpoint. Exits non-zero when
# any check fails, so it can gate a deployment.
namespace :smoke do
  desc 'End-to-end smoke test against a running API server'
  task api: :environment do
    require 'net/http'
    require 'json'
    require 'uri'

    base = ENV.fetch('SMOKE_BASE_URL', 'http://127.0.0.1:3000')
    email = ENV.fetch('SMOKE_EMAIL', 'admin@god-engine.local')
    password = ENV.fetch('SMOKE_PASSWORD', 'GodEngine-Admin-123')

    failures = []
    token = nil

    request = lambda do |method, path, body = nil|
      uri = URI.join("#{base}/", path.sub(%r{\A/}, ''))
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }[method]
      req = klass.new(uri)
      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req['Authorization'] = "Bearer #{token}" if token
      req.body = body.to_json if body
      response = http.request(req)
      payload = response.body.to_s.empty? ? {} : (JSON.parse(response.body) rescue { '_raw' => response.body })
      [response.code.to_i, payload]
    end

    check = lambda do |name, expected, &block|
      status, payload = block.call
      ok = Array(expected).include?(status)
      failures << name unless ok
      puts format('%-4s %-46s HTTP %s', ok ? 'PASS' : 'FAIL', name, status)
      payload
    end

    check.call('health', 200) { request.call(:get, '/api/v1/health') }

    login = check.call('auth/login', 200) do
      request.call(:post, '/api/v1/auth/login', email: email, password: password)
    end
    token = login['token']
    abort 'Login fehlgeschlagen - Smoke-Test abgebrochen' if token.blank?

    check.call('auth/me', 200) { request.call(:get, '/api/v1/auth/me') }

    projects = check.call('projects#index', 200) { request.call(:get, '/api/v1/projects') }
    projects ||= {}
    project_id = projects.dig('data', 0, 'id')
    abort 'Kein Projekt vorhanden - `bin/rails db:seed` ausführen' if project_id.blank?

    materials = check.call('materials#index', 200) do
      request.call(:get, "/api/v1/projects/#{project_id}/materials")
    end
    material_id = materials.dig('data', 0, 'id')

    check.call('materials#lead_time_analysis', 200) do
      request.call(:get, "/api/v1/projects/#{project_id}/materials/lead_time_analysis")
    end
    check.call('suppliers#index', 200) { request.call(:get, "/api/v1/projects/#{project_id}/suppliers") }
    check.call('monthly_costs#index', 200) { request.call(:get, "/api/v1/projects/#{project_id}/monthly_costs") }
    check.call('labor_costs#index', 200) { request.call(:get, "/api/v1/projects/#{project_id}/labor_costs") }
    check.call('fixed_costs#index', 200) { request.call(:get, "/api/v1/projects/#{project_id}/fixed_costs") }
    check.call('overhead_rules#index', 200) { request.call(:get, "/api/v1/projects/#{project_id}/overhead_rules") }
    check.call('sales_forecasts#analysis', 200) do
      request.call(:get, "/api/v1/projects/#{project_id}/sales_forecasts/analysis")
    end
    check.call('pricing#show', 200) { request.call(:get, "/api/v1/projects/#{project_id}/pricing") }
    check.call('pricing#optimize', 200) do
      request.call(:post, "/api/v1/projects/#{project_id}/pricing/optimize",
                   targetPriceCents: 2999, targetPriceIncludesTax: true)
    end
    check.call('dashboard#show', 200) { request.call(:get, "/api/v1/projects/#{project_id}/dashboard") }
    check.call('risk_summaries#show', 200) { request.call(:get, "/api/v1/projects/#{project_id}/risk_summary") }
    check.call('risk_events#index', 200) { request.call(:get, "/api/v1/projects/#{project_id}/risk_events") }
    check.call('materials/card', 200) { request.call(:get, "/api/v1/materials/#{material_id}/card") }
    check.call('materials/risk_assessment', 200) do
      request.call(:get, "/api/v1/materials/#{material_id}/risk_assessment")
    end
    check.call('risk_providers#index', 200) { request.call(:get, '/api/v1/risk_providers') }
    check.call('risk_providers#probe', 200) { request.call(:post, '/api/v1/risk_providers/heuristic/probe') }
    check.call('risk_assessment/refresh', [200, 202]) do
      request.call(:post, "/api/v1/materials/#{material_id}/risk_assessment/refresh")
    end
    check.call('projects#export', 200) { request.call(:get, "/api/v1/projects/#{project_id}/export") }
    check.call('cost_templates#index', 200) { request.call(:get, '/api/v1/cost_templates') }
    check.call('health/unauthorized', 401) do
      saved = token
      token = nil
      result = request.call(:get, "/api/v1/projects/#{project_id}/materials/lead_time_analysis")
      token = saved
      result
    end

    puts
    if failures.empty?
      puts 'Smoke-Test erfolgreich.'
    else
      abort "Smoke-Test fehlgeschlagen (#{failures.size}): #{failures.join(', ')}"
    end
  end
end