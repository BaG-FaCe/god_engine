# One identifier of a `SanctionsEntry` (formerly the
# `sanctions_entries.identifiers` JSON hash: `{ type => value }`, e.g.
# `{ eu_reference => "...", remark => "..." }`).
class SanctionsEntryIdentifier < ApplicationRecord
  belongs_to :sanctions_entry, inverse_of: :sanctions_entry_identifiers

  validates :identifier_type, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :identifier_type) }
end
