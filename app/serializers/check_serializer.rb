class CheckSerializer < ActiveModel::Serializer
  # Добавляем :zone в список атрибутов, чтобы оно попало в JSON
  attributes :id, :user_id, :zone_id, :room_number, :status, :score,
             :submitted_at, :created_at, :user_name, :status_text, :zone

  has_one :analysis_result

  # Указываем связь, чтобы подтянулись данные из таблицы zones
  belongs_to :zone

  def user_name
    object.user&.full_name || "Unknown"
  end

  def status_text
    object.status_text
  end

  def submitted_at
    object.submitted_at&.iso8601
  end
end
