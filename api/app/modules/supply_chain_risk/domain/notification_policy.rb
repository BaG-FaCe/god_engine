module SupplyChainRisk
  module Domain
    # Decides *whether* an in-app notification is triggered.
    #
    # Extracted from `NotifyRiskAlert` so the rule ("🔴 or a new risk_event") is a
    # pure, testable domain question instead of an `if` buried in a service:
    #
    #   * every new early-warning event notifies once - re-polls of the same feed
    #     neither create a new event nor a second notification
    #   * a material notifies when its aggregated traffic light turns 🔴, or when
    #     it stays 🔴 but the score changed; it stays silent when nothing changed
    #   * a configurable severity floor (`RISK_NOTIFICATION_MIN_SEVERITY`) lets an
    #     operator mute the noise of `low`/`medium` events without a deployment
    #
    # The policy only answers questions - it never writes. That keeps the
    # notification fan-out idempotent and easy to contract-test.
    class NotificationPolicy
      SEVERITY_ORDER = { 'low' => 0, 'medium' => 1, 'high' => 2, 'critical' => 3 }.freeze
      DEFAULT_MINIMUM_SEVERITY = 'low'
      MINIMUM_SEVERITY_ENV = 'RISK_NOTIFICATION_MIN_SEVERITY'

      # A material is "critical" for notification purposes at this risk level.
      CRITICAL_MATERIAL_LEVEL = 'high'

      class << self
        def minimum_severity
          configured = ENV.fetch(MINIMUM_SEVERITY_ENV, '').to_s.downcase
          return configured if SEVERITY_ORDER.key?(configured)

          DEFAULT_MINIMUM_SEVERITY
        end

        def severity_sufficient?(severity)
          SEVERITY_ORDER.fetch(severity.to_s, -1) >= SEVERITY_ORDER.fetch(minimum_severity)
        end

        # @param event [RiskEvent]
        # @return [Boolean]
        def notify_for_event?(event)
          return false unless event.respond_to?(:persisted?) && event.persisted?
          return false unless severity_sufficient?(event.severity)
          return false if event_already_notified?(event)

          true
        end

        # Idempotency guard: `risk_event_id` is unique per notification in
        # practice, but an explicit check keeps a retried job from double-firing.
        def event_already_notified?(event)
          RiskNotification.where(kind: 'risk_event', risk_event_id: event.id).exists?
        end

        # @param material [Material] the *reloaded* material after aggregation
        # @param previous_level [String, nil] aggregated level before the refresh
        # @param previous_score [Integer, nil] score before the refresh
        def notify_for_material?(material, previous_level: nil, previous_score: nil)
          return false unless material.respond_to?(:risk_level)
          return false unless material.risk_level.to_s == CRITICAL_MATERIAL_LEVEL

          # Still red with an unchanged score -> already notified, stay silent.
          return false if previous_level.to_s == CRITICAL_MATERIAL_LEVEL &&
                          previous_score == material.risk_score

          true
        end
      end
    end
  end
end
