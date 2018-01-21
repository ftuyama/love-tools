Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  controller 'home' do
    get '/alive/' => :alive
  end

  root 'home#index'
end
