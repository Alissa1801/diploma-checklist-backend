class LoggingService
  class << self
    # Логирование действий пользователя
    def log_user_action(user, action, details = {})
      log_entry = {
        timestamp: Time.current,
        user_id: user.id,
        user_email: user.email,
        action: action,
        details: details
      }
      
      Rails.logger.info("[USER_ACTION] #{log_entry.to_json}")
      
      # Также сохраняем в базу для аналитики
      UserLog.log(user, action, details)
    rescue => e
      Rails.logger.error("Failed to log user action: #{e.message}")
    end
    
    # Логирование API запросов
    def log_api_request(request, response, user = nil)
      log_entry = {
        timestamp: Time.current,
        method: request.method,
        path: request.path,
        params: request.filtered_parameters,
        user_id: user&.id,
        user_email: user&.email,
        status: response.status,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
      
      Rails.logger.info("[API_REQUEST] #{log_entry.to_json}")
      
      # Сохраняем в базу для мониторинга
      ApiLog.log(request, response, user)
    rescue => e
      Rails.logger.error("Failed to log API request: #{e.message}")
    end
    
    # Логирование работы нейросети
    def log_ml_analysis(check, result, processing_time)
      log_entry = {
        timestamp: Time.current,
        check_id: check.id,
        zone_id: check.zone_id,
        user_id: check.user_id,
        ml_model_version: result[:ml_model_version],
        confidence_score: result[:confidence_score],
        is_approved: result[:is_approved],
        detected_objects: result[:detected_objects],
        issues: result[:issues],
        processing_time_ms: (processing_time * 1000).round(2),
        feedback: result[:feedback]
      }
      
      Rails.logger.info("[ML_ANALYSIS] #{log_entry.to_json}")
    rescue => e
      Rails.logger.error("Failed to log ML analysis: #{e.message}")
    end
    
    # Логирование ошибок
    def log_error(error, context = {})
      log_entry = {
        timestamp: Time.current,
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(5),
        context: context
      }
      
      Rails.logger.error("[ERROR] #{log_entry.to_json}")
      
      # Сохраняем серьезные ошибки в базу
      if error.is_a?(StandardError) && !error.is_a?(ActiveRecord::RecordNotFound)
        SystemError.create!(
          error_class: error.class.name,
          error_message: error.message,
          backtrace: error.backtrace&.join("\n"),
          context: context
        )
      end
    rescue => e
      Rails.logger.error("Failed to log error: #{e.message}")
    end
    
    # Логирование безопасности
    def log_security_event(event_type, details = {})
      log_entry = {
        timestamp: Time.current,
        event_type: event_type,
        details: details
      }
      
      Rails.logger.warn("[SECURITY] #{log_entry.to_json}")
      
      SecurityEvent.create!(
        event_type: event_type,
        details: details
      )
    rescue => e
      Rails.logger.error("Failed to log security event: #{e.message}")
    end
  end
end
