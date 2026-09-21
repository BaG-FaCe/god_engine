module Shared
  module Infrastructure
    module Jobs
      # Platform aware Active Job adapter selection.
      #
      # Solid Queue is the production adapter (SQLite backed, no Redis) but its
      # supervisor calls `fork`, which is not available on Windows
      # (`Process.respond_to?(:fork)` is false, and `Kernel#fork` raises
      # `NotImplementedError`). Rather than making the whole stack Windows
      # incompatible, the adapter is resolved at boot:
      #
      #   BACKGROUND_JOB_ADAPTER=solid_queue  -> durable, out-of-process
      #   BACKGROUND_JOB_ADAPTER=async        -> in-process thread pool
      #   BACKGROUND_JOB_ADAPTER=inline       -> synchronous, tests only
      #
      # On Linux/macOS the default is `solid_queue`; on Windows it degrades to
      # `async` so that "refresh risk data" and the recurring provider polling
      # still work in a local development setup (see docs/15-deployment.md).
      class JobAdapter
        ADAPTERS = %i[solid_queue async inline].freeze

        Capabilities = Struct.new(
          :adapter,
          :durable,
          :concurrent,
          :supports_fork,
          :scheduler,
          :status_queryable,
          :note,
          keyword_init: true
        )

        class << self
          # True when the current Ruby/OS combination can run Solid Queue.
          def fork_available?
            return false if Gem.win_platform?
            return false unless Process.respond_to?(:fork)

            Process.fork { exit } && true
          rescue NotImplementedError, StandardError
            false
          end

          # Resolves the adapter from the environment, falling back to the best
          # adapter the platform can actually run.
          def resolve
            requested = ENV['BACKGROUND_JOB_ADAPTER'].presence&.to_sym
            return requested if requested && ADAPTERS.include?(requested)
            return :solid_queue if fork_available?

            :async
          end

          def install!
            adapter = resolve
            ActiveJob::Base.queue_adapter = adapter
            adapter
          end

          def capabilities(adapter = ActiveJob::Base.queue_adapter_name.to_sym)
            case adapter
            when :solid_queue
              Capabilities.new(
                adapter: :solid_queue,
                durable: true,
                concurrent: true,
                supports_fork: true,
                scheduler: true,
                status_queryable: defined?(SolidQueue::Job) ? true : false,
                note: 'Durable SQLite backed queue. Run the worker with `bin/jobs`.'
              )
            when :async
              Capabilities.new(
                adapter: :async,
                durable: false,
                concurrent: true,
                supports_fork: false,
                scheduler: false,
                status_queryable: false,
                note: 'In-process thread pool. Jobs are lost on restart and no ' \
                      'recurring scheduler is available.'
              )
            else
              Capabilities.new(
                adapter: adapter,
                durable: false,
                concurrent: false,
                supports_fork: fork_available?,
                scheduler: false,
                status_queryable: false,
                note: 'Synchronous execution - intended for tests only.'
              )
            end
          end

          # Rake tasks, the health endpoint and the docs all read this.
          def description
            caps = capabilities
            "#{caps.adapter} (durable=#{caps.durable}, scheduler=#{caps.scheduler})"
          end
        end
      end
    end
  end
end
