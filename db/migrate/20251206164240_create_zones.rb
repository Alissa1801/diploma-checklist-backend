class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones do |t|
      t.string :name
      t.text :description
      t.jsonb :expected_objects
      t.jsonb :expected_conditions
      t.string :reference_photo_url

      t.timestamps
    end
  end
end
