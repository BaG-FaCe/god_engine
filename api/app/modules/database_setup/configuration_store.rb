# frozen_string_literal: true

require 'yaml'

module DatabaseSetup
  # Persists the SQL backend configuration to a local, gitignored file and reads
  # it back. Environment variables take precedence, which keeps the store a
  # purely *local, environment-specific* mechanism:
  #
  #   * first-run setup writes `config/sqlserver.local.yml` (gitignored, 0600 on
  #     POSIX systems),
  #   * production deployments should use environment variables / a secret
  #     manager instead of the file.
  #
  # The password is stored because the file is the application's own secret
  # store, but it is never returned in logs and the file is excluded from git.
  class ConfigurationStore
    FILE_NAME = 'sqlserver.local.yml'
    # The test suite must never read a developer's live `sqlserver.local.yml`;
    # it uses a distinct, non-existent filename so the first-run state stays
    # reproducible regardless of what is configured for local development.
    TEST_FILE_NAME = 'sqlserver.local.test.yml'

    class << self
      def path
        Rails.root.join('config', Rails.env.test? ? TEST_FILE_NAME : FILE_NAME)
      end

      def local_file_present?
        File.exist?(path)
      end

      def configured?
        env_configured? || local_file_present?
      end

      def env_configured?
        ENV['SQL_SERVER'].present? && ENV['SQL_USER'].present? && ENV['SQL_PASSWORD'].present?
      end

      # Highest precedence first: environment, then the local file.
      def load
        from_env || from_file
      end

      def from_env
        return nil unless env_configured?

        Configuration.new(
          adapter: ENV.fetch('SQL_ADAPTER', 'sqlserver'),
          host: ENV['SQL_SERVER'],
          port: ENV['SQL_PORT'],
          username: ENV['SQL_USER'],
          password: ENV['SQL_PASSWORD'],
          database: ENV.fetch('SQL_DATABASE', 'productdata'),
          users_database: ENV.fetch('SQL_USERS_DATABASE', 'users'),
          events_database: ENV.fetch('SQL_EVENTS_DATABASE', 'events'),
          logs_database: ENV.fetch('SQL_LOGS_DATABASE', 'logs'),
          encrypt: ENV.fetch('SQL_ENCRYPT', 'true') != 'false',
          timeout: ENV.fetch('SQL_TIMEOUT', 15)
        )
      end

      def from_file
        return nil unless File.exist?(path)

        data = YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: true) || {}
        return nil if data.blank?

        Configuration.new(**data.symbolize_keys)
      rescue Errno::ENOENT, Psych::SyntaxError, ArgumentError, TypeError => e
        Rails.logger&.warn("Ignoring unreadable SQL Server config file: #{e.class}")
        nil
      end

      def save(configuration)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, configuration.to_h.stringify_keys.to_yaml)
        restrict_permissions(path)
        configuration
      end

      def clear
        File.delete(path) if File.exist?(path)
      end

      private

      # 0600 keeps the credential file readable only by the owning user on
      # POSIX systems. Windows ACLs are the operator's responsibility (the file
      # is still excluded from source control via .gitignore).
      def restrict_permissions(file)
        File.chmod(0o600, file) unless Gem.win_platform?
      rescue Errno::EPERM, Errno::ENOENT
        nil
      end
    end
  end
end
