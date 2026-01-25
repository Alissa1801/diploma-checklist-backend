class AnalysisResult < ApplicationRecord
  belongs_to :check
  
  # Сериализация JSON полей для Rails 8
  attribute :detected_objects, :json, default: []
  attribute :issues, :json, default: []
  
  # Валидации
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :ml_model_version, presence: true
  
  # Хелпер методы
  def approved?
    is_approved
  end
  
  def rejected?
    !is_approved
  end
  
  def confidence_percentage
    confidence_score ? "#{confidence_score}%" : "N/A"
  end
  
  def issue_list
    issues&.join(', ') || 'No issues'
  end
  
  def detected_objects_summary
    if detected_objects&.any?
      detected_objects.map { |obj| 
        if obj.is_a?(Hash)
          "#{obj['name']} (#{obj['count']})"
        else
          obj.to_s
        end
      }.join(', ')
    else
      'No objects detected'
    end
  end
  
  # Добавьте методы для совместимости с контроллером dashboard
  def status
    is_approved ? 'approved' : 'rejected'
  end
  
  def status_text
    is_approved ? 'Approved' : 'Rejected'
  end
end
