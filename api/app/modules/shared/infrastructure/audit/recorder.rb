module Shared
  module Infrastructure
    module Audit
      # Writes `AuditLog` rows for domain events that matter forensically:
      # data changes, imports/exports, provider configuration and risk refreshes.
      #
      # Everything is funnelled through this single class so the trail always has
      # the same shape - and so the recorder can be swapped for an event bus when
      # the contexts are split into services.
      class Recorder
        class << self
          # @param action [String] one of AuditLog::ACTIONS
          # @param auditable [ActiveRecord::Base, nil]
          # @param project [Project, String, nil]
          def call(action:, auditable: nil, project: nil, user: nil, changes: nil,
                   metadata: nil, request: nil)
            log = AuditLog.new(
              action: action,
              auditable_type: auditable&.class&.name,
              auditable_id: auditable&.id,
              project_id: resolve_project_id(project, auditable),
              user_id: user&.id,
              user_name: user&.name,
              changeset: serialise_changes(changes).merge(metadata || {}).presence,
              ip: request&.remote_ip,
              user_agent: request&.user_agent.to_s.truncate(255),
              occurred_at: Time.current
            )

            log.save!
            log
          rescue ActiveRecord::RecordInvalid => e
            # Auditing must never break the business transaction, but the failure
            # must be visible in the logs.
            Rails.logger.error("[audit] failed to record #{action}: #{e.message}")
            nil
          end

          # Records the diff of a saved record.
          def record_change(record, action:, user: nil, request: nil, project: nil)
            changes = record.previous_changes.except('updated_at', 'lock_version')
            return nil if action == 'update' && changes.empty?

            call(action: action, auditable: record, project: project || record,
                 user: user, changes: changes, request: request)
          end

          def record_export(resource, format:, user: nil, request: nil, project: nil)
            call(
              action: 'export', auditable: resource, project: project, user: user,
              request: request, metadata: { format: format }
            )
          end

          def record_import(project, source:, counts: {}, user: nil, request: nil)
            call(
              action: 'import', auditable: project, project: project, user: user,
              request: request, metadata: { source: source }.merge(counts)
            )
          end

          def record_provider_config(provider_key, action:, user: nil, request: nil, project: nil)
            call(
              action: action, auditable: nil, project: project, user: user, request: request,
              metadata: { providerKey: provider_key }
            )
          end

          def record_refresh(material, provider_keys:, user: nil, request: nil)
            call(
              action: 'refresh', auditable: material, project: material&.project,
              user: user, request: request, metadata: { providerKeys: provider_keys }
            )
          end

          private

          def resolve_project_id(project, auditable)
            return project.id if project.respond_to?(:id) && project.present?
            return project if project.is_a?(String)
            return auditable.project_id if auditable.respond_to?(:project_id)
            return auditable.id if auditable.is_a?(Project)

            nil
          end

          # Turns raw `previous_changes` values into JSON-safe scalars.
          def serialise_changes(changes)
            return {} if changes.blank?

            changes.to_h.transform_values do |(from, to)|
              { 'from' => jsonable(from), 'to' => jsonable(to) }
            end
          end

          def jsonable(value)
            case value
            when BigDecimal then value.to_s('F')
            when Date, Time, ActiveSupport::TimeWithZone, DateTime then value.iso8601
            when Array, Hash then value
            else value
            end
          end
        end
      end
    end
  end
end