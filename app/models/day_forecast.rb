# frozen_string_literal: true

# Value object representing a single day's forecast.
# Constructed by WeatherService from Open-Meteo daily forecast arrays.
class DayForecast
  attr_reader :date, :high_f, :low_f, :condition, :icon, :chance_of_rain

  def initialize(date:, high_f:, low_f:, condition:, icon:, chance_of_rain:)
    @date = date
    @high_f = high_f
    @low_f = low_f
    @condition = condition
    @icon = icon
    @chance_of_rain = chance_of_rain
  end
end
