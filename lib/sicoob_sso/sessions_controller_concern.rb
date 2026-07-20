# frozen_string_literal: true

require "securerandom"

begin
  require "active_support/concern"
rescue LoadError
  nil
end

module SicoobSso
  module SessionsControllerConcern
    extend ActiveSupport::Concern if defined?(ActiveSupport::Concern)

    def new
      return redirect_to("/") if user_signed_in?
      return if renders_login_form?

      flash.delete(:alert)
      state = SecureRandom.hex(16)
      session[:sso_state] = state
      redirect_to IdentityProvider.authorize_url(state: state), allow_other_host: true
    end

    def create
      return create_with_password if SicoobSso.config.auth_strategy == :proxy

      request_id = IdentityProvider.create_auth_request(email: params[:email].to_s)
      session[:sso_request_id] = request_id
      redirect_to sso_waiting_path
    rescue SicoobSso::ExchangeError
      redirect_to SicoobSso.login_path_for(self), alert: "Não foi possível iniciar o login. Tente novamente."
    end

    def waiting
      redirect_to SicoobSso.login_path_for(self) if session[:sso_request_id].blank?
    end

    # JSON contract consumed by waiting.html.erb's poller:
    #   { status: "pending" | "approved" | "denied" | "expired", code? }
    # "approved" additionally carries redirect_to. Changing these strings is a
    # breaking change to the server<->client coupling.
    #
    # Safe as a GET: it acts only on the pending request bound to the current
    # server-side session (session[:sso_request_id]), never on a client param.
    def poll
      request_id = session[:sso_request_id]
      return render(json: { status: "expired" }) if request_id.blank?

      result = IdentityProvider.poll_auth_request(request_id: request_id)

      if result["status"] == "approved"
        claims = IdentityProvider.exchange_code(result["code"])
        session.delete(:sso_request_id)
        render json: { status: "approved", redirect_to: sso_sign_in(claims) }
      else
        render json: { status: result["status"] }
      end
    rescue SicoobSso::ExchangeError
      render json: { status: "error" }
    end

    def callback
      expected_state = session.delete(:sso_state)
      unless params[:state].present? && params[:state] == expected_state
        return redirect_to SicoobSso.login_path_for(self),
                           alert: "Sessão de login inválida. Tente novamente."
      end

      claims = IdentityProvider.exchange_code(params[:code].to_s)
      redirect_to sso_sign_in(claims)
    rescue SicoobSso::ExchangeError
      redirect_to SicoobSso.login_path_for(self),
                  alert: "Falha ao autenticar com o provedor. Tente novamente."
    end

    def destroy
      sign_out
      redirect_to SicoobSso.login_path_for(self), status: :see_other
    end

    private
      def create_with_password
        claims = IdentityProvider.authenticate_password(email: params[:email].to_s, password: params[:password].to_s)
        redirect_to sso_sign_in(claims)
      rescue SicoobSso::ExchangeError
        redirect_to SicoobSso.login_path_for(self), alert: "E-mail ou senha inválidos."
      end

      def renders_login_form?
        strategy = SicoobSso.config.auth_strategy
        strategy == :push_approval || strategy == :proxy
      end

      def sso_sign_in(claims)
        sign_in(SicoobSso.config.provisioner.call(claims))
        session.delete(:return_to) || "/"
      end
  end
end
