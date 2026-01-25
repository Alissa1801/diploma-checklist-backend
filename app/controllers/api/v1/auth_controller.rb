module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login]
      
      def login
        user = User.find_by(email: params[:email])
        
        if user&.authenticate(params[:password])
          token = encode_token({ id: user.id, email: user.email })
          
          # Логируем успешный вход
          LoggingService.log_user_action(user, 'login_success')
          
          render json: {
            success: true,
            token: token,
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name
            }
          }
        else
          # Логируем неудачную попытку входа
          LoggingService.log_security_event('failed_login', { 
            email: params[:email],
            ip_address: request.remote_ip 
          })
          
          render json: { 
            success: false, 
            error: 'Invalid email or password' 
          }, status: :unauthorized
        end
      end
      
      def logout
        # Логируем выход пользователя
        LoggingService.log_user_action(current_user, 'logout')
        
        render json: { success: true, message: 'Logged out successfully' }
      end
      
      private
      
      def encode_token(payload)
        expiration = 24.hours.from_now.to_i
        payload[:exp] = expiration
        JWT.encode(payload, Rails.application.credentials.secret_key_base)
      end
    end
  end
end
