class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  
  before_action :authenticate_user!
  
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from JWT::DecodeError, with: :invalid_token
  rescue_from StandardError, with: :internal_server_error
  
  attr_reader :current_user
  
  private
  
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    if token
      begin
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
        user_id = decoded_token.first['id']
        @current_user = User.find_by(id: user_id)
        
        # Логируем успешную аутентификацию
        if @current_user && defined?(LoggingService)
          LoggingService.log_user_action(@current_user, 'api_authenticate', {
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          })
        end
      rescue JWT::DecodeError => e
        # Логируем ошибку аутентификации
        if defined?(LoggingService)
          LoggingService.log_security_event('invalid_token', { 
            error: e.message,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          })
        end
        @current_user = nil
      end
    end
    
    unless @current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
  
  def not_found(exception)
    if defined?(LoggingService)
      LoggingService.log_error(exception, { 
        params: params,
        current_user_id: @current_user&.id 
      })
    end
    render json: { error: 'Resource not found' }, status: :not_found
  end
  
  def invalid_token(exception)
    if defined?(LoggingService)
      LoggingService.log_security_event('invalid_token', { 
        error: exception.message,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      })
    end
    render json: { error: 'Invalid token' }, status: :unauthorized
  end
  
  def internal_server_error(exception)
    if defined?(LoggingService)
      LoggingService.log_error(exception, { 
        params: params,
        current_user_id: @current_user&.id,
        backtrace: exception.backtrace&.first(5)
      })
    end
    Rails.logger.error("Internal Server Error: #{exception.message}")
    Rails.logger.error(exception.backtrace&.join("\n"))
    
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end
end
