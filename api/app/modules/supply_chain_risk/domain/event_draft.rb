module SupplyChainRisk
  module Domain
    # A normalised early-warning signal returned by an event-capable provider.
    #
    # `source_event_id` makes ingestion idempotent: the unique index on
    # `(source, source_event_id)` means a re-poll of the same feed updates nothing
    # and creates no duplicates.
    EventDraft = Data.define(
      :source, :source_event_id, :event_type, :severity, :title, :description,
      :country_code, :occurred_at, :metadata, :material_id, :project_id
    ) do
      def self.build(**kwargs)
        new(
          source: kwargs.fetch(:source),
          source_event_id: kwargs[:source_event_id]&.to_s,
          event_type: kwargs.fetch(:event_type),
          severity: kwargs.fetch(:severity, 'medium'),
          title: kwargs.fetch(:title),
          description: kwargs[:description],
          country_code: kwargs[:country_code]&.to_s&.upcase,
          occurred_at: kwargs.fetch(:occurred_at),
          metadata: kwargs[:metadata],
          material_id: kwargs[:material_id],
          project_id: kwargs[:project_id]
        )
      end

      def valid?
        title.present? && RiskEvent::TYPES.include?(event_type) &&
          RiskEvent::SEVERITIES.include?(severity)
      end

      # Upsert: create the event, or refresh its severity/description when the
      # same upstream event is seen again with new information.
      def persist!
        return nil unless valid?

        event = RiskEvent.find_or_initialize_by(source: source, source_event_id: source_event_id) do |record|
          record.event_type = event_type
          record.title = title
          record.occurred_at = occurred_at
        end

        event.assign_attributes(
          severity: severity,
          description: description,
          country_code: country_code,
          metadata: metadata,
          material_id: material_id,
          project_id: project_id
        )
        event.save! if event.new_record? || event.changed?

        event
      rescue ActiveRecord::RecordNotUnique
        RiskEvent.find_by(source: source, source_event_id: source_event_id)
      end

      def to_h
        {
          source: source,
          sourceEventId: source_event_id,
          eventType: event_type,
          severity: severity,
          title: title,
          description: description,
          countryCode: country_code,
          occurredAt: occurred_at&.iso8601,
          metadata: metadata
        }
      end
    end
  end
end