module Shared
  module Infrastructure
    module Jobs
      # Uniform status lookup across adapters.
      #
      # The risk refresh endpoints return a job handle so the SPA can poll for
      # completion. Solid Queue can be queried, the `async` adapter cannot - in
      # that case the endpoint reports `status: "unknown"` and the SPA falls back
      # to re-fetching the assessment, which keeps the UI identical on both
      # platforms.
      class JobStatus
        Result = Struct.new(
          :id,
          :status,
          :queue_name,
          :job_class,
          :enqueued_at,
          :finished_at,
          :error,
          :queryable,
          keyword_init: true
        )

        STATUSES = %w[pending scheduled running finished failed].freeze

        class << self
          def queryable?
            JobAdapter.capabilities.status_queryable
          end

          def find(job_id)
            return unavailable(job_id) if job_id.blank? || !queryable?

            record = SolidQueue::Job.find_by(active_job_id: job_id)
            return unavailable(job_id) if record.nil?

            Result.new(
              id: job_id,
              status: map_status(record),
              queue_name: record.queue_name,
              job_class: record.class_name,
              enqueued_at: record.created_at,
              finished_at: record.finished_at,
              error: failure_message(record),
              queryable: true
            )
          end

          def recent(limit = 25)
            return [] unless queryable?

            SolidQueue::Job.order(created_at: :desc).limit(limit).map do |record|
              Result.new(
                id: record.active_job_id,
                status: map_status(record),
                queue_name: record.queue_name,
                job_class: record.class_name,
                enqueued_at: record.created_at,
                finished_at: record.finished_at,
                error: failure_message(record),
                queryable: true
              )
            end
          end

          private

          def unavailable(job_id)
            Result.new(
              id: job_id,
              status: 'unknown',
              queue_name: nil,
              job_class: nil,
              enqueued_at: nil,
              finished_at: nil,
              error: nil,
              queryable: false
            )
          end

          def map_status(record)
            return 'failed' if record.finished_at && record.failed?
            return 'finished' if record.finished_at
            return 'running' if running?(record)
            return 'scheduled' if record.scheduled_at && record.scheduled_at > Time.current

            'pending'
          end

          def running?(record)
            return false unless defined?(SolidQueue::ClaimedExecution)

            SolidQueue::ClaimedExecution.where(job_id: record.id).exists?
          rescue ActiveRecord::StatementInvalid
            false
          end

          def failure_message(record)
            return nil unless record.respond_to?(:finished_at) && record.finished_at

            failure = SolidQueue::FailedExecution.find_by(job_id: record.id)
            failure&.error&.dig('message') || failure&.error&.dig(:message)
          rescue ActiveRecord::StatementInvalid
            nil
          end
        end
      end
    end
  end
end
