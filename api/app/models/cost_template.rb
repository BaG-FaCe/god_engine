# A reusable set of cost positions (Tab 2/3) that can be saved, exported,
# imported and applied to any project.
#
# `items` is a relational child table (`cost_template_items`) so a template can
# hold monthly, labour and fixed cost rows at the same time - that is what
# `kind: "mixed"` means.
class CostTemplate < ApplicationRecord
  KINDS = %w[monthly_costs fixed_costs labor_costs mixed].freeze

  belongs_to :project, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :items, -> { order(:position, :created_at) },
                   class_name: 'CostTemplateItem', dependent: :destroy,
                   inverse_of: :cost_template

  validates :name, presence: true, length: { maximum: 200 }
  validates :kind, inclusion: { in: KINDS }

  scope :ordered, -> { order(is_global: :desc, name: :asc) }
  scope :for_project, ->(project) { where(project_id: [nil, project&.id]) }
  scope :global, -> { where(is_global: true) }
  scope :by_kind, ->(kind) { where(kind: kind) }

  # Normalised items (snake_case) used by `ApplyCostTemplate` and the legacy
  # callers. The child table is the source of truth.
  def normalised_items
    items.map(&:to_normalised)
  end

  # Items in the camelCase REST contract shape (`CostTemplateItem[]`).
  def items_as_json
    items.map(&:to_json_item)
  end

  def item_count
    items.size
  end

  def total_cents
    items.sum(:amount_cents)
  end

  def apply_to!(project)
    Calculator::Application::ApplyCostTemplate.call(project: project, template: self)
  end

  # Replaces the item list from raw client input (camelCase), tolerant towards
  # hand-written template files. Mirrors the pre-relational normalisation rules.
  def replace_items!(raw_items)
    transaction do
      items.destroy_all
      Array(raw_items).each_with_index do |raw, index|
        item = raw.respond_to?(:to_h) ? raw.to_h : {}
        item = item.deep_symbolize_keys
        items.create!(
          position: index,
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
        )
      end
    end
  end
end
