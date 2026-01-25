class CreateChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :checks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :zone, null: false, foreign_key: true
      t.integer :status
      t.datetime :submitted_at
      t.datetime :completed_at
      t.text :feedback
      t.float :score

      t.timestamps
    end
  end
end
