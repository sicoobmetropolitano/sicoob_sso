# frozen_string_literal: true

require "test_helper"

class LoadingTest < Minitest::Test
  def test_modules_are_defined
    assert defined?(RisecodeSso::Authentication)
    assert defined?(RisecodeSso::SessionsControllerConcern)
    assert defined?(RisecodeSso::IdentityProvider)
    assert defined?(RisecodeSso::Configuration)
    assert defined?(RisecodeSso::Error)
    assert defined?(RisecodeSso::ExchangeError)
  end

  def test_authentication_exposes_expected_instance_methods
    %i[authenticate_user! current_user user_signed_in? sign_in sign_out resume_session].each do |m|
      assert_includes RisecodeSso::Authentication.instance_methods(true), m
    end
  end

  def test_sessions_controller_concern_exposes_actions
    %i[new callback destroy].each do |m|
      assert_includes RisecodeSso::SessionsControllerConcern.instance_methods(true), m
    end
  end

  def test_login_path_for_resolves_callable
    RisecodeSso.configure { |c| c.login_path = -> { "/dynamic" } }
    assert_equal "/dynamic", RisecodeSso.login_path_for(Object.new)
  ensure
    RisecodeSso.reset_config!
  end

  def test_login_path_for_returns_string
    RisecodeSso.configure { |c| c.login_path = "/static" }
    assert_equal "/static", RisecodeSso.login_path_for(Object.new)
  ensure
    RisecodeSso.reset_config!
  end
end
