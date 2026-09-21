# Selects and installs the Active Job adapter for the current platform.
#
# Solid Queue needs `fork`; Windows does not have it, so the adapter degrades to
# the in-process `async` pool there (see
# `Shared::Infrastructure::Jobs::JobAdapter`).
Rails.application.config.after_initialize do
  chosen = Shared::Infrastructure::Jobs::JobAdapter.install!
  caps = Shared::Infrastructure::Jobs::JobAdapter.capabilities(chosen)

  Rails.logger.info(
    "[background-jobs] adapter=#{caps.adapter} durable=#{caps.durable} " \
    "scheduler=#{caps.scheduler} (#{caps.note})"
  )

  if chosen == :async && ENV['BACKGROUND_JOB_ADAPTER'].present?
    Rails.logger.warn(
      '[background-jobs] BACKGROUND_JOB_ADAPTER was set explicitly; ' \
      "ignoring the platform default (#{Shared::Infrastructure::Jobs::JobAdapter.fork_available? ? 'fork available' : 'fork unavailable'})."
    )
  end
end
