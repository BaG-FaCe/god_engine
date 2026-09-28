# Abstract base for every model persisted in the `logs` database of a SQL
# backend: the append-only audit trail, provider run bookkeeping and migration
# run records.
#
# On a single-database backend (explicit SQLite mode, test suite) this class
# simply inherits the primary connection.
class LogsRecord < ApplicationRecord
  self.abstract_class = true
end
