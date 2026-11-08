# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resource :dashboard, only: :show, controller: :dashboard

  resources :cases do
    collection do
      get :compare
    end
  end

  get "/events/import", to: "events#import_events"
  resources :events

  resources :check_lists

  get "/transports/import", to: "transports#import_transports"
  resources :transports

  resources :organisations do
    collection do
      post :from_url
    end
    member do
      get :image
    end
  end

  resources :products do
    collection do
      post :from_url
    end
    member do
      get :image
    end
  end

  get "/items/export", to: "items#export"
  resources :items do
    member do
      get :clone
    end

    resources :comments, controller: :item_comments
  end

  resources :item_types
  resources :case_types

  post "/graphql", to: "graphql#execute"

  namespace :api do
    namespace :v1 do
      resources :items, only: %i[index show]
      resources :products, only: %i[index show]
      resources :check_lists, only: %i[index show]
      resources :organisations, only: %i[index show]
    end
  end

  root to: "root#show"
end
