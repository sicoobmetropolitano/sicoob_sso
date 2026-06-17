# frozen_string_literal: true

module SicoobSso
  class Configuration
    attr_accessor :provider_url, :client_id, :client_secret, :redirect_uri,
                  :provisioner, :login_path, :auth_strategy

    def initialize
      @provider_url = ENV.fetch("SSO_PROVIDER_URL", "http://localhost:3000")
      @client_id = ENV.fetch("SSO_CLIENT_ID", "")
      @client_secret = ENV.fetch("SSO_CLIENT_SECRET", "")
      @redirect_uri = ENV.fetch("SSO_REDIRECT_URI", "http://localhost:3000/sso/callback")
      @provisioner = nil
      @login_path = "/login"
      @auth_strategy = ENV.fetch("SSO_AUTH_STRATEGY", "redirect").to_sym
    end
  end
end
