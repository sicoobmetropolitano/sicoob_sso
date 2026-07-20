# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module SicoobSso
  module IdentityProvider
    module_function

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    def authorize_url(state:)
      query = URI.encode_www_form(
        client_id: SicoobSso.config.client_id,
        redirect_uri: SicoobSso.config.redirect_uri,
        state: state
      )
      "#{SicoobSso.config.provider_url}/sso/authorize?#{query}"
    end

    def exchange_code(code)
      post_json("/sso/token",
        code: code,
        client_id: SicoobSso.config.client_id,
        client_secret: SicoobSso.config.client_secret).fetch("user")
    end

    def authenticate_password(email:, password:)
      post_json("/sso/password",
        email: email,
        password: password,
        client_id: SicoobSso.config.client_id,
        client_secret: SicoobSso.config.client_secret).fetch("user")
    end

    def create_auth_request(email:)
      post_json("/sso/auth_requests",
        email: email,
        client_id: SicoobSso.config.client_id,
        client_secret: SicoobSso.config.client_secret).fetch("request_id")
    end

    def poll_auth_request(request_id:)
      get_json("/sso/auth_requests/#{request_id}")
    end

    def post_json(path, params)
      request(Net::HTTP::Post, path) { |req| req.set_form_data(params) }
    end

    def get_json(path)
      request(Net::HTTP::Get, path)
    end

    def request(verb, path)
      uri = URI("#{SicoobSso.config.provider_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      req = verb.new(uri)
      yield req if block_given?

      response = http.request(req)
      unless response.is_a?(Net::HTTPSuccess)
        raise ExchangeError, "SSO request to #{path} failed: #{response.code}"
      end

      JSON.parse(response.body)
    end
  end
end
