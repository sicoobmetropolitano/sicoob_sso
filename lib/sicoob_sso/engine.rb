# frozen_string_literal: true

require "rails/engine"

module SicoobSso
  class Engine < ::Rails::Engine
    initializer "sicoob_sso.routes" do
      require_relative "routes"
    end

    initializer "sicoob_sso.authentication" do
      ActiveSupport.on_load(:action_controller_base) do
        include SicoobSso::Authentication
      end
    end
  end
end
