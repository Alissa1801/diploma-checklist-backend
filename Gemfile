source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.1"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# ============== ДОБАВЛЕННЫЕ ГЕМЫ ДЛЯ ПРОЕКТА ==============

# Аутентификация
gem 'devise'
gem 'devise-jwt'
gem 'bcrypt', '~> 3.1.7'

# CORS для API
gem 'rack-cors'

# Сериализация JSON
gem 'active_model_serializers'

# Фоновые задачи
gem 'sidekiq'
gem 'redis'

# Работа с изображениями (УДАЛИЛИ ПОВТОР image_processing)
# gem "ruby-vips"
gem 'mini_magick', '~> 4.11'  # или измените на просто gem 'mini_magick'

# Документация API
gem 'rswag'

# ============== ДЛЯ РАЗРАБОТКИ ==============
group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  
  gem 'annotate'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry-rails'
  gem 'byebug'
end