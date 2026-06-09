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
    stub_post_form(success_response('{"user":{"email":"a@b.com","name":"A"}}')) do |captured|
      claims = SicoobSso::IdentityProvider.exchange_code("the-code")

      assert_equal({ "email" => "a@b.com", "name" => "A" }, claims)
      assert_equal URI("https://idp.test/sso/token"), captured[:uri]
      assert_equal "the-code", captured[:params][:code]
      assert_equal "myapp", captured[:params][:client_id]
      assert_equal "secret", captured[:params][:client_secret]
    end
  end

  def test_exchange_code_raises_on_non_success
    stub_post_form(failure_response) do
      error = assert_raises(SicoobSso::ExchangeError) do
        SicoobSso::IdentityProvider.exchange_code("bad-code")
      end

      assert_match(/401/, error.message)
    end
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

    def stub_post_form(response)
      captured = {}
      original = Net::HTTP.method(:post_form)
      verbose, $VERBOSE = $VERBOSE, nil
      Net::HTTP.singleton_class.send(:define_method, :post_form) do |uri, params|
        captured[:uri] = uri
        captured[:params] = params
        response
      end
      $VERBOSE = verbose
      yield captured
    ensure
      verbose, $VERBOSE = $VERBOSE, nil
      Net::HTTP.singleton_class.send(:define_method, :post_form, original)
      $VERBOSE = verbose
    end
end
