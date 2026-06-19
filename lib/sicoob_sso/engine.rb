# frozen_string_literal: true

require "rails/engine"

module SicoobSso
  class Engine < ::Rails::Engine
    initializer "sicoob_sso.routes" do
      require_relative "routes"
    end
  end
end
