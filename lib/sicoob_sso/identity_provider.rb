# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module SicoobSso
  module IdentityProvider
    module_function

    def authorize_url(state:)
      query = URI.encode_www_form(
        client_id: SicoobSso.config.client_id,
        redirect_uri: SicoobSso.config.redirect_uri,
        state: state
      )
      "#{SicoobSso.config.provider_url}/sso/authorize?#{query}"
    end

    def exchange_code(code)
      response = Net::HTTP.post_form(
        URI("#{SicoobSso.config.provider_url}/sso/token"),
        code: code,
        client_id: SicoobSso.config.client_id,
        client_secret: SicoobSso.config.client_secret
      )

      unless response.is_a?(Net::HTTPSuccess)
        raise ExchangeError, "SSO token exchange failed: #{response.code}"
      end

      JSON.parse(response.body).fetch("user")
    end
  end
end
