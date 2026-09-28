# Abstract base for every model persisted in the `events` database of a SQL
# backend: application events and the notifications derived from them.
#
# On a single-database backend (explicit SQLite mode, test suite) this class
# simply inherits the primary connection.
class EventsRecord < ApplicationRecord
  self.abstract_class = true
end
