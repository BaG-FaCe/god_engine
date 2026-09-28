# Abstract base for every model persisted in the `users` database of a SQL
# backend (SQL Server / MariaDB): application users and their identity data.
#
# On a single-database backend (explicit SQLite mode, test suite) this class
# simply inherits the primary connection, so nothing changes for the file based
# setup - all tables live in one file.
class UsersRecord < ApplicationRecord
  self.abstract_class = true
end
