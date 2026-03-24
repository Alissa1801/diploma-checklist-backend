class AnalysisResult < ApplicationRecord
  belongs_to :check

  # Авто-заполнение версии модели перед валидацией,
  # чтобы запись не "падала" при сохранении результата от нейросети
  before_validation :set_default_model_version, on: :create

  # Сериализация JSON полей для Rails 8
  attribute :detected_objects, :json, default: []
  attribute :issues, :json, default: []

  # Валидации
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :ml_model_version, presence: true

  # Хелпер методы для URL
  def full_processed_url(base_url)
    return nil if processed_url.blank?
    "#{base_url}#{processed_url}"
  end

  # Логика статусов
  def approved?
    is_approved
  end

  def rejected?
    !is_approved
  end

  def status
    is_approved ? "approved" : "rejected"
  end

  def status_text
    is_approved ? "Одобрено" : "Отклонено"
  end

  # Текстовые представления данных
  def confidence_percentage
    confidence_score ? "#{confidence_score.round(1)}%" : "N/A"
  end

  def issue_list
    issues&.any? ? issues.join(", ") : "Проблем не обнаружено"
  end

  def detected_objects_summary
    if detected_objects&.any?
      detected_objects.map { |obj|
        if obj.is_a?(Hash)
          "#{obj["name"]} (#{obj["count"]})"
        else
          obj.to_s
        end
      }.join(", ")
    else
      "Объекты не найдены"
    end
  end

  private

  # Если версия модели не пришла из YoloService, ставим стандартную
  def set_default_model_version
    self.ml_model_version ||= "YOLOv8-production-v1"
  end
end
