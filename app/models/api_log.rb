class ApiLog < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :method, :path, :status, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 200..299) }
  scope :failed, -> { where.not(status: 200..299) }
  
  # Сериализация JSON полей для Rails 8
  attribute :params, :json, default: {}
  
  def self.log(request, response, user = nil)
    create!(
      user: user,
      method: request.method,
      path: request.path,
      params: request.filtered_parameters,
      status: response.status,
      ip_address: request.remote_ip || 'unknown',
      user_agent: request.user_agent || 'unknown'
    )
  rescue => e
    Rails.logger.error("Failed to create ApiLog: #{e.message}")
    nil
  end
  
  def success?
    status >= 200 && status < 300
  end
end
