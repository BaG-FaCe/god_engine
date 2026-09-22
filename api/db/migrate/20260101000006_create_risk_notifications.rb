# In-app risk notifications (spec § Lieferrisiko: "Bei 🔴 oder neuem risk_event
# wird eine In-App-Benachrichtigung ausgelöst").
#
# Notifications are deliberately *derived* at write time (by `NotifyRiskAlert`)
# instead of being computed on the fly from `risk_events` + materials:
#
#   * the dashboard needs a stable "unread" counter even after the user changes
#     or deletes master data,
#   * acknowledging is per user action, not per data row.
class CreateRiskNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :risk_notifications, id: :string, limit: 36 do |t|
      t.string :project_id
      t.string :material_id
      t.string :risk_event_id
      t.string :kind, null: false, default: 'risk_event'
      t.string :severity, null: false, default: 'medium'
      t.string :title, null: false
      t.text :body
      t.json :payload
      t.datetime :read_at
      t.string :read_by_id
      t.timestamps
    end
    add_index :risk_notifications, %i[project_id created_at]
    add_index :risk_notifications, :read_at
    add_index :risk_notifications, :severity
    add_foreign_key :risk_notifications, :projects, column: :project_id
    add_foreign_key :risk_notifications, :materials, column: :material_id
  end
end
