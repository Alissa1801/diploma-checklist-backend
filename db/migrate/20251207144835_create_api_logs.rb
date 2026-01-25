class CreateApiLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :api_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :method
      t.string :path
      t.json :params
      t.integer :status
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
