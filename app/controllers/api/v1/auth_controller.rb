module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login, :refresh]
      
      def login
        user = User.find_by(email: params[:email])
        
        if user&.authenticate(params[:password])
          # Генерируем access token
          access_token = user.generate_jwt
          
          # Генерируем refresh token
          refresh_token = user.generate_refresh_token
          
          # Логируем успешный вход
          LoggingService.log_user_action(user, 'login_success')
          
          render json: {
            success: true,
            token: access_token,
            refresh_token: refresh_token,
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name,
              admin: user.admin?
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
      
      def refresh
        refresh_token = params[:refresh_token]
        
        unless refresh_token
          return render json: { success: false, error: 'Refresh token required' }, status: :bad_request
        end
        
        begin
          # Декодируем refresh token
          decoded = decode_token(refresh_token)
          user_id = decoded[:id]
          
          # Находим пользователя
          user = User.find_by(id: user_id)
          
          # Проверяем валидность refresh token
          unless user&.valid_refresh_token?(refresh_token)
            return render json: { success: false, error: 'Invalid or expired refresh token' }, status: :unauthorized
          end
          
          # Генерируем новый access token
          new_access_token = user.generate_jwt
          
          # Можно обновить refresh token (опционально)
          # new_refresh_token = user.generate_refresh_token
          
          render json: {
            success: true,
            token: new_access_token,
            # refresh_token: new_refresh_token,
            message: 'Token refreshed successfully'
          }
          
        rescue JWT::DecodeError, JWT::ExpiredSignature
          render json: { success: false, error: 'Invalid token' }, status: :unauthorized
        rescue ActiveRecord::RecordNotFound
          render json: { success: false, error: 'User not found' }, status: :unauthorized
        end
      end
      
      def logout
        # Очищаем refresh token при выходе
        current_user.clear_refresh_token if current_user
        
        # Логируем выход пользователя
        LoggingService.log_user_action(current_user, 'logout')
        
        render json: { success: true, message: 'Logged out successfully' }
      end
      
      private
      
      def decode_token(token)
        decoded = JWT.decode(token, Rails.application.secret_key_base)[0]
        HashWithIndifferentAccess.new(decoded)
      end
    end
  end
end