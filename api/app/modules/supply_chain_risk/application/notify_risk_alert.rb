module SupplyChainRisk
  module Application
    # In-app notification fan-out (spec § Lieferrisiko: "Bei 🔴 oder neuem
    # risk_event wird eine In-App-Benachrichtigung ausgelöst und im Dashboard
    # unter 'Kritische Lieferrisiken' aggregiert").
    #
    # Two entry points, both idempotent:
    #
    #   * `for_event!`  - called by `EventDraft#persist!` for every *new* event
    #   * `for_material!` - called by `RefreshMaterialRisk` when the aggregated
    #     traffic light flips to red (previous state is passed in by the caller)
    #
    # Whether a notification is appropriate at all is decided by
    # `Domain::NotificationPolicy` - this service only writes. Notification
    # creation must never break the write path that produced it, so a failing
    # insert is logged and swallowed.
    class NotifyRiskAlert
      class << self
        # A new early-warning event for a project / material.
        # @return [RiskNotification, nil]
        def for_event!(event, policy: Domain::NotificationPolicy)
          return nil unless policy.notify_for_event?(event)

          RiskNotification.create!(
            project_id: event.project_id,
            material_id: event.material_id,
            risk_event_id: event.id,
            kind: 'risk_event',
            severity: event.severity,
            title: event.title.truncate(300),
            body: event.description,
            payload: {
              source: event.source,
              countryCode: event.country_code,
              eventType: event.event_type,
              # Deep-link target: the SPA opens the material card with the
              # supply-chain-risk section expanded.
              materialId: event.material_id,
              riskEventId: event.id
            }.compact
          )
        rescue StandardError => e
          Rails.logger.warn("[supply-chain-risk] notification for event #{event.id} failed: #{e.message}")
          nil
        end

        # A material whose aggregate turned 🔴 (or stayed 🔴 with a new score).
        # @return [RiskNotification, nil]
        def for_material!(material, previous_level: nil, previous_score: nil,
                          policy: Domain::NotificationPolicy)
          return nil unless policy.notify_for_material?(material, previous_level: previous_level,
                                                                  previous_score: previous_score)

          RiskNotification.create!(
            project_id: material.project_id,
            material_id: material.id,
            kind: 'critical_material',
            severity: 'critical',
            title: "#{material.name} ist jetzt kritisch (Score #{material.risk_score})",
            body: 'Lieferrisiko hoch — Alternativlieferant prüfen und Kalkulation absichern.',
            payload: { riskScore: material.risk_score, riskLevel: material.risk_level,
                       materialId: material.id }
          )
        rescue StandardError => e
          Rails.logger.warn("[supply-chain-risk] notification for material #{material.id} failed: #{e.message}")
          nil
        end
      end
    end
  end
end
