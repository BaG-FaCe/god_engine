# One normalised cost position of a reusable `CostTemplate` (formerly the
# `cost_templates.items` JSON array). A mixed template stores monthly, labour
# and fixed rows in the same shape; the fields that only apply to a specific
# kind are nullable.
class CostTemplateItem < ApplicationRecord
  belongs_to :cost_template, inverse_of: :items

  validates :name, presence: true, length: { maximum: 200 }
  validates :amount_cents, :hourly_rate_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, -> { order(:position, :created_at) }

  # snake_case hash used by `CostTemplate#normalised_items` and
  # `Calculator::Application::ApplyCostTemplate`.
  def to_normalised
    {
      category: category,
      name: name,
      amount_cents: amount_cents,
      is_recurring: is_recurring,
      notes: notes,
      employee: employee,
      role: role,
      hours: hours,
      hourly_rate_cents: hourly_rate_cents,
      allocation_basis: allocation_basis
    }
  end

  # camelCase hash used by the REST serializer (`CostTemplateItem[]`).
  def to_json_item
    {
      category: category,
      name: name,
      amountCents: amount_cents,
      isRecurring: is_recurring,
      notes: notes,
      employee: employee,
      role: role,
      hours: hours&.to_f,
      hourlyRateCents: hourly_rate_cents,
      allocationBasis: allocation_basis
    }
  end
end
