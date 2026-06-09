# frozen_string_literal: true

require "test_helper"

class LoadingTest < Minitest::Test
  def test_modules_are_defined
    assert defined?(SicoobSso::Authentication)
    assert defined?(SicoobSso::SessionsControllerConcern)
    assert defined?(SicoobSso::IdentityProvider)
    assert defined?(SicoobSso::Configuration)
    assert defined?(SicoobSso::Error)
    assert defined?(SicoobSso::ExchangeError)
  end

  def test_authentication_exposes_expected_instance_methods
    %i[authenticate_user! current_user user_signed_in? sign_in sign_out resume_session].each do |m|
      assert_includes SicoobSso::Authentication.instance_methods(true), m
    end
  end

  def test_sessions_controller_concern_exposes_actions
    %i[new callback destroy].each do |m|
      assert_includes SicoobSso::SessionsControllerConcern.instance_methods(true), m
    end
  end

  def test_login_path_for_resolves_callable
    SicoobSso.configure { |c| c.login_path = -> { "/dynamic" } }
    assert_equal "/dynamic", SicoobSso.login_path_for(Object.new)
  ensure
    SicoobSso.reset_config!
  end

  def test_login_path_for_returns_string
    SicoobSso.configure { |c| c.login_path = "/static" }
    assert_equal "/static", SicoobSso.login_path_for(Object.new)
  ensure
    SicoobSso.reset_config!
  end
end
