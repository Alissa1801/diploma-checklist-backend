class Zone < ApplicationRecord
  # Валидации
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  
  # Связь с проверками
  has_many :checks
  
  # Стандартные значения
  attribute :standard_items_count, :integer, default: 0
  attribute :standard_objects, :json, default: []
  attribute :checklist_points, :json, default: []
  
  # Метод для получения текстового описания стандартных объектов
  def standard_objects_summary
    return "No standard objects" if standard_objects.blank?
    
    standard_objects.map do |obj|
      if obj.is_a?(Hash)
        "#{obj['name']} (#{obj['count']})"
      else
        obj.to_s
      end
    end.join(', ')
  end
  
  # Метод для получения количества пунктов чек-листа
  def checklist_points_count
    checklist_points&.count || 0
  end
end