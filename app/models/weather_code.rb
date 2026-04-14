# frozen_string_literal: true

# Maps WMO (World Meteorological Organization) weather interpretation codes
# to human-readable descriptions, emoji icons, and Tailwind CSS gradient classes.
#
# Reference: https://open-meteo.com/en/docs#weathervariables
# WMO Code Table 4677 defines standard weather condition codes used by
# meteorological services worldwide.
class WeatherCode
  CODES = {
    0  => { description: "Clear Sky",        emoji: "☀️",   gradient: "from-sky-400 via-blue-400 to-blue-500" },
    1  => { description: "Mainly Clear",     emoji: "🌤️",  gradient: "from-sky-400 via-blue-400 to-blue-500" },
    2  => { description: "Partly Cloudy",    emoji: "⛅",    gradient: "from-blue-400 via-blue-500 to-slate-400" },
    3  => { description: "Overcast",         emoji: "☁️",   gradient: "from-slate-400 via-slate-500 to-gray-500" },
    45 => { description: "Fog",              emoji: "🌫️",  gradient: "from-gray-400 via-gray-500 to-slate-500" },
    48 => { description: "Depositing Rime Fog", emoji: "🌫️", gradient: "from-gray-400 via-gray-500 to-slate-500" },
    51 => { description: "Light Drizzle",    emoji: "🌦️",  gradient: "from-blue-500 via-slate-500 to-gray-500" },
    53 => { description: "Moderate Drizzle", emoji: "🌦️",  gradient: "from-blue-500 via-slate-500 to-gray-500" },
    55 => { description: "Dense Drizzle",    emoji: "🌦️",  gradient: "from-slate-500 via-gray-600 to-gray-700" },
    61 => { description: "Slight Rain",      emoji: "🌧️",  gradient: "from-blue-600 via-slate-600 to-gray-600" },
    63 => { description: "Moderate Rain",    emoji: "🌧️",  gradient: "from-slate-600 via-gray-600 to-gray-700" },
    65 => { description: "Heavy Rain",       emoji: "🌧️",  gradient: "from-slate-700 via-gray-700 to-gray-800" },
    71 => { description: "Slight Snow",      emoji: "🌨️",  gradient: "from-blue-200 via-slate-300 to-gray-400" },
    73 => { description: "Moderate Snow",    emoji: "🌨️",  gradient: "from-blue-300 via-slate-400 to-gray-500" },
    75 => { description: "Heavy Snow",       emoji: "❄️",   gradient: "from-slate-300 via-gray-400 to-gray-500" },
    77 => { description: "Snow Grains",      emoji: "❄️",   gradient: "from-slate-300 via-gray-400 to-gray-500" },
    80 => { description: "Slight Showers",   emoji: "🌧️",  gradient: "from-blue-500 via-slate-500 to-gray-600" },
    81 => { description: "Moderate Showers", emoji: "🌧️",  gradient: "from-slate-600 via-gray-600 to-gray-700" },
    82 => { description: "Violent Showers",  emoji: "🌧️",  gradient: "from-slate-700 via-gray-700 to-gray-800" },
    85 => { description: "Slight Snow Showers", emoji: "🌨️", gradient: "from-blue-300 via-slate-400 to-gray-500" },
    86 => { description: "Heavy Snow Showers",  emoji: "❄️",  gradient: "from-slate-400 via-gray-500 to-gray-600" },
    95 => { description: "Thunderstorm",     emoji: "⛈️",   gradient: "from-gray-700 via-slate-800 to-gray-900" },
    96 => { description: "Thunderstorm with Slight Hail", emoji: "⛈️", gradient: "from-gray-700 via-slate-800 to-gray-900" },
    99 => { description: "Thunderstorm with Heavy Hail",  emoji: "⛈️", gradient: "from-gray-800 via-slate-900 to-gray-950" }
  }.each_value(&:freeze).freeze

  DEFAULT = { description: "Unknown", emoji: "🌡️", gradient: "from-blue-400 via-blue-500 to-blue-600" }.freeze

  # Returns the full info hash { description:, emoji:, gradient: } for a WMO code.
  def self.for(code)
    CODES.fetch(code, DEFAULT)
  end

  def self.description(code)
    self.for(code)[:description]
  end

  def self.emoji(code)
    self.for(code)[:emoji]
  end

  def self.gradient(code)
    self.for(code)[:gradient]
  end
end
