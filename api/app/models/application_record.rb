require 'securerandom'

# Base class for every Active Record model in the platform.
#
# All tables use string UUID primary keys so records stay globally unique across
# imports and future service extraction. UUIDs are generated in Ruby
# (`SecureRandom.uuid`) instead of by the database, which keeps behaviour
# identical on SQLite and PostgreSQL and lets nested documents be built before
# their parents are persisted.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_validation :ensure_uuid, on: :create

  # True for records whose primary key has been assigned but which may not be
  # persisted yet - needed by the serialisers when building nested documents.
  def uuid?
    self[:id].to_s.length == 36
  end

  private

  def ensure_uuid
    self.id ||= SecureRandom.uuid
  end
end