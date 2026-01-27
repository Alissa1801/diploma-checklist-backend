class User < ApplicationRecord
  has_secure_password
  
  has_many :checks, dependent: :destroy
  
 
  enum :role, { cleaner: 0, supervisor: 1, admin: 2 }, default: :cleaner
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :password, length: { minimum: 6 }, allow_nil: true
  
  before_validation :downcase_email
  
  # Метод для генерации JWT access токена (24 часа)
  def generate_jwt
    payload = { 
      id: id,
      email: email,
      exp: 24.hours.from_now.to_i 
    }
    
    secret = Rails.application.secret_key_base
    JWT.encode(payload, secret, 'HS256')
  end
  
  # Метод для генерации JWT refresh токена (7 дней) - ДОБАВЬТЕ ЭТОТ МЕТОД
  def generate_refresh_token
    payload = { 
      id: id,
      exp: 7.days.from_now.to_i 
    }
    
    secret = Rails.application.secret_key_base
    refresh_token = JWT.encode(payload, secret, 'HS256')
    
    # Сохраняем refresh token в базе
    update(
      refresh_token: refresh_token,
      refresh_token_expires_at: 7.days.from_now
    )
    
    refresh_token
  end
  
  # Метод для проверки валидности refresh токена - ДОБАВЬТЕ ЭТОТ МЕТОД
  def valid_refresh_token?(token)
    return false unless refresh_token.present?
    return false unless refresh_token_expires_at.present?
    return false unless refresh_token_expires_at > Time.current
    
    # Сравниваем токены
    refresh_token == token
  end
  
  # Метод для очистки refresh токена - ДОБАВЬТЕ ЭТОТ МЕТОД
  def clear_refresh_token
    update(
      refresh_token: nil,
      refresh_token_expires_at: nil
    )
  end
  
  # Метод для проверки является ли пользователь администратором
  def admin?
    role == 'admin' || email == 'admin@example.com'
  end
  
  def role_name
    role || 'cleaner'
  end

  # Метод для получения полного имени
  def full_name
    "#{first_name} #{last_name}"
  end

  private
  
  def downcase_email
    self.email = email.downcase if email.present?
  end
end