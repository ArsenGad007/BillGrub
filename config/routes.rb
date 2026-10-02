Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
  get "likes",   to: "pages#likes"
  get "history", to: "pages#history"

  # Эти маршруты пока закомментированы: контроллеров BillsController и
  # BookmarksController в проекте ещё нет, и при заходе на них был бы
  # NameError (uninitialized constant). Раскомментируйте после создания.
  # resources :bills, only: [:show] do
  #   resources :bookmarks, only: [:create, :destroy]
  # end
end
