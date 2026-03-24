class AnalysisResultSerializer < ActiveModel::Serializer
  attributes :id, :check_id, :confidence_score, :is_approved,
             :detected_objects, :issues, :feedback,
             :processed_url, :ml_model_version

  def processed_url
    return nil unless object.processed_url
    # Склеиваем домен сервера и путь к картинке
    "#{instance_options[:base_url] || 'https://diploma-checklist-backend-production.up.railway.app'}#{object.processed_url}"
  end
end
