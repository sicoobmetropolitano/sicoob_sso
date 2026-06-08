# RisecodeSso

Reusable client side of Risecode's in-house Single Sign-On. The identity provider
("Tools") exposes `GET /sso/authorize` and `POST /sso/token`; this gem authenticates
a host Rails app against it.

This is a plain gem — modules, a configuration object, and two controller concerns.
It is **not** a Rails engine: it ships no models, migrations, routes, or views. The
host app owns all of those.

## Installation

```ruby
gem "risecode_sso"
```

## What's in the box

| Component | Type | Responsibility |
|-----------|------|----------------|
| `RisecodeSso::Configuration` / `RisecodeSso.configure` | config | Provider URL, client credentials, redirect URI, user provisioner, login path |
| `RisecodeSso::IdentityProvider` | module function | `authorize_url(state:)` and `exchange_code(code)` against the IdP |
| `RisecodeSso::Authentication` | controller concern | `current_user`, `user_signed_in?`, `authenticate_user!`, `sign_in`, `sign_out`, `resume_session` (token cookie) |
| `RisecodeSso::SessionsControllerConcern` | controller concern | `new` / `callback` / `destroy` actions for the SSO login flow |

## Configuration

```ruby
# config/initializers/risecode_sso.rb
RisecodeSso.configure do |c|
  c.provider_url   = ENV.fetch("SSO_PROVIDER_URL")   # e.g. https://tools.example
  c.client_id      = ENV.fetch("SSO_CLIENT_ID")
  c.client_secret  = ENV.fetch("SSO_CLIENT_SECRET")
  c.redirect_uri   = ENV.fetch("SSO_REDIRECT_URI")   # e.g. https://app.example/sso/callback
  c.login_path     = "/login"                        # string, or a callable resolved in the controller
  c.provisioner    = ->(claims) { User.provision_from_sso(claims) }
end
```

Every setting falls back to an ENV default
(`SSO_PROVIDER_URL`, `SSO_CLIENT_ID`, `SSO_CLIENT_SECRET`, `SSO_REDIRECT_URI`), so the
initializer only needs to set what differs (typically just the `provisioner`).

`login_path` may be a string or a callable. A callable is evaluated in the controller
instance, so route helpers work: `c.login_path = -> { login_path }`.

## Host requirements

The gem references two host constants, resolved where the concerns are included:

### `Session` model

```ruby
class Session < ApplicationRecord
  belongs_to :user
  has_secure_token :token

  def active?         = # your freshness rule, e.g. last_active_at > 30.days.ago
  def touch_activity! = update_column(:last_active_at, Time.current)
end
```

Required surface: `Session.find_by(token:)`, instance `token`, `active?`,
`touch_activity!`, and `user.sessions.create!(user_agent:, ip_address:)`.

### `Current` (ActiveSupport::CurrentAttributes)

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user
end
```

### A user provisioner

A callable that takes the IdP's `"user"` claims hash and returns a host `User`
(find-or-create). Wired through `RisecodeSso.config.provisioner`.

### Routes

```ruby
get    "/login",        to: "sso/sessions#new"
get    "/sso/callback", to: "sso/sessions#callback"
delete "/logout",       to: "sso/sessions#destroy"
```

## Usage

Include the authentication concern in your base controller:

```ruby
class ApplicationController < ActionController::Base
  include RisecodeSso::Authentication
  before_action :authenticate_user!
end
```

Build the SSO sessions controller from the concern (it inherits the host's
`Authentication` helpers and view helpers via `ApplicationController`):

```ruby
class Sso::SessionsController < ApplicationController
  include RisecodeSso::SessionsControllerConcern
  skip_before_action :authenticate_user!, only: %i[new callback]
end
```

That's the whole integration:

- `new` generates a state nonce, stores it in the session, and redirects to the IdP.
- `callback` verifies the returned state, exchanges the code for user claims, runs the
  provisioner, signs the user in (httponly `:session_token` cookie), and redirects to
  the stored `return_to` (or `/`). An `RisecodeSso::ExchangeError` redirects back to
  the login path with an alert.
- `destroy` signs out and redirects to the login path.

## Errors

- `RisecodeSso::Error` — base error
- `RisecodeSso::ExchangeError` — raised by `IdentityProvider.exchange_code` on a non-2xx
  response from the IdP token endpoint

## Development

```bash
bundle install
bundle exec rake test
```

The `IdentityProvider` and `Configuration` are unit-tested in this gem. The two
controller concerns are integration-tested in the host application (they require a Rails
controller context, `Session`, and `Current`); the gem's suite only verifies they load
and expose the expected methods.

## License

MIT.
