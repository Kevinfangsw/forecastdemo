# Weather Forecast

A Ruby on Rails weather forecast application with an Apple Weather-inspired design. Enter any address, city, or zip/postal code to view current conditions and a 5-day extended forecast with real-time data.

## Features

- **Current conditions** — labeled "Current Temperature" display, feels-like, humidity, wind speed, and weather description with emoji icons
- **5-day extended forecast** — daily low/high temperatures, weather conditions, and precipitation probability with labeled column headers (Day, Rain, Condition, Low, High)
- **Unit toggle (°F / °C)** — switch between Fahrenheit/mph and Celsius/km/h with a single click; preference persists across sessions via localStorage
- **Address autocomplete** — type-ahead suggestions powered by Nominatim with coordinates passed via hidden fields to skip re-geocoding; supports keyboard navigation (arrow keys, Enter, Escape) and click selection
- **Canadian postal code support** — handles A1A 1A1 format postal codes (with or without space, any case) by extracting the 3-character Forward Sortation Area (FSA) and searching Nominatim with that
- **30-minute caching by postal code** — subsequent requests for the same postal code are served from cache, with a visual indicator distinguishing fresh vs. cached results
- **Reverse-geocode fallback** — city-level queries that lack a postal code automatically resolve via reverse geocoding
- **Apple Weather-inspired UI** — glass morphism cards, weather-contextual gradient backgrounds, system font stack, responsive typography
- **Clear labels** — "Current Temperature" label, "High" / "Low" labels, column headers on the 5-day forecast, condition descriptions visible alongside emoji icons, "Current Details" section header
- **Home navigation** — back link on the forecast page to return to the home search screen
- **Accessible** — semantic HTML, ARIA labels, screen-reader-only labels, `role="status"` for cache indicators, `role="listbox"` for autocomplete
- **No API keys required** — uses Open-Meteo (weather) and Nominatim/OpenStreetMap (geocoding), both free and keyless
- **No database** — fully stateless, service-based architecture

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Ruby 3.4.5, Rails 8.1 |
| Weather API | [Open-Meteo](https://open-meteo.com) (free, no key) |
| Geocoding | [Nominatim](https://nominatim.org) via `geocoder` gem (free, no key) |
| HTTP Client | `httparty` |
| CSS | Tailwind CSS v4 via `tailwindcss-rails` (standalone binary, no Node.js) |
| Frontend | Hotwire (Turbo Drive), Stimulus |
| Asset Pipeline | Propshaft, importmap-rails |
| Server | Puma |
| Caching | `Rails.cache` with `:memory_store` (30-min TTL by postal code) |

## Architecture

```
User types in search field
  → autocomplete_controller.js (Stimulus) debounces 300ms
    → GET /autocomplete?q=... → Nominatim suggestions → dropdown
  → User selects suggestion (or submits typed address)

  → ForecastsController#show
    → If lat/lon/postal_code params present (from autocomplete selection):
        → ForecastService.call_with_coordinates (skip geocoding)
    → Otherwise:
        → ForecastService.call(address)
          → GeocodingService (Nominatim) → postal_code + lat/lon
             (Canadian postal codes: extract FSA and retry if needed)
          → Check Rails.cache["forecast_v1/{postal_code}"]
            → HIT:  return cached data (cached=true, cached_at timestamp)
            → MISS: WeatherService (Open-Meteo) → cache 30 min → return fresh
    → Render show.html.erb with ForecastResult

  → unit_toggle_controller.js (Stimulus)
    → Reads data-temp-f / data-wind-mph attributes
    → Converts and updates all displayed values client-side
    → Persists preference in localStorage
```

### Key Design Decisions

- **Cache key is postal code** — all addresses within the same postal code share a single cache entry, reducing redundant API calls
- **`Rails.cache.read`/`write` instead of `.fetch`** — allows distinguishing cache hits from misses so the view can show the correct indicator
- **Service object pattern** — each service has a single responsibility: `GeocodingService` (address → coordinates), `WeatherService` (coordinates → weather), `ForecastService` (orchestration + caching)
- **PORO value objects** — `ForecastResult`, `CurrentWeather`, `DayForecast`, `WeatherCode` are plain Ruby objects with no framework dependencies
- **Client-side unit toggle** — temperatures stored as Fahrenheit in `data-temp-f` attributes; Stimulus converts on the fly without page reload
- **Coordinate pass-through** — autocomplete returns lat/lon/postal_code alongside display names; selecting a suggestion populates hidden form fields so the server skips re-geocoding entirely
- **Server-side autocomplete proxy** — `/autocomplete` proxies to Nominatim to maintain User-Agent header and avoid CORS issues

## Getting Started

### Prerequisites

- Ruby 3.4.5 (see `.ruby-version`)
- Bundler

### Setup

```bash
git clone <repo-url> && cd forecastdemo
bin/setup
```

This installs gems and prepares the environment. No database setup is needed.

### Run the App

```bash
bin/dev
```

This starts both the Rails server and the Tailwind CSS watcher via Foreman. Visit [http://localhost:3000](http://localhost:3000).

Alternatively, build CSS once and start the server directly:

```bash
bin/rails tailwindcss:build
bin/rails server
```

### Run Tests

```bash
bin/rails test
```

Runs the full test suite: 82 tests, 436 assertions. All tests use stubs for external API calls — no network access required.

### Linting and Security

```bash
bin/rubocop          # Ruby style checks (RuboCop + Rails Omakase)
bin/brakeman         # Static security analysis
bin/bundler-audit    # Gem vulnerability audit
bin/ci               # Runs all of the above + tests
```

## Project Structure

```
app/
  models/
    weather_code.rb          # WMO code → description, emoji, gradient mapping
    current_weather.rb       # Value object: current conditions
    day_forecast.rb          # Value object: single day forecast
    forecast_result.rb       # Value object: complete forecast + cache metadata
  services/
    geocoding_service.rb     # Address → {postal_code, lat, lon} via Nominatim
    weather_service.rb       # Lat/lon → weather data via Open-Meteo API
    forecast_service.rb      # Orchestrator: geocode → cache → fetch → result
  controllers/
    forecasts_controller.rb  # index + show + autocomplete actions
  helpers/
    forecasts_helper.rb      # gradient_class_for(), format_temperature()
  javascript/controllers/
    unit_toggle_controller.js   # °F/°C toggle with localStorage persistence
    autocomplete_controller.js  # Debounced address suggestions with keyboard nav
  views/
    forecasts/
      index.html.erb         # Search screen with autocomplete
      show.html.erb          # Weather display with unit toggle + labels
    layouts/
      application.html.erb   # Base layout with Apple system font stack
  assets/
    tailwind/
      application.css        # Tailwind v4 config with @source for model scanning

test/
  models/                    # WeatherCode mapping, ForecastResult defaults
  services/                  # Geocoding (incl. Canadian postal codes), Weather API, cache
  controllers/               # Routes, errors, network errors, XSS, autocomplete endpoint
  integration/               # Full user flows, unit toggle presence, autocomplete presence

config/
  initializers/
    geocoder.rb              # Nominatim config with User-Agent and 1-day cache
  routes.rb                  # root + GET /forecast + GET /autocomplete
```

## Caching Behavior

| Cache Layer | TTL | Key | Purpose |
|-------------|-----|-----|---------|
| Forecast data | 30 minutes | `forecast_v1/{postal_code}` | Avoid redundant weather API calls |
| Geocoding results | 1 day | `geocoder:{address}` | Avoid redundant geocoding lookups |

The cache indicator on the forecast page shows:
- **Green dot + "Just updated"** — fresh data from the API
- **Amber dot + "Cached result from [time]"** — served from cache

For single-server deployments, the default `:memory_store` works well. For multi-server production, switch to Redis or Memcached in `config/environments/production.rb`:

```ruby
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
```

## Error Handling

| Scenario | User Experience |
|----------|----------------|
| Blank/missing address | Redirect to home with "Please enter an address" |
| Address not found | Redirect with "Could not find location for '...'" |
| No postal code resolvable | Redirect with "Could not determine postal code... Try a more specific address" |
| Weather API error | Redirect with "Weather data unavailable: ..." |
| Network timeout / DNS failure | Redirect with "Unable to reach weather services. Please try again" |

All errors are shown as styled flash alerts on the search screen. No raw error pages are exposed to users.

## Testing

The test suite (82 tests, 436 assertions) covers:

- **Unit tests** — WeatherCode mappings, ForecastResult value object, nil defaults
- **Service tests** — Geocoding (reverse-geocode fallback, Canadian postal codes with/without space, lowercase, FSA extraction), Weather API parsing (WMO codes, nil data, unknown codes), ForecastService (cache hit/miss/expiry, zip-based sharing, coordinate pass-through, error propagation)
- **Controller tests** — All routes, error paths, network errors (timeout, DNS, connection refused), XSS prevention, coordinate pass-through (skip geocoding), autocomplete endpoint (valid query, short query, blank query, error handling, result limit, lat/lon/postal_code in response), edge cases (whitespace, missing params)
- **Integration tests** — Full user flows with labels, unit toggle data attributes, autocomplete presence on both pages, cache indicators, home navigation link, abbreviated day names, column ordering, accessibility checks

All external API calls are stubbed using a custom `StubHelper` module compatible with Minitest 6.

## Deployment

The app is ready for single-server deployment. Key production settings (`config/environments/production.rb`):

- SSL forced (`config.force_ssl = true`)
- Eager loading enabled
- Memory cache store (swap to Redis for multi-server)
- Thruster for HTTP caching/compression (`bin/thrust`)

```bash
RAILS_ENV=production bin/rails tailwindcss:build
RAILS_ENV=production bin/thrust bin/rails server
```

## License

This project is for demonstration purposes.
