class CheckSerializer < ActiveModel::Serializer
  # УДАЛИЛИ :zone из списка атрибутов ниже
  attributes :id, :user_id, :zone_id, :room_number, :status, :score,
             :submitted_at, :created_at, :user_name, :status_text

  # Ассоциации (AMS сам подтянет ZoneSerializer, если он есть)
  has_one :analysis_result
  belongs_to :zone

  def user_name
    object.user&.full_name || "Unknown"
  end

  def status_text
    # Убедитесь, что в модели check.rb этот метод не приватный!
    object.status_text 
  end

  def submitted_at
    object.submitted_at&.iso8601
  end
end