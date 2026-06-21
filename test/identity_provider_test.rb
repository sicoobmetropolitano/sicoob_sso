# frozen_string_literal: true

require "test_helper"
require "uri"

class IdentityProviderTest < Minitest::Test
  include ConfigSandbox

  def setup
    super
    SicoobSso.configure do |c|
      c.provider_url = "https://idp.test"
      c.client_id = "myapp"
      c.client_secret = "secret"
      c.redirect_uri = "https://app.test/sso/callback"
    end
  end

  def test_authorize_url
    url = SicoobSso::IdentityProvider.authorize_url(state: "abc123")
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query).to_h

    assert_equal "https", uri.scheme
    assert_equal "idp.test", uri.host
    assert_equal "/sso/authorize", uri.path
    assert_equal "myapp", params["client_id"]
    assert_equal "https://app.test/sso/callback", params["redirect_uri"]
    assert_equal "abc123", params["state"]
  end

  def test_exchange_code_returns_user_claims_on_success
    stub_request(success_response('{"user":{"email":"a@b.com","name":"A"}}')) do |captured|
      claims = SicoobSso::IdentityProvider.exchange_code("the-code")

      assert_equal({ "email" => "a@b.com", "name" => "A" }, claims)
      assert_equal "/sso/token", captured[:request].uri.path
      assert_kind_of Net::HTTP::Post, captured[:request]
      assert_equal "the-code", captured[:form]["code"]
      assert_equal "myapp", captured[:form]["client_id"]
      assert_equal "secret", captured[:form]["client_secret"]
    end
  end

  def test_exchange_code_raises_on_non_success
    stub_request(failure_response) do
      error = assert_raises(SicoobSso::ExchangeError) do
        SicoobSso::IdentityProvider.exchange_code("bad-code")
      end

      assert_match(/401/, error.message)
    end
  end

  def test_create_auth_request_returns_request_id
    stub_request(success_response('{"request_id":"tok-123"}')) do |captured|
      request_id = SicoobSso::IdentityProvider.create_auth_request(email: "user@example.com")

      assert_equal "tok-123", request_id
      assert_equal "/sso/auth_requests", captured[:request].uri.path
      assert_kind_of Net::HTTP::Post, captured[:request]
      assert_equal "user@example.com", captured[:form]["email"]
      assert_equal "myapp", captured[:form]["client_id"]
      assert_equal "secret", captured[:form]["client_secret"]
    end
  end

  def test_create_auth_request_raises_on_non_success
    stub_request(failure_response) do
      error = assert_raises(SicoobSso::ExchangeError) do
        SicoobSso::IdentityProvider.create_auth_request(email: "user@example.com")
      end

      assert_match(/401/, error.message)
    end
  end

  def test_poll_auth_request_returns_parsed_hash
    body = '{"status":"approved","code":"the-code"}'
    stub_request(success_response(body)) do |captured|
      result = SicoobSso::IdentityProvider.poll_auth_request(request_id: "tok-123")

      assert_equal({ "status" => "approved", "code" => "the-code" }, result)
      assert_equal "/sso/auth_requests/tok-123", captured[:request].uri.path
      assert_kind_of Net::HTTP::Get, captured[:request]
    end
  end

  def test_poll_auth_request_raises_on_non_success
    stub_request(failure_response) do
      error = assert_raises(SicoobSso::ExchangeError) do
        SicoobSso::IdentityProvider.poll_auth_request(request_id: "tok-123")
      end

      assert_match(/401/, error.message)
    end
  end

  def test_request_enables_tls_for_https_and_sets_timeouts
    captured = {}
    original = Net::HTTP.instance_method(:request)
    verbose, $VERBOSE = $VERBOSE, nil
    Net::HTTP.send(:define_method, :request) do |req|
      captured[:use_ssl] = use_ssl?
      captured[:open_timeout] = open_timeout
      captured[:read_timeout] = read_timeout
      res = Net::HTTPOK.new("1.1", "200", "OK")
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, '{"status":"pending"}')
      res
    end
    $VERBOSE = verbose

    SicoobSso::IdentityProvider.poll_auth_request(request_id: "tok-123")

    assert_equal true, captured[:use_ssl]
    assert_equal SicoobSso::IdentityProvider::OPEN_TIMEOUT, captured[:open_timeout]
    assert_equal SicoobSso::IdentityProvider::READ_TIMEOUT, captured[:read_timeout]
  ensure
    verbose, $VERBOSE = $VERBOSE, nil
    Net::HTTP.send(:define_method, :request, original)
    $VERBOSE = verbose
  end

  private
    def success_response(body)
      res = Net::HTTPOK.new("1.1", "200", "OK")
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, body)
      res
    end

    def failure_response
      res = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, "{}")
      res
    end

    # Stubs Net::HTTP#request, capturing the outgoing request object and the
    # form-encoded body (when present) so the new private helper path is exercised
    # end-to-end without real network access.
    def stub_request(response)
      captured = {}
      original = Net::HTTP.instance_method(:request)
      verbose, $VERBOSE = $VERBOSE, nil
      Net::HTTP.send(:define_method, :request) do |req|
        captured[:request] = req
        captured[:form] = URI.decode_www_form(req.body).to_h if req.body
        response
      end
      $VERBOSE = verbose
      yield captured
    ensure
      verbose, $VERBOSE = $VERBOSE, nil
      Net::HTTP.send(:define_method, :request, original)
      $VERBOSE = verbose
    end
end
