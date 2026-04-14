# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "ostruct"

# Lightweight method stubbing for Minitest 6 (which removed Object#stub).
# Temporarily replaces a method on an object and restores it after the block.
module StubHelper
  def stub_method(object, method_name, value_or_callable)
    original = object.method(method_name)

    replacement = if value_or_callable.respond_to?(:call)
      value_or_callable
    else
      ->(*_args, **_kwargs) { value_or_callable }
    end

    object.define_singleton_method(method_name) do |*args, **kwargs|
      replacement.call(*args, **kwargs)
    end

    yield
  ensure
    object.define_singleton_method(method_name, original)
  end
end

# Shared factory methods for constructing test data.
# All helpers produce realistic-looking data matching the Open-Meteo API structure.
module WeatherTestHelper
  def build_mock_location(zip_code: "60601", latitude: 41.8781, longitude: -87.6298, address: "Chicago, Cook County, Illinois, 60601, United States")
    {
      zip_code: zip_code,
      latitude: latitude,
      longitude: longitude,
      formatted_address: address
    }
  end

  def build_mock_weather
    {
      current: CurrentWeather.new(
        temperature_f: 72.0,
        condition: "Partly Cloudy",
        icon: "⛅",
        humidity: 45,
        wind_mph: 8.5,
        feels_like_f: 70.0,
        weather_code: 2
      ),
      daily_forecast: [
        DayForecast.new(date: Date.today,     high_f: 78.0, low_f: 62.0, condition: "Partly Cloudy", icon: "⛅",  chance_of_rain: 10),
        DayForecast.new(date: Date.today + 1,  high_f: 75.0, low_f: 60.0, condition: "Mainly Clear",  icon: "🌤️", chance_of_rain: 5),
        DayForecast.new(date: Date.today + 2,  high_f: 80.0, low_f: 65.0, condition: "Clear Sky",     icon: "☀️",  chance_of_rain: 0)
      ]
    }
  end

  def build_mock_forecast_result(cached: false)
    weather = build_mock_weather
    ForecastResult.new(
      address: "Chicago, Cook County, Illinois, 60601, United States",
      zip_code: "60601",
      current: weather[:current],
      daily_forecast: weather[:daily_forecast],
      cached: cached,
      cached_at: Time.current
    )
  end

  def build_mock_open_meteo_response
    {
      "current" => {
        "temperature_2m" => 72.0,
        "relative_humidity_2m" => 45,
        "apparent_temperature" => 70.0,
        "weather_code" => 2,
        "wind_speed_10m" => 8.5
      },
      "daily" => {
        "time" => [ Date.today.to_s, (Date.today + 1).to_s, (Date.today + 2).to_s ],
        "weather_code" => [ 2, 1, 0 ],
        "temperature_2m_max" => [ 78.0, 75.0, 80.0 ],
        "temperature_2m_min" => [ 62.0, 60.0, 65.0 ],
        "precipitation_probability_max" => [ 10, 5, 0 ]
      }
    }
  end

  def stub_geocoder_result(postal_code: "60601", coordinates: [ 41.8781, -87.6298 ], address: "Chicago, Cook County, Illinois, 60601, United States")
    mock = OpenStruct.new(
      postal_code: postal_code,
      coordinates: coordinates,
      address: address,
      data: { "display_name" => address }
    )
    [ mock ]
  end

  # Builds a mock HTTParty response object with the essential interface.
  def mock_http_response(code, body)
    response = OpenStruct.new(
      code: code,
      success?: code == 200,
      parsed_response: body
    )
    response.define_singleton_method(:dig) { |*keys| body.dig(*keys) }
    response.define_singleton_method(:[]) { |key| body[key] }
    response
  end
end

module ActiveSupport
  class TestCase
    # Run tests in single process — our stub approach uses define_singleton_method
    # which is not thread-safe across parallel workers.
    parallelize(workers: 1)

    include WeatherTestHelper
    include StubHelper
  end
end
