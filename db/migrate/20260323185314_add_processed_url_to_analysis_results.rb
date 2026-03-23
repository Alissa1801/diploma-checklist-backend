class AddProcessedUrlToAnalysisResults < ActiveRecord::Migration[8.1]
  def change
    add_column :analysis_results, :processed_url, :string
  end
end
