Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Аутентификация
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      
      # Зоны уборки
      resources :zones, only: [:index, :show]
      
      # Чек-листы
      resources :checks, only: [:index, :create, :show]
      
      # Дашборд (добавим позже)
      namespace :dashboard do
        get 'stats', to: 'dashboard#stats'
        get 'recent_checks', to: 'dashboard#recent_checks'
      end
    end
  end
  
  root to: proc { [200, {}, ['Checklist API is running']] }
end
