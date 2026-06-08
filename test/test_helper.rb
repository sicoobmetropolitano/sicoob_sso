# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "risecode_sso"

require "minitest/autorun"

module ConfigSandbox
  def setup
    super
    RisecodeSso.reset_config!
  end

  def teardown
    super
    RisecodeSso.reset_config!
  end
end
