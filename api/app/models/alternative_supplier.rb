# An alternative sourcing option for a material - the concrete mitigation the
# risk module recommends when a supplier or route becomes critical.
class AlternativeSupplier < ApplicationRecord
  belongs_to :material, inverse_of: :alternative_suppliers
  belongs_to :supplier, optional: true

  validates :name, presence: true, length: { maximum: 200 }
  validates :priority, numericality: { only_integer: true, greater_than: 0 }
  validates :lead_time_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                             allow_nil: true
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                               allow_nil: true
  validates :country, length: { is: 2 }, allow_nil: true

  scope :ordered, -> { order(:priority, :name) }
  scope :preferred, -> { ordered.first }

  def price_delta_cents
    return nil if unit_price_cents.nil?

    unit_price_cents - material.net_unit_price_cents
  end

  def price_delta_pct
    delta = price_delta_cents
    base = material.net_unit_price_cents
    return nil if delta.nil? || base.to_i.zero?

    delta.to_f / base
  end
end