# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  include ConfigSandbox

  def test_defaults
    config = RisecodeSso::Configuration.new

    assert_equal "http://localhost:3000", config.provider_url
    assert_equal "", config.client_id
    assert_equal "", config.client_secret
    assert_equal "http://localhost:3000/sso/callback", config.redirect_uri
    assert_nil config.provisioner
    assert_equal "/login", config.login_path
  end

  def test_reads_from_env
    with_env("SSO_PROVIDER_URL" => "https://tools.example",
             "SSO_CLIENT_ID" => "myapp",
             "SSO_CLIENT_SECRET" => "shh",
             "SSO_REDIRECT_URI" => "https://app.example/sso/callback") do
      config = RisecodeSso::Configuration.new

      assert_equal "https://tools.example", config.provider_url
      assert_equal "myapp", config.client_id
      assert_equal "shh", config.client_secret
      assert_equal "https://app.example/sso/callback", config.redirect_uri
    end
  end

  def test_configure_overrides
    provisioner = ->(claims) { claims }

    RisecodeSso.configure do |c|
      c.provider_url = "https://idp.test"
      c.client_id = "client"
      c.provisioner = provisioner
      c.login_path = "/sign_in"
    end

    assert_equal "https://idp.test", RisecodeSso.config.provider_url
    assert_equal "client", RisecodeSso.config.client_id
    assert_same provisioner, RisecodeSso.config.provisioner
    assert_equal "/sign_in", RisecodeSso.config.login_path
  end

  private
    def with_env(values)
      previous = values.keys.to_h { |k| [k, ENV[k]] }
      values.each { |k, v| ENV[k] = v }
      yield
    ensure
      previous.each { |k, v| ENV[k] = v }
    end
end
