# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "sicoob_sso"

require "minitest/autorun"

module ConfigSandbox
  def setup
    super
    SicoobSso.reset_config!
  end

  def teardown
    super
    SicoobSso.reset_config!
  end
end
