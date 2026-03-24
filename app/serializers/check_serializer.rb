class CheckSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :zone_id, :room_number, :status, :score, :submitted_at, :created_at, :user_name, :status_text

  # Это заставит Rails включить данные нейросети в ответ
  has_one :analysis_result

  def user_name
    object.user&.first_name || "Unknown"
  end

  def status_text
    object.status_text
  end

  def submitted_at
    object.submitted_at&.iso8601
  end
end
