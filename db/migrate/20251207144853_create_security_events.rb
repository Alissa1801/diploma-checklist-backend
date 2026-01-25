class CreateSecurityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :security_events do |t|
      t.string :event_type
      t.json :details
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
