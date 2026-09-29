module Api
  module V1
    # Base controller: JSON defaults, bearer auth, uniform error envelope.
    class ApplicationController < ActionController::API
      AUTH_HEADER = /\ABearer\s+(.+)\z/i.freeze

      before_action :set_default_format
      before_action :ensure_persistence_ready!
      # --- GLOBAL AUTHENTICATION GATE ----------------------------------------
      # The platform is private by default: every endpoint requires a valid,
      # non-expired, non-revoked session for an active user, unless a controller
      # explicitly opts out below (first-run setup, health probe, login). This
      # boundary must never rely on a per-controller `authenticate_user!` call
      # being remembered - it fails closed at the base class.
      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      # Guards raise these so they *halt* the action (rendering alone does not
      # stop execution; the previous implementation let a forbidden write fall
      # through into a second render and a 500).
      class NotAuthorized < StandardError; end
      class Forbidden < StandardError; end

      rescue_from NotAuthorized, with: :render_unauthorized
      rescue_from Forbidden, with: :render_forbidden

      private

      def set_default_format
        request.format = :json
      end

      # --- persistence gate -------------------------------------------------

      # The application must not serve persistent data while the SQL backend is
      # unconfigured: the first-run setup screen has to be completed first.
      # Endpoints that do not touch persistence (setup, health) skip this.
      def ensure_persistence_ready!
        return unless DatabaseSetup::Runtime.setup_required?

        render_error(
          'Der SQL-Backend ist nicht konfiguriert. Bitte zuerst die Ersteinrichtung abschließen.',
          code: 'sql_server_setup_required', status: :service_unavailable
        )
      end

      # --- auth -----------------------------------------------------------

      def current_session
        return @current_session if defined?(@current_session)

        token = bearer_token
        @current_session = token.present? ? Session.authenticate(token) : nil
      rescue StandardError
        # Fail closed: if the session store cannot confirm validity (DB down,
        # inconsistent data, ...) the caller must NOT be treated as authenticated.
        @current_session = nil
      end

      def current_user
        return @current_user if defined?(@current_user)

        # The SQL-backed Session is the single authoritative authentication
        # source. `current_session` already fails closed (returns nil on any
        # validation error), so there is no fallback path.
        @current_user = current_session&.user
      end

      # Session tokens are accepted ONLY via the `Authorization: Bearer <token>`
      # header. Tokens are deliberately never read from query parameters, because
      # tokens in URLs leak into access logs, browser history and referrers.
      def bearer_token
        header = request.headers['Authorization'].to_s
        match = AUTH_HEADER.match(header)
        match && match[1].strip
      end

      def authenticate_user!
        raise NotAuthorized if current_user.nil?
      end

      def require_write!
        authenticate_user!
        raise Forbidden unless current_user.can_write?
      end

      def require_admin!
        authenticate_user!
        raise Forbidden unless current_user.admin?
      end

      def audit(action, auditable: nil, project: nil, changes: nil, metadata: nil)
        Shared::Infrastructure::Audit::Recorder.call(
          action: action, auditable: auditable, project: project,
          user: current_user, changes: changes, metadata: metadata, request: request
        )
      end

      # --- pagination ------------------------------------------------------

      def pagination_params(default_per_page: 50)
        page = params[:page].to_i
        per_page = params[:per_page].to_i
        {
          page: page.positive? ? page : 1,
          per_page: per_page.positive? ? [per_page, 200].min : default_per_page
        }
      end

      def paginate(scope)
        pagination = pagination_params
        records = scope.page(pagination[:page]).per(pagination[:per_page]) rescue scope
        [records, pagination]
      end

      def render_paginated(records, total:, page:, per_page:, serializer: nil)
        data = serializer ? records.map { |record| serializer.call(record) } : records
        render json: {
          data: data,
          meta: {
            page: page, perPage: per_page, total: total,
            totalPages: (total.to_f / per_page).ceil
          }
        }
      end

      # --- errors -----------------------------------------------------------

      def render_error(message, code: 'bad_request', status: :bad_request, details: nil)
        body = { error: { code: code, message: message } }
        body[:error][:details] = details if details
        render json: body, status: status
      end

      def render_not_found(exception)
        render_error(exception.message, code: 'not_found', status: :not_found)
      end

      def render_unprocessable(exception)
        details = exception.record.errors.to_hash
        render_error(
          "Validierung fehlgeschlagen: #{exception.record.errors.full_messages.first}",
          code: 'validation_error', status: :unprocessable_entity, details: details
        )
      end

      def render_bad_request(exception)
        render_error(exception.message, code: 'bad_request', status: :bad_request)
      end

      def render_unauthorized(_exception = nil)
        render_error('Ungültige oder abgelaufene Anmeldung', code: 'unauthorized', status: :unauthorized)
      end

      def render_forbidden(_exception = nil)
        render_error('Keine Schreibberechtigung', code: 'forbidden', status: :forbidden)
      end
    end
  end
end
