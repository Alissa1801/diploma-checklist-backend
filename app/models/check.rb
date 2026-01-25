class Check < ApplicationRecord
  belongs_to :user
  belongs_to :zone
  
  # Связь для загрузки фото
  has_many_attached :photos
  
  # Валидации
  validates :zone_id, presence: true
 # validate :validate_photos
  
  # Простые методы для статуса
  def status_text
    case status
    when 0 then 'pending'
    when 1 then 'processing'
    when 2 then 'approved'
    when 3 then 'rejected'
    when 4 then 'needs_correction'
    else 'unknown'
    end
  end
  
  def pending?
    status == 0
  end
  
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
  
  private
  
  def validate_photos
    if photos.attached?
      # Проверяем количество фото (например, от 1 до 3)
      if photos.length > 3
        errors.add(:photos, "не может быть больше 3 фотографий")
      end
      
      # Проверяем тип файла
      photos.each do |photo|
        unless photo.content_type.in?(%w(image/jpeg image/png image/jpg))
          errors.add(:photos, "должны быть JPEG или PNG")
        end
        
        if photo.blob.byte_size > 5.megabytes
          errors.add(:photos, "каждое фото должно быть меньше 5MB")
        end
      end
    else
      errors.add(:photos, "не может быть пустым")
    end
  end
end