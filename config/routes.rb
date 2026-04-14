Rails.application.routes.draw do
  # Health check endpoint — returns 200 if the app boots without exceptions.
  # Used by load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # Home page with the address search form.
  root "forecasts#index"

  # Forecast results page — accepts address (and optional lat/lon/postal_code from autocomplete).
  get "forecast", to: "forecasts#show", as: :forecast

  # JSON autocomplete endpoint for address type-ahead suggestions.
  get "autocomplete", to: "forecasts#autocomplete", as: :autocomplete
end
