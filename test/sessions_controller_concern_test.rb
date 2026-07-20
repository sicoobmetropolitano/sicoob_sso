# frozen_string_literal: true

# Harness approach: full ActionController::TestCase against a dummy controller
# that includes SicoobSso::SessionsControllerConcern. sign_in is stubbed on the
# dummy (the gem's real sign_in needs host Session/Current models), and
# SicoobSso::IdentityProvider is stubbed per-test. A standalone RouteSet provides
# the login/waiting/poll helpers the concern references. This exercises the real
# state check and poll dispatch end-to-end without a host Rails app.

require "test_helper"
require "action_controller"
require "action_controller/test_case"
require "action_dispatch"

CONCERN_TEST_ROUTES = ActionDispatch::Routing::RouteSet.new
CONCERN_TEST_ROUTES.draw do
  get    "/login",       to: "sso_dummy#new",     as: :login
  post   "/login",       to: "sso_dummy#create"
  get    "/sso/waiting", to: "sso_dummy#waiting",  as: :sso_waiting
  get    "/sso/poll",    to: "sso_dummy#poll",     as: :sso_poll
  get    "/sso/callback", to: "sso_dummy#callback"
end

class SsoDummyController < ActionController::Base
  include CONCERN_TEST_ROUTES.url_helpers
  include SicoobSso::SessionsControllerConcern

  attr_reader :signed_in_user

  def sign_in(user)
    @signed_in_user = user
  end

  def user_signed_in?
    false
  end
end

class SessionsControllerConcernTest < ActionController::TestCase
  include ConfigSandbox

  tests SsoDummyController

  def setup
    super
    @routes = CONCERN_TEST_ROUTES
    SicoobSso.configure do |c|
      c.provider_url = "https://idp.test"
      c.client_id = "myapp"
      c.client_secret = "secret"
      c.login_path = "/login"
      c.provisioner = ->(claims) { provisioned_users << claims; "user:#{claims["email"]}" }
    end
  end

  # --- new --------------------------------------------------------------------

  def test_new_redirects_an_already_signed_in_user_to_root
    @controller.stub(:user_signed_in?, true) do
      get :new

      assert_redirected_to "/"
    end
  end

  # --- callback / state check -------------------------------------------------

  def test_callback_rejects_mismatched_state
    stub_idp do |calls|
      get :callback, params: { state: "wrong", code: "the-code" }, session: { sso_state: "right" }

      assert_redirected_to "/login"
      assert_empty calls[:exchange_code]
      assert_nil @controller.signed_in_user
    end
  end

  def test_callback_rejects_blank_state
    stub_idp do |calls|
      get :callback, params: { code: "the-code" }, session: { sso_state: "right" }

      assert_redirected_to "/login"
      assert_empty calls[:exchange_code]
      assert_nil @controller.signed_in_user
    end
  end

  def test_callback_with_matching_state_signs_in_and_redirects
    stub_idp(exchange_code: { "email" => "a@b.com" }) do |calls|
      get :callback,
        params: { state: "right", code: "the-code" },
        session: { sso_state: "right", return_to: "/dashboard" }

      assert_equal ["the-code"], calls[:exchange_code]
      assert_equal [{ "email" => "a@b.com" }], provisioned_users
      assert_equal "user:a@b.com", @controller.signed_in_user
      assert_redirected_to "/dashboard"
    end
  end

  def test_callback_defaults_redirect_to_root
    stub_idp(exchange_code: { "email" => "a@b.com" }) do
      get :callback, params: { state: "right", code: "the-code" }, session: { sso_state: "right" }

      assert_redirected_to "/"
    end
  end

  # --- proxy strategy ---------------------------------------------------------

  def test_create_with_proxy_authenticates_signs_in_and_redirects
    SicoobSso.config.auth_strategy = :proxy
    stub_password("email" => "a@b.com") do |calls|
      post :create, params: { email: "a@b.com", password: "pw" }, session: { return_to: "/painel" }

      assert_equal [{ email: "a@b.com", password: "pw" }], calls[:authenticate_password]
      assert_equal [{ "email" => "a@b.com" }], provisioned_users
      assert_equal "user:a@b.com", @controller.signed_in_user
      assert_redirected_to "/painel"
    end
  end

  def test_create_with_proxy_redirects_to_login_on_invalid_credentials
    SicoobSso.config.auth_strategy = :proxy
    SicoobSso::IdentityProvider.stub(:authenticate_password, ->(email:, password:) { raise SicoobSso::ExchangeError }) do
      post :create, params: { email: "a@b.com", password: "bad" }

      assert_redirected_to "/login"
      assert_nil @controller.signed_in_user
    end
  end

  def test_create_without_proxy_uses_push_approval
    stub_idp_push(create_auth_request: "req-42") do |calls|
      post :create, params: { email: "a@b.com" }

      assert_equal ["a@b.com"], calls[:create_auth_request]
      assert_redirected_to "/sso/waiting"
    end
  end

  # --- poll dispatch ----------------------------------------------------------

  def test_poll_without_request_id_renders_expired
    stub_idp do |calls|
      get :poll

      assert_equal({ "status" => "expired" }, response.parsed_body)
      assert_empty calls[:poll_auth_request]
    end
  end

  def test_poll_pending_renders_pending_without_sign_in
    stub_idp(poll_auth_request: { "status" => "pending" }) do
      get :poll, session: { sso_request_id: "req-1" }

      assert_equal({ "status" => "pending" }, response.parsed_body)
      assert_nil @controller.signed_in_user
    end
  end

  def test_poll_approved_exchanges_signs_in_and_renders_redirect
    stub_idp(poll_auth_request: { "status" => "approved", "code" => "the-code" },
             exchange_code: { "email" => "a@b.com" }) do |calls|
      get :poll, session: { sso_request_id: "req-1", return_to: "/home" }

      assert_equal ["the-code"], calls[:exchange_code]
      assert_equal "user:a@b.com", @controller.signed_in_user
      assert_equal({ "status" => "approved", "redirect_to" => "/home" }, response.parsed_body)
    end
  end

  private
    def provisioned_users
      @provisioned_users ||= []
    end

    def stub_password(claims)
      calls = { authenticate_password: [] }
      SicoobSso::IdentityProvider.stub(:authenticate_password, ->(email:, password:) {
        calls[:authenticate_password] << { email: email, password: password }
        claims
      }) do
        yield calls
      end
    end

    def stub_idp_push(create_auth_request:)
      calls = { create_auth_request: [] }
      SicoobSso::IdentityProvider.stub(:create_auth_request, ->(email:) {
        calls[:create_auth_request] << email
        create_auth_request
      }) do
        yield calls
      end
    end

    # Stubs the IdentityProvider module functions and records the args each was
    # called with. exchange_code/poll_auth_request return the supplied values.
    def stub_idp(exchange_code: nil, poll_auth_request: nil)
      calls = { exchange_code: [], poll_auth_request: [] }
      idp = SicoobSso::IdentityProvider

      idp.stub(:exchange_code, ->(code) { calls[:exchange_code] << code; exchange_code }) do
        idp.stub(:poll_auth_request, ->(request_id:) { calls[:poll_auth_request] << request_id; poll_auth_request }) do
          yield calls
        end
      end
    end
end
