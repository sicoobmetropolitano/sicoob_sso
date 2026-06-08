# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module RisecodeSso
  module IdentityProvider
    module_function

    def authorize_url(state:)
      query = URI.encode_www_form(
        client_id: RisecodeSso.config.client_id,
        redirect_uri: RisecodeSso.config.redirect_uri,
        state: state
      )
      "#{RisecodeSso.config.provider_url}/sso/authorize?#{query}"
    end

    def exchange_code(code)
      response = Net::HTTP.post_form(
        URI("#{RisecodeSso.config.provider_url}/sso/token"),
        code: code,
        client_id: RisecodeSso.config.client_id,
        client_secret: RisecodeSso.config.client_secret
      )

      unless response.is_a?(Net::HTTPSuccess)
        raise ExchangeError, "SSO token exchange failed: #{response.code}"
      end

      JSON.parse(response.body).fetch("user")
    end
  end
end
