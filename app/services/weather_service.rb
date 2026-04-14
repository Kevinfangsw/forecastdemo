# frozen_string_literal: true

# Fetches weather data from the Open-Meteo API (https://open-meteo.com).
# No API key required. Returns current conditions and a multi-day forecast.
#
# Open-Meteo uses WMO weather interpretation codes (mapped by WeatherCode).
# API docs: https://open-meteo.com/en/docs
class WeatherService
  class WeatherApiError < StandardError; end

  BASE_URL = "https://api.open-meteo.com/v1/forecast"
  FORECAST_DAYS = 5

  # Current weather fields requested from Open-Meteo
  CURRENT_PARAMS = "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"

  # Daily forecast fields requested from Open-Meteo
  DAILY_PARAMS = "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"

  def self.call(latitude:, longitude:)
    new(latitude: latitude, longitude: longitude).call
  end

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  def call
    response = fetch_forecast
    validate_response!(response)
    parse_response(response)
  end

  private

  def fetch_forecast
    HTTParty.get(BASE_URL, {
      query: {
        latitude: @latitude,
        longitude: @longitude,
        current: CURRENT_PARAMS,
        daily: DAILY_PARAMS,
        temperature_unit: "fahrenheit",
        wind_speed_unit: "mph",
        forecast_days: FORECAST_DAYS,
        timezone: "auto"
      },
      timeout: 10 # seconds — Open-Meteo can be slow under load
    })
  end

  def validate_response!(response)
    return if response.success?

    error_message = response.dig("reason") || "Weather service error (HTTP #{response.code})"
    raise WeatherApiError, error_message
  end

  def parse_response(response)
    current = build_current_weather(response["current"])
    raise WeatherApiError, "Weather data unavailable — no current conditions returned" if current.nil?

    {
      current: current,
      daily_forecast: build_daily_forecast(response["daily"])
    }
  end

  def build_current_weather(data)
    return nil if data.nil?

    # Fetch the full WMO code entry once to avoid repeated hash lookups
    code = data["weather_code"].to_i
    weather_info = WeatherCode.for(code)

    CurrentWeather.new(
      temperature_f: data["temperature_2m"],
      condition: weather_info[:description],
      icon: weather_info[:emoji],
      humidity: data["relative_humidity_2m"],
      wind_mph: data["wind_speed_10m"],
      feels_like_f: data["apparent_temperature"],
      weather_code: code
    )
  end

  def build_daily_forecast(data)
    return [] if data.nil? || data["time"].nil?

    dates = data["time"]
    dates.each_index.map do |i|
      # Fetch the full WMO code entry once per day
      code = data.dig("weather_code", i).to_i
      weather_info = WeatherCode.for(code)

      DayForecast.new(
        date: parse_date(dates[i]),
        high_f: data.dig("temperature_2m_max", i),
        low_f: data.dig("temperature_2m_min", i),
        condition: weather_info[:description],
        icon: weather_info[:emoji],
        chance_of_rain: data.dig("precipitation_probability_max", i) || 0
      )
    end
  end

  # Safely parse a date string, falling back to today if malformed.
  def parse_date(date_str)
    Date.parse(date_str.to_s)
  rescue Date::Error
    Date.current
  end
end
