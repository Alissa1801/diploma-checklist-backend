class User < ApplicationRecord
  has_secure_password
  
  has_many :checks, dependent: :destroy
  
  # Временно закомментируем enum
  # enum role: { cleaner: 0, supervisor: 1, admin: 2 }
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :password, length: { minimum: 6 }, allow_nil: true
  
  before_validation :downcase_email
  
  # Метод для генерации JWT токена
  def generate_jwt
    payload = { 
      id: id,
      email: email,
      exp: 24.hours.from_now.to_i 
    }
    
    secret = Rails.application.secret_key_base
    JWT.encode(payload, secret, 'HS256')
  end
  
  # Метод для проверки является ли пользователь администратором
  def admin?
    # Проверяем по email (пока что простой способ)
    email == 'admin@example.com'
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