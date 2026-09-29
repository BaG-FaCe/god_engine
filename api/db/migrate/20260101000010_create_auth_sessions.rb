# frozen_string_literal: true

class CreateAuthSessions < DatabaseSetup::PlatformMigration
  def change
    routed_create_table :sessions, id: :string, limit: 36 do |t|
      t.string :user_id, null: false
      t.string :token_hash, null: false
      t.string :ip
      t.string :user_agent
      t.integer :duration_seconds, null: false, default: 86_400
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :revoked_by_id
      t.datetime :last_activity_at, null: false
      t.timestamps
    end

    routed_add_index :sessions, :user_id
    routed_add_index :sessions, :token_hash, unique: true
    routed_add_index :sessions, :expires_at
    routed_add_index :sessions, :revoked_at
  end
end
