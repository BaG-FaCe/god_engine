# Puma configuration.
#
# Solid Queue can either run as a separate `bin/jobs` process (recommended) or
# inside Puma via the plugin below. The plugin relies on `fork`, so it must stay
# disabled on Windows - see docs/15-deployment.md.
max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 5)
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` in seconds.
worker_timeout 3600 if ENV.fetch('RAILS_ENV', 'development') == 'development'

port ENV.fetch('PORT', 3000)
environment ENV.fetch('RAILS_ENV') { 'development' }

pidfile ENV.fetch('PIDFILE', 'tmp/pids/server.pid')

# Allow the Solid Queue supervisor to run inside Puma with `SOLID_QUEUE_IN_PUMA`.
plugin :solid_queue if ENV['SOLID_QUEUE_IN_PUMA'] && Process.respond_to?(:fork)

# Allow puma to be restarted by `bin/rails restart`.
plugin :tmp_restart
