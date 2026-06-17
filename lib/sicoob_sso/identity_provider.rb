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

    def create_auth_request(email:)
      response = Net::HTTP.post_form(
        URI("#{SicoobSso.config.provider_url}/sso/auth_requests"),
        email: email,
        client_id: SicoobSso.config.client_id,
        client_secret: SicoobSso.config.client_secret
      )

      unless response.is_a?(Net::HTTPSuccess)
        raise ExchangeError, "SSO auth_request failed: #{response.code}"
      end

      JSON.parse(response.body).fetch("request_id")
    end

    def poll_auth_request(request_id:)
      uri = URI("#{SicoobSso.config.provider_url}/sso/auth_requests/#{request_id}")
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        raise ExchangeError, "SSO poll failed: #{response.code}"
      end

      JSON.parse(response.body)
    end
  end
end
