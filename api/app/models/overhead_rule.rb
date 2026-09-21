# Tab 3 - overhead / surcharge rules (Gemeinkostenzuschläge).
#
# Each rule is a percentage applied to a configurable base cost block. Rules with
# `auto_from_risk` are recalculated from the aggregated supply chain risk score
# by `Calculator::Application::ResolveRiskSurcharge`, which is how the risk data
# actually reaches the price.
class OverheadRule < ApplicationRecord
  BASES = %w[materials labor fixed_costs monthly_costs direct_cost subtotal].freeze

  DEFAULT_RULES = [
    { key: 'material_overhead', name: 'Materialgemeinkosten', percentage: 0.05,
      base: 'materials', auto_from_risk: false, position: 1 },
    { key: 'production_overhead', name: 'Fertigungsgemeinkosten', percentage: 0.12,
      base: 'labor', auto_from_risk: false, position: 2 },
    { key: 'admin_overhead', name: 'Verwaltungsgemeinkosten', percentage: 0.08,
      base: 'direct_cost', auto_from_risk: false, position: 3 },
    { key: 'risk_surcharge', name: 'Lieferrisiko-Zuschlag', percentage: 0.03,
      base: 'subtotal', auto_from_risk: true, position: 4 },
    { key: 'sales_overhead', name: 'Vertriebsgemeinkosten', percentage: 0.04,
      base: 'subtotal', auto_from_risk: false, position: 5 }
  ].freeze

  belongs_to :project, inverse_of: :overhead_rules

  validates :key, presence: true, format: { with: /\A[a-z0-9_]+\z/ },
                  uniqueness: { scope: :project_id }
  validates :name, presence: true, length: { maximum: 200 }
  validates :base, inclusion: { in: BASES }
  validates :percentage, numericality: { greater_than_or_equal_to: 0, less_than: 10 }

  scope :ordered, -> { order(:position, :key) }
  scope :enabled, -> { where(enabled: true) }
  scope :auto_from_risk, -> { where(auto_from_risk: true) }

  def self.bases
    BASES
  end
end