module Api::V1
  class AuthController < ApplicationController
    skip_before_action :authenticate_user_from_token!, only: [:login]
    
    def login
      user = User.find_by(email: params[:email]&.downcase)
      
      if user && user.authenticate(params[:password])
        token = user.generate_jwt
        
        render json: {
          success: true,
          token: token,
          user: {
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role,
            phone: user.phone
          }
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'Invalid email or password'
        }, status: :unauthorized
      end
    end
    
    def logout
      render json: { 
        success: true, 
        message: 'Logged out successfully' 
      }
    end
  end
end
