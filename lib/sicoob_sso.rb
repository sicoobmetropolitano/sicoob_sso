# frozen_string_literal: true

require_relative "sicoob_sso/version"
require_relative "sicoob_sso/configuration"
require_relative "sicoob_sso/identity_provider"
require_relative "sicoob_sso/authentication"
require_relative "sicoob_sso/sessions_controller_concern"
require_relative "sicoob_sso/engine" if defined?(::Rails::Engine)

module SicoobSso
  class Error < StandardError; end
  class ExchangeError < Error; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def reset_config!
      @config = Configuration.new
    end
  end
end
