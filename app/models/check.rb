class Check < ApplicationRecord
  # --- Ассоциации ---
  belongs_to :user
  belongs_to :zone
  has_one :analysis_result, dependent: :destroy

  # Связь для загрузки фото (Active Storage)
  has_one_attached :photo

  # --- Валидации ---
  validates :zone_id, presence: true
  validate :validate_photo # Раскомментировано для обеспечения целостности данных

  # --- Публичные методы для API и Сериализаторов ---
  # Эти методы должны быть ВЫШЕ private, чтобы Serializer мог их вызвать

  def user_name
    user&.full_name || "Unknown User"
  end

  def status_text
    case status
    when 0 then "pending"
    when 1 then "processing"
    when 2 then "approved"
    when 3 then "rejected"
    when 4 then "needs_correction"
    else "unknown"
    end
  end

  def pending?
    status == 0
  end

  def processing_time
    return nil unless completed_at && submitted_at
    (completed_at - submitted_at).round(2)
  end

  # Методы изменения состояния
  def approve!(feedback = nil, score = 100.0)
    update!(
      status: 2, # approved
      completed_at: Time.current,
      feedback: feedback,
      score: score
    )
  end

  def reject!(feedback, score = 0.0)
    update!(
      status: 3, # rejected
      completed_at: Time.current,
      feedback: feedback,
      score: score
    )
  end

  # --- Методы статистики (Класс) ---
  
  def self.today_count
    where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count
  end

  def self.this_week_count
    where(created_at: 1.week.ago..Time.current).count
  end

  def self.approval_rate
    total = count
    return 0 if total.zero?
    (where(status: 2).count.to_f / total * 100).round(2)
  end

  def self.average_processing_time
    processed = where(status: [ 2, 3 ]).where.not(submitted_at: nil, completed_at: nil)
    return 0 if processed.empty?

    times = processed.map { |c| c.completed_at - c.submitted_at }
    (times.sum / times.count).round(2)
  end

  # --- Приватные методы (внутренняя логика) ---
  private

  def validate_photo
    return unless photo.attached?

    # Проверяем тип файла
    allowed_types = %w[image/jpeg image/jpg image/png image/heic image/heif]
    unless photo.blob.content_type.downcase.in?(allowed_types)
      errors.add(:photo, "должно быть JPEG, PNG или HEIC")
    end

    # Проверяем размер (5MB максимум)
    if photo.blob.byte_size > 5.megabytes
      errors.add(:photo, "должно быть меньше 5MB")
    end
  end
end