# frozen_string_literal: true

begin
  require "active_support/concern"
rescue LoadError
  nil
end

module SicoobSso
  module Authentication
    extend ActiveSupport::Concern if defined?(ActiveSupport::Concern)

    if defined?(ActiveSupport::Concern)
      included do
        helper_method :current_user, :user_signed_in?
      end
    end

    def authenticate_user!
      return if user_signed_in?
      session[:return_to] = request.fullpath if request.get?
      redirect_to SicoobSso.login_path_for(self), alert: "Faça login para continuar."
    end

    def current_user
      Current.user ||= resume_session&.user
    end

    def user_signed_in?
      current_user.present?
    end

    def sign_in(user)
      record = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      cookies[:session_token] = { value: record.token, httponly: true, same_site: :lax }
      Current.session = record
      Current.user = user
      record
    end

    def sign_out
      resume_session&.destroy
      cookies.delete(:session_token)
      Current.session = nil
      Current.user = nil
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    private
      def find_session_by_cookie
        token = cookies[:session_token]
        return unless token

        record = Session.find_by(token: token)
        return unless record&.active?

        record.touch_activity!
        record
      end
  end

  def self.login_path_for(controller)
    path = config.login_path
    path.respond_to?(:call) ? controller.instance_exec(&path) : path
  end
end
