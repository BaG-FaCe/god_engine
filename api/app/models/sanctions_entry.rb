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
  # `upsert` needs an explicit `id` because the primary key is a UUID string
  # without a database default. `update_only` keeps the stable key
  # (`source`/`entity_name`) and the row's own UUID untouched on conflict - only
  # the list content is refreshed.
  def self.sync!(attributes)
    upsert(
      attributes.merge(id: SecureRandom.uuid),
      unique_by: %i[source entity_name],
      update_only: %i[list_name normalised_name entity_type country_code program
                      listed_on aliases identifiers updated_at]
    )
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