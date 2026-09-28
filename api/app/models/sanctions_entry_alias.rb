# One alternative name of a `SanctionsEntry` (formerly the
# `sanctions_entries.aliases` JSON array of strings).
class SanctionsEntryAlias < ApplicationRecord
  belongs_to :sanctions_entry, inverse_of: :sanctions_entry_aliases

  validates :name, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :name) }
end
