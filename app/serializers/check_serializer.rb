class CheckSerializer < ActiveModel::Serializer
  # Список полей, которые улетят в JSON на iPhone
  attributes :id,
             :user_id,
             :zone_id,
             :room_number,
             :status,
             :score,
             :submitted_at,
             :created_at,
             :user_name,
             :status_text

  # 1. Включаем вложенные объекты.
  # Это позволит iOS увидеть check.zone.name и check.analysis_result
  has_one :analysis_result
  belongs_to :zone

  # 2. Метод для получения имени пользователя (если оно нужно в списке)
  def user_name
    # Используем safe navigation (&.), чтобы не упасть, если пользователь удален
    object.user&.full_name || "Неизвестный"
  end

  # 3. Берем текстовый статус прямо из модели Check
  def status_text
    object.status_text
  end

  # 4. Форматируем дату в стандарт ISO8601 для Swift
  def submitted_at
    object.submitted_at&.iso8601
  end

  def created_at
    object.created_at&.iso8601
  end
end
