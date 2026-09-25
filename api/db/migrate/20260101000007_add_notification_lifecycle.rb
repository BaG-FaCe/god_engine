# Notification lifecycle columns (Update-Prompt Aufgabe 2).
#
# `RiskNotification` already exposed `acknowledged_at/acknowledged_by` and
# `dismissed_at/dismissed_by`, but the columns were never migrated - the model
# contract was ahead of the schema. Adding them here keeps the
# "acknowledge/dismiss instead of delete" rule enforceable at the database level,
# so the notification history stays auditable.
#
# Nothing is ever deleted: `dismissed_at` only hides a row from the open list.
class AddNotificationLifecycle < ActiveRecord::Migration[8.0]
  def change
    add_column :risk_notifications, :acknowledged_at, :datetime
    add_column :risk_notifications, :acknowledged_by_id, :string
    add_column :risk_notifications, :dismissed_at, :datetime
    add_column :risk_notifications, :dismissed_by_id, :string

    add_index :risk_notifications, :acknowledged_at
    add_index :risk_notifications, :dismissed_at
  end
end
