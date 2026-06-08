# frozen_string_literal: true

require_relative "risecode_sso/version"
require_relative "risecode_sso/configuration"
require_relative "risecode_sso/identity_provider"
require_relative "risecode_sso/authentication"
require_relative "risecode_sso/sessions_controller_concern"

module RisecodeSso
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
