# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Mapper
      def sicoob_sso_routes
        get    "/login",        to: "sicoob_sso/sessions#new",      as: :login
        post   "/login",        to: "sicoob_sso/sessions#create"
        get    "/sso/waiting",  to: "sicoob_sso/sessions#waiting",  as: :sso_waiting
        get    "/sso/poll",     to: "sicoob_sso/sessions#poll",     as: :sso_poll
        get    "/sso/callback", to: "sicoob_sso/sessions#callback"
        delete "/logout",       to: "sicoob_sso/sessions#destroy",  as: :logout
      end
    end
  end
end
