# frozen_string_literal: true

Rubyn::Engine.routes.draw do
  root to: "dashboard#index"

  resources :files, only: [:index]
  resource :agent, only: %i[show create], controller: "agent"
  resource :refactor, only: %i[show create update], controller: "refactor"
  resource :specs, only: %i[show create], controller: "specs"
  resource :reviews, only: %i[show create], controller: "reviews"
  resource :settings, only: %i[show update], controller: "settings"
  post "feedback", to: "feedback#create"
end
