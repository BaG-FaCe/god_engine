module Api
  module V1
    # Base controller: JSON defaults, bearer auth, uniform error envelope.
    class ApplicationController < ActionController::API
      AUTH_HEADER = /\ABearer\s+(.+)\z/i.freeze

      before_action :set_default_format

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from JWT::DecodeError, JWT::ExpiredSignature, with: :render_unauthorized

      private

      def set_default_format
        request.format = :json
      end

      # --- auth -----------------------------------------------------------

      def current_user
        return @current_user if defined?(@current_user)

        token = bearer_token
        @current_user =
          if token.present?
            payload = Auth::JsonWebToken.decode(token)
            User.active.find_by(id: payload['sub'])
          end
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      # Accepts `Authorization: Bearer <token>` (the SPA) and `token` query
      # parameters used by the smoke-test scripts.
      def bearer_token
        header = request.headers['Authorization'].to_s
        match = AUTH_HEADER.match(header)
        return match[1].strip if match

        params[:token].presence
      end

      def authenticate_user!
        render_unauthorized(StandardError.new('Anmeldung erforderlich')) if current_user.nil?
      end

      def require_write!
        authenticate_user!
        return if current_user.can_write?

        render_error('Keine Schreibberechtigung', code: 'forbidden', status: :forbidden)
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
    end
  end
end
