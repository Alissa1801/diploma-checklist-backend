class CreateSystemErrors < ActiveRecord::Migration[8.1]
  def change
    create_table :system_errors do |t|
      t.string :error_class
      t.text :error_message
      t.text :backtrace
      t.json :context
      t.datetime :resolved_at
      t.text :resolution_notes

      t.timestamps
    end
  end
end
