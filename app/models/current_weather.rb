# frozen_string_literal: true

# Value object representing current weather conditions at a location.
# Constructed by WeatherService from Open-Meteo API response data.
class CurrentWeather
  attr_reader :temperature_f, :condition, :icon, :humidity,
              :wind_mph, :feels_like_f, :weather_code

  def initialize(temperature_f:, condition:, icon:, humidity:, wind_mph:, feels_like_f:, weather_code:)
    @temperature_f = temperature_f
    @condition = condition
    @icon = icon
    @humidity = humidity
    @wind_mph = wind_mph
    @feels_like_f = feels_like_f
    @weather_code = weather_code
  end
end
