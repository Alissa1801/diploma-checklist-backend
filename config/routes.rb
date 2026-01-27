# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Аутентификация
      post 'auth/login', to: 'auth#login'
      post 'auth/refresh', to: 'auth#refresh'
      post 'auth/logout', to: 'auth#logout'
      
      # Зоны уборки
      resources :zones, only: [:index, :show]
      
      # Чек-листы
      resources :checks, only: [:index, :create, :show]
      
      # Анализ нейросети
      get 'analysis/:check_id', to: 'analysis#show'
      post 'analysis/:check_id/analyze', to: 'analysis#analyze'

      # Дашборд - убрали namespace, используем прямую ссылку
      get 'dashboard/stats', to: 'dashboard#stats'
      get 'dashboard/daily_stats', to: 'dashboard#daily_stats'
      get 'dashboard/user_stats', to: 'dashboard#user_stats'
      get 'dashboard/zone_stats', to: 'dashboard#zone_stats'
      get 'dashboard/personal_stats', to: 'dashboard#personal_stats'
    end
  end
  
  root to: proc { [200, {}, ['Checklist API is running']] }
end