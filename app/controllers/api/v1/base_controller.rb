module Api::V1
  class BaseController < ApplicationController
    before_action :authenticate_user_from_token!
    
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from JWT::DecodeError, with: :invalid_token
    
    attr_reader :current_user
    
    private
    
    def authenticate_user_from_token!
      token = request.headers['Authorization']&.split(' ')&.last
      
      if token.present?
        begin
          decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
          user_id = decoded[0]['id']
          @current_user = User.find(user_id)
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound => e
          render json: { error: 'Invalid token', details: e.message }, status: :unauthorized
        end
      else
        render json: { error: 'Token missing' }, status: :unauthorized
      end
    end
    
    def not_found
      render json: { error: 'Resource not found' }, status: :not_found
    end
    
    def invalid_token
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end
end
