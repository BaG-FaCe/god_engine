# A reusable set of cost positions (Tab 2/3) that can be saved, exported,
# imported and applied to any project.
#
# `items` is a JSON array so a template can hold monthly, labour and fixed cost
# rows at the same time - that is what `kind: "mixed"` means.
class CostTemplate < ApplicationRecord
  KINDS = %w[monthly_costs fixed_costs labor_costs mixed].freeze

  belongs_to :project, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :name, presence: true, length: { maximum: 200 }
  validates :kind, inclusion: { in: KINDS }
  validate :items_are_well_formed

  scope :ordered, -> { order(is_global: :desc, name: :asc) }
  scope :for_project, ->(project) { where(project_id: [nil, project&.id]) }
  scope :global, -> { where(is_global: true) }
  scope :by_kind, ->(kind) { where(kind: kind) }

  # Normalised items; tolerant towards template files written by hand.
  def normalised_items
    Array(items).map do |raw|
      item = raw.respond_to?(:to_h) ? raw.to_h : {}
      item = item.deep_symbolize_keys

      {
        category: item[:category].to_s.presence || 'other',
        name: item[:name].to_s.presence || 'Position',
        amount_cents: Shared::Domain::Money.to_cents(item[:amount_cents]),
        is_recurring: item.fetch(:is_recurring, true),
        notes: item[:notes].presence,
        employee: item[:employee].presence,
        role: item[:role].presence,
        hours: item[:hours] && BigDecimal(item[:hours].to_s),
        hourly_rate_cents: item[:hourly_rate_cents] && Shared::Domain::Money.to_cents(item[:hourly_rate_cents]),
        allocation_basis: item[:allocation_basis].presence || 'per_unit'
      }
    end
  end

  def item_count
    Array(items).size
  end

  def total_cents
    normalised_items.sum { |item| item[:amount_cents].to_i }
  end

  def apply_to!(project)
    Calculator::Application::ApplyCostTemplate.call(project: project, template: self)
  end

  private

  def items_are_well_formed
    return if items.blank?

    unless items.is_a?(Array)
      errors.add(:items, 'muss eine Liste sein')
      return
    end

    normalised_items.each_with_index do |item, index|
      errors.add(:"items.#{index}.name", 'darf nicht leer sein') if item[:name].blank?
    end
  end
end