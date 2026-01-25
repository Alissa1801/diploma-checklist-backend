module CurrentRequest
  extend ActiveSupport::Concern
  
  included do
    before_action :set_current_request
  end
  
  def set_current_request
    Current.request_ip = request.remote_ip
    Current.user_agent = request.user_agent
  end
  
  class Current
    class_attribute :request_ip, :user_agent
  end
end
