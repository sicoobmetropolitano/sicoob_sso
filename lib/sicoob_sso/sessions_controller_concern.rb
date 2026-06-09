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
      state = SecureRandom.hex(16)
      session[:sso_state] = state
      redirect_to IdentityProvider.authorize_url(state: state), allow_other_host: true
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
