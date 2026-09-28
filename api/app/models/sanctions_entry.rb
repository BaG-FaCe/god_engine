# Locally cached entry of a public sanctions / restricted party list
# (EU consolidated list, UN list). Populated by
# `SupplyChainRisk::Infrastructure::Providers::FreeData::EUSanctionsProvider`
# and queried by the sanctions screening service.
#
# The list is cached in the application database rather than in Solid Cache
# because screening must keep working when the upstream list is unreachable - a
# "clear" result based on a stale list is still worth more than an error.
class SanctionsEntry < ApplicationRecord
  SOURCES = %w[eu_consolidated un_consolidated ofac_sdn manual].freeze
  ENTITY_TYPES = %w[entity individual vessel aircraft].freeze

  validates :source, inclusion: { in: SOURCES }
  validates :list_name, :entity_name, :normalised_name, presence: true
  validates :entity_type, inclusion: { in: ENTITY_TYPES }
  validates :country_code, length: { is: 2 }, allow_nil: true

  has_many :sanctions_entry_aliases, -> { order(:position, :name) },
            dependent: :destroy, inverse_of: :sanctions_entry
  has_many :sanctions_entry_identifiers, -> { order(:position, :identifier_type) },
            dependent: :destroy, inverse_of: :sanctions_entry

  scope :by_source, ->(source) { where(source: source) }
  scope :for_country, ->(code) { where(country_code: code.to_s.upcase) }

  # Matches a supplier name against the cached lists.
  #
  # The normaliser strips legal suffixes, punctuation and accents so that
  # "OOO Sibur Holding" and "Sibur" both collide with the listed entity.
  LEGAL_SUFFIXES = %w[
    gmbh ag kg kgaa ltd limited llc inc incorporated sa sas sarl bv nv ab as oy
    spa srl plc pte pvt co corp corporation holding holdings group
    ooo oao pao jsc ojsc cjsc
  ].freeze

  # Idempotent bulk import used by the list sync providers.
  #
  # Aliases and identifiers (formerly JSON columns) are persisted as child rows.
  # The `(source, entity_name)` unique index keeps the entry's UUID stable across
  # syncs; only the list content and children are refreshed.
  def self.sync!(attributes)
    aliases = Array(attributes.delete(:aliases))
    identifiers = (attributes.delete(:identifiers) || {}).to_a
    entry = find_or_initialize_by(source: attributes[:source], entity_name: attributes[:entity_name])
    entry.assign_attributes(attributes)
    entry.save!
    entry.replace_aliases!(aliases)
    entry.replace_identifiers!(identifiers)
    entry
  end

  def replace_aliases!(names)
    transaction do
      sanctions_entry_aliases.destroy_all
      Array(names).each_with_index do |name, index|
        next if name.blank?

        sanctions_entry_aliases.create!(name: name.to_s, position: index)
      end
    end
  end

  def replace_identifiers!(pairs)
    transaction do
      sanctions_entry_identifiers.destroy_all
      Array(pairs).each_with_index do |(type, value), index|
        next if value.blank?

        sanctions_entry_identifiers.create!(identifier_type: type.to_s, value: value.to_s, position: index)
      end
    end
  end

  def self.normalise(name)
    value = name.to_s.unicode_normalize(:nfkd).gsub(/[^\p{Alnum}\s]/, ' ').downcase
    tokens = value.split(/\s+/).reject(&:empty?).reject { |token| LEGAL_SUFFIXES.include?(token) }
    tokens.join(' ')
  end

  def self.search(name)
    key = normalise(name)
    return none if key.length < 4

    where(normalised_name: key)
  end

  # Fuzzy containment search used as a second pass when the exact match fails.
  def self.search_loosely(name)
    key = normalise(name)
    return none if key.length < 6

    # NOTE: SQLite treats double-quoted text as an *identifier*, so the wildcard
    # literals are written with single quotes (escaped for Ruby).
    where("normalised_name LIKE ? OR normalised_name LIKE ? OR ? LIKE '%' || normalised_name || '%'",
          "#{sanitize_sql_like(key)} %", "% #{sanitize_sql_like(key)}", key)
  end
end