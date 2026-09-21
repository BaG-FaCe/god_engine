module Calculator
  module Application
    # Applies a reusable cost template to a project.
    class ApplyCostTemplate
      class << self
        def call(project:, template:)
          created = Hash.new(0)
          Project.transaction do
            template.normalised_items.each do |item|
              case template.kind
              when 'monthly_costs', 'mixed'
                project.monthly_costs.create!(
                  category: item[:category], name: item[:name],
                  amount_cents: item[:amount_cents], notes: item[:notes]
                )
                created[:monthlyCosts] += 1
              when 'fixed_costs'
                project.fixed_costs.create!(
                  category: item[:category], name: item[:name],
                  amount_cents: item[:amount_cents], allocation_basis: item[:allocation_basis]
                )
                created[:fixedCosts] += 1
              when 'labor_costs'
                project.labor_costs.create!(
                  employee: item[:employee] || item[:name], hours: item[:hours] || 0,
                  hourly_rate_cents: item[:hourly_rate_cents] || item[:amount_cents] || 0
                )
                created[:laborCosts] += 1
              end
            end
          end
          created
        end
      end
    end
  end
end
