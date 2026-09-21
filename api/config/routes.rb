# API routes — modular monolith.
#
# Every bounded context owns a route block below; cross-context endpoints
# (pricing, dashboard) compose the application services of both modules.
Rails.application.routes.draw do
  get 'up', to: 'rails/health#show', as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get 'health', to: 'health#show'

      # --- auth ----------------------------------------------------------
      post 'auth/login', to: 'auth#login'
      get 'auth/me', to: 'auth#me'

      # --- projects ------------------------------------------------------
      resources :projects do
        member do
          post 'duplicate'
          post 'archive'
          post 'restore'
          get 'export'
          post 'import'
        end

        resources :suppliers, controller: 'suppliers', only: %i[index show create update destroy]
        resources :materials, only: %i[index show create update destroy] do
          collection do
            get 'lead_time_analysis', to: 'materials#lead_time_analysis'
          end
        end
        resources :monthly_costs, controller: 'cost_blocks', defaults: { block: 'monthly_costs' },
                                  only: %i[index create update destroy]
        resources :sales_forecasts, controller: 'cost_blocks', defaults: { block: 'sales_forecasts' },
                                    only: %i[index create update destroy] do
          collection do
            get 'analysis', to: 'sales_forecasts#analysis'
          end
        end
        resources :labor_costs, controller: 'cost_blocks', defaults: { block: 'labor_costs' },
                                only: %i[index create update destroy]
        resources :fixed_costs, controller: 'cost_blocks', defaults: { block: 'fixed_costs' },
                                only: %i[index create update destroy]
        resources :overhead_rules, controller: 'cost_blocks', defaults: { block: 'overhead_rules' },
                                   only: %i[index create update destroy]
        resources :pricing_scenarios, controller: 'pricing_scenarios', only: %i[index show create update destroy] do
          member do
            post 'activate'
            post 'optimize'
          end
        end

        # Tab 4 + Tab 5 composition endpoints
        get 'pricing', to: 'pricing#show'
        post 'pricing/optimize', to: 'pricing#optimize'
        get 'dashboard', to: 'dashboards#show'
        get 'risk_summary', to: 'risk_summaries#show'
        get 'risk_events', to: 'risk_events#index'
      end

      # --- materials (top-level risk endpoints, spec § API-Design) --------
      resources :materials, only: [] do
        member do
          get 'risk_assessment', to: 'material_risk#show'
          post 'risk_assessment/manual', to: 'material_risk#create_manual'
          post 'risk_assessment/refresh', to: 'material_risk#refresh'
          get 'risk_events', to: 'material_risk#events'
          get 'card', to: 'material_cards#show'
        end
      end

      # --- risk providers --------------------------------------------------
      resources :risk_providers, only: %i[index], param: :key do
        member do
          post 'configure'
          post 'probe'
        end
      end
      resources :risk_events, only: %i[index show update]
      resources :cost_templates, only: %i[index show create update destroy] do
        member do
          post 'apply'
        end
      end

      # --- background job status -------------------------------------------
      resources :jobs, only: %i[show index]
    end
  end
end
