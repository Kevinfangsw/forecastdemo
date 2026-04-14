# frozen_string_literal: true

# Orchestrates the full forecast workflow: geocode → cache check → fetch → cache store.
#
# Two entry points:
#   call(address)                   — geocodes the address first, then fetches weather
#   call_with_coordinates(...)      — skips geocoding when coordinates are already known
#                                     (e.g. from an autocomplete selection)
#
# Caching strategy:
#   - Cache key is based on postal code (e.g. "forecast_v1/60601" or "forecast_v1/V6P")
#   - TTL is 30 minutes per the requirements
#   - Uses Rails.cache.read/write (not .fetch) so we can distinguish cache hits from misses
#     and pass the `cached` flag + `cached_at` timestamp to the view layer
class ForecastService
  CACHE_EXPIRY = 30.minutes
  CACHE_PREFIX = "forecast_v1"

  # Standard flow: geocode the address, then fetch weather.
  def self.call(address)
    new.call_with_address(address)
  end

  # Skip geocoding when coordinates are already known (e.g. from autocomplete).
  # The caller is responsible for providing valid latitude, longitude, and postal_code.
  def self.call_with_coordinates(address:, latitude:, longitude:, postal_code:)
    location = {
      zip_code: postal_code,
      latitude: latitude,
      longitude: longitude,
      formatted_address: address
    }
    new.fetch_weather(location)
  end

  # Geocode the address, then look up weather (with caching).
  def call_with_address(address)
    location = GeocodingService.call(address)
    fetch_weather(location)
  end

  # Check the cache for this postal code. On a miss, call the weather API,
  # store the result, and return it. On a hit, return cached data with metadata.
  def fetch_weather(location)
    zip_code = location[:zip_code]
    cache_key = "#{CACHE_PREFIX}/#{zip_code}"

    cached_data = Rails.cache.read(cache_key)

    if cached_data
      build_result(location, cached_data[:weather], zip_code, cached: true, cached_at: cached_data[:fetched_at])
    else
      weather = WeatherService.call(latitude: location[:latitude], longitude: location[:longitude])
      fetched_at = Time.current
      Rails.cache.write(cache_key, { weather: weather, fetched_at: fetched_at }, expires_in: CACHE_EXPIRY)
      build_result(location, weather, zip_code, cached: false, cached_at: fetched_at)
    end
  end

  private

  # Assembles a ForecastResult value object for the view layer.
  def build_result(location, weather, zip_code, cached:, cached_at:)
    ForecastResult.new(
      address: location[:formatted_address],
      zip_code: zip_code,
      current: weather[:current],
      daily_forecast: weather[:daily_forecast],
      cached: cached,
      cached_at: cached_at
    )
  end
end
