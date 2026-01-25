class UserLog < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :action, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  
  # Сериализация JSON полей для Rails 8
  attribute :details, :json, default: {}
  
  def self.log(user, action, details = {})
    create!(
      user: user,
      action: action,
      details: details,
      ip_address: details[:ip_address] || 'unknown',
      user_agent: details[:user_agent] || 'unknown'
    )
  rescue => e
    Rails.logger.error("Failed to create UserLog: #{e.message}")
    nil
  end
end
