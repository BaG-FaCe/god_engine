module Api
  module V1
    class JobsController < ApplicationController
      # GET /api/v1/jobs/:id — background job status (poll target for the SPA).
      def show
        result = Shared::Infrastructure::Jobs::JobStatus.find(params[:id])
        render json: {
          id: result.id, status: result.status, queueName: result.queue_name,
          jobClass: result.job_class, enqueuedAt: result.enqueued_at&.iso8601,
          finishedAt: result.finished_at&.iso8601, error: result.error,
          queryable: result.queryable
        }
      end

      def index
        render json: {
          data: Shared::Infrastructure::Jobs::JobStatus.recent(25).map do |result|
            { id: result.id, status: result.status, jobClass: result.job_class }
          end
        }
      end
    end
  end
end
