require_relative "boot"

require "rails"

# Only load the Rails frameworks this app actually uses.
# No database, background jobs, mailers, or real-time features needed.
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Forecastdemo
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    # System tests are not used — the app has no browser-level test dependency.
    config.generators.system_tests = nil
  end
end
