# frozen_string_literal: true

# Handles forecast lookup, display, and address autocomplete.
#
# Actions:
#   index       — renders the home page with the search form
#   show        — geocodes the address (or uses provided coordinates), fetches weather, and renders results
#   autocomplete — returns JSON address suggestions for the type-ahead dropdown
#
# Error handling:
#   - GeocodingError      → redirect with geocoding-specific message
#   - WeatherApiError     → redirect with "Weather data unavailable" message
#   - Network errors      → redirect with generic connectivity message
class ForecastsController < ApplicationController
  # GET / — Home page with the address search form.
  def index
  end

  # GET /forecast?address=...&lat=...&lon=...&postal_code=...
  #
  # When the user selects an autocomplete suggestion, lat/lon/postal_code are
  # passed as hidden fields so we can skip re-geocoding the display name.
  # When the user types a free-form address and submits, only `address` is present,
  # and we fall through to GeocodingService.
  def show
    address = params[:address]

    if address.blank?
      redirect_to root_path, alert: "Please enter an address."
      return
    end

    if coordinates_provided?
      @latitude = params[:lat].to_f
      @longitude = params[:lon].to_f
      @postal_code = params[:postal_code]
    else
      location = GeocodingService.call(address)
      @latitude = location[:latitude]
      @longitude = location[:longitude]
      @postal_code = location[:zip_code]
    end

    @forecast = ForecastService.call_with_coordinates(
      address: address,
      latitude: @latitude,
      longitude: @longitude,
      postal_code: @postal_code
    )
    @address_query = address
  rescue GeocodingService::GeocodingError => e
    redirect_to root_path, alert: e.message
  rescue WeatherService::WeatherApiError => e
    redirect_to root_path, alert: "Weather data unavailable: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError,
         Errno::EHOSTUNREACH, Errno::ENETUNREACH => e
    Rails.logger.error("[ForecastsController] Network error: #{e.class} - #{e.message}")
    redirect_to root_path, alert: "Unable to reach weather services. Please try again in a moment."
  end

  # GET /autocomplete?q=...
  #
  # Returns up to 5 JSON suggestions from Nominatim. Each suggestion includes
  # display_name, lat, lon, and postal_code so the client can pass coordinates
  # directly on form submit (avoiding a second geocoding round-trip).
  def autocomplete
    query = params[:q].to_s.strip
    render json: [] and return if query.length < 3

    results = Geocoder.search(query)
    suggestions = results.first(5).map do |result|
      {
        display_name: result.data["display_name"] || result.address,
        lat: result.coordinates[0],
        lon: result.coordinates[1],
        postal_code: result.postal_code
      }
    end
    render json: suggestions
  rescue StandardError => e
    Rails.logger.warn("[Autocomplete] Error: #{e.class} - #{e.message}")
    render json: []
  end

  private

  # Returns true when the autocomplete hidden fields provide full coordinate data,
  # allowing us to skip the geocoding step entirely.
  def coordinates_provided?
    params[:lat].present? && params[:lon].present? && params[:postal_code].present?
  end
end
