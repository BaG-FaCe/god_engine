# Platform foundation: users and the audit trail.
#
# UUID string primary keys are used throughout so that records remain unique
# when a bounded context is later extracted into its own service or when a
# project document is imported into a different installation.
class CreatePlatformFoundation < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :string, limit: 36 do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false, default: 'manager'
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_login_at
      t.string :locale, null: false, default: 'de'
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :role
    add_index :users, :active

    create_table :audit_logs, id: :string, limit: 36 do |t|
      t.string :user_id
      t.string :user_name
      t.string :project_id
      t.string :action, null: false
      t.string :auditable_type
      t.string :auditable_id
      t.json :changeset
      t.string :ip
      t.string :user_agent
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :audit_logs, %i[auditable_type auditable_id]
    add_index :audit_logs, :project_id
    add_index :audit_logs, :user_id
    add_index :audit_logs, :occurred_at
    add_index :audit_logs, :action
  end
end