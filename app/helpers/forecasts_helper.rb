# frozen_string_literal: true

module ForecastsHelper
  # Returns the Tailwind gradient classes for a given WMO weather code.
  # Used to set the page background based on current conditions.
  def gradient_class_for(weather_code)
    WeatherCode.gradient(weather_code)
  end

  # Formats a temperature value for display, rounding to the nearest integer.
  # Returns "--" if the value is nil (defensive against missing API data).
  def format_temperature(temp)
    temp ? temp.round.to_s : "--"
  end
end
