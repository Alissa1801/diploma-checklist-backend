class SecurityEvent < ApplicationRecord
  validates :event_type, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  
  # Сериализация JSON полей для Rails 8
  attribute :details, :json, default: {}
  
  def self.log(event_type, details = {})
    create!(
      event_type: event_type,
      details: details,
      ip_address: details[:ip_address] || 'unknown',
      user_agent: details[:user_agent] || 'unknown'
    )
  rescue => e
    Rails.logger.error("Failed to create SecurityEvent: #{e.message}")
    nil
  end
  
  EVENT_TYPES = [
    'failed_login',
    'suspicious_activity',
    'brute_force_attempt',
    'unauthorized_access',
    'token_theft',
    'rate_limit_exceeded',
    'invalid_token',
    'unauthorized_dashboard_access'
  ].freeze
end
