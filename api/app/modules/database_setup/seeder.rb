# frozen_string_literal: true

module DatabaseSetup
  # Runs the application's seed data (`db/seeds.rb`) against the current
  # connection. After the bootstrap has switched the primary connection to SQL
  # Server, this guarantees the *initial entry* exists there too: the admin user
  # and the demo project (idempotent — `find_or_create_by!`).
  #
  # Without this step a fresh SQL Server installation would be empty and
  # unusable (no admin login), even though the schema and the legacy data were
  # migrated correctly.
  class Seeder
    def self.call
      Rails.application.load_seed

      {
        users: User.count,
        projects: Project.count,
        materials: Material.count
      }
    end
  end
end
