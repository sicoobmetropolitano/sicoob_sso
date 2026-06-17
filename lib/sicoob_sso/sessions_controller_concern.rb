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
      return if SicoobSso.config.auth_strategy == :push_approval

      state = SecureRandom.hex(16)
      session[:sso_state] = state
      redirect_to IdentityProvider.authorize_url(state: state), allow_other_host: true
    end

    def create
      request_id = IdentityProvider.create_auth_request(email: params[:email].to_s)
      session[:sso_request_id] = request_id
      redirect_to sso_waiting_path
    rescue SicoobSso::ExchangeError
      redirect_to SicoobSso.login_path_for(self), alert: "Não foi possível iniciar o login. Tente novamente."
    end

    def waiting
      redirect_to SicoobSso.login_path_for(self) if session[:sso_request_id].blank?
    end

    def status
      request_id = session[:sso_request_id]
      return render(json: { status: "expired" }) if request_id.blank?

      result = IdentityProvider.poll_auth_request(request_id: request_id)

      if result["status"] == "approved"
        claims = IdentityProvider.exchange_code(result["code"])
        sign_in(SicoobSso.config.provisioner.call(claims))
        session.delete(:sso_request_id)
        render json: { status: "approved", redirect_to: (session.delete(:return_to) || "/") }
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
      user = SicoobSso.config.provisioner.call(claims)
      sign_in(user)
      redirect_to(session.delete(:return_to) || "/")
    rescue SicoobSso::ExchangeError
      redirect_to SicoobSso.login_path_for(self),
                  alert: "Falha ao autenticar com o provedor. Tente novamente."
    end

    def destroy
      sign_out
      redirect_to SicoobSso.login_path_for(self), status: :see_other
    end
  end
end
