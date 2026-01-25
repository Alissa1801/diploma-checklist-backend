class CreateAnalysisResults < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_results do |t|
      t.references :check, null: false, foreign_key: true
      t.boolean :is_approved
      t.float :confidence_score
      t.jsonb :detected_objects
      t.jsonb :issues
      t.text :feedback
      t.string :ml_model_version

      t.timestamps
    end
  end
end
