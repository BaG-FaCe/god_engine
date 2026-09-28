# frozen_string_literal: true

module DatabaseSetup
  # Base class for every platform migration.
  #
  # Migrations are the single source of the schema. Because the four logical
  # databases may be separate physical databases, each DDL statement is routed
  # to the connection that owns the affected table (see `TableRouting`).
  #
  # On a single-database backend (SQLite) routing is inert and the helpers
  # behave exactly like the plain ActiveRecord migration methods, so the file
  # based development setup and the test suite are unaffected.
  class PlatformMigration < ActiveRecord::Migration[8.0]
    private

    def routed_connection(table)
      TableRouting.connection_for(table, fallback: connection)
    end

    def routed_create_table(table, **options, &block)
      routed_connection(table).create_table(table, **options, &block)
    end

    def routed_drop_table(table, **options)
      routed_connection(table).drop_table(table, **options)
    end

    def routed_add_index(table, columns, **options)
      routed_connection(table).add_index(table, columns, **options)
    end

    def routed_add_column(table, column, type, **options)
      routed_connection(table).add_column(table, column, type, **options)
    end

    def routed_remove_column(table, column, type = nil, **options)
      conn = routed_connection(table)
      type ? conn.remove_column(table, column, type, **options) : conn.remove_column(table, column)
    end

    def routed_change_column(table, column, type, **options)
      routed_connection(table).change_column(table, column, type, **options)
    end

    # Foreign keys are only created when both tables live in the same physical
    # database (SQL Server/MariaDB cannot enforce cross-database keys). The
    # relationship is still implemented application-side and documented.
    def routed_add_foreign_key(from_table, to_table, **options)
      return if TableRouting.cross_database?(from_table, to_table)

      routed_connection(from_table).add_foreign_key(from_table, to_table, **options)
    end

    def routed_select_all(table, sql)
      routed_connection(table).select_all(sql)
    end

    def routed_execute(table, sql)
      routed_connection(table).execute(sql)
    end

    def routed_quote(table, value)
      routed_connection(table).quote(value)
    end
  end
end
