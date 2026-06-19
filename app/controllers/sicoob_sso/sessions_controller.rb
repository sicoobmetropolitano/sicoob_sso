# frozen_string_literal: true

module SicoobSso
  class SessionsController < ::ApplicationController
    include SicoobSso::SessionsControllerConcern

    skip_before_action :authenticate_user!, only: %i[new create waiting poll callback], raise: false
  end
end
