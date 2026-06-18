# SicoobSso

Reusable client side of Sicoob's in-house Single Sign-On. The identity provider
("Tools") authenticates users; this gem authenticates a host Rails app against it.

This is a plain gem — modules, a configuration object, and two controller concerns.
It is **not** a Rails engine: it ships no models, migrations, routes, or views. The
host app owns all of those.

The gem supports two login strategies, selected per host:

- **`:redirect`** (default) — classic OAuth-style redirect. The host sends the user to
  the IdP (`GET /sso/authorize`), the user authenticates there, and the IdP redirects
  back with a code the host exchanges (`POST /sso/token`).
- **`:push_approval`** — passwordless on the host. The user enters only their e-mail;
  the IdP shows an approval request in its in-app notification center; once the user
  approves, the host exchanges the result for claims. Use this when the user can reach
  the IdP to approve (e.g. internal web apps).

## Installation

```ruby
gem "sicoob_sso", git: "https://github.com/sicoobmetropolitano/sicoob_sso.git"
```

## What's in the box

| Component | Type | Responsibility |
|-----------|------|----------------|
| `SicoobSso::Configuration` / `SicoobSso.configure` | config | Provider URL, client credentials, redirect URI, user provisioner, login path, **auth strategy** |
| `SicoobSso::IdentityProvider` | module function | `authorize_url(state:)`, `exchange_code(code)` (redirect); `create_auth_request(email:)`, `poll_auth_request(request_id:)` (push-approval) |
| `SicoobSso::Authentication` | controller concern | `current_user`, `user_signed_in?`, `authenticate_user!`, `sign_in`, `sign_out`, `resume_session` (token cookie) |
| `SicoobSso::SessionsControllerConcern` | controller concern | login actions: `new` / `callback` / `destroy` (redirect) and `new` / `create` / `waiting` / `status` / `destroy` (push-approval) |

## Configuration

```ruby
# config/initializers/sicoob_sso.rb
SicoobSso.configure do |c|
  c.provider_url   = ENV.fetch("SSO_PROVIDER_URL")   # e.g. https://tools.example
  c.client_id      = ENV.fetch("SSO_CLIENT_ID")
  c.client_secret  = ENV.fetch("SSO_CLIENT_SECRET")
  c.redirect_uri   = ENV.fetch("SSO_REDIRECT_URI")   # redirect strategy only
  c.login_path     = "/login"                        # string, or a callable resolved in the controller
  c.auth_strategy  = :push_approval                  # :redirect (default) | :push_approval
  c.provisioner    = ->(claims) { User.provision_from_sso(claims) }
end
```

Every setting falls back to an ENV default
(`SSO_PROVIDER_URL`, `SSO_CLIENT_ID`, `SSO_CLIENT_SECRET`, `SSO_REDIRECT_URI`,
`SSO_AUTH_STRATEGY`), so the initializer only needs to set what differs (typically the
`provisioner` and, for push-approval hosts, `auth_strategy`).

`login_path` may be a string or a callable. A callable is evaluated in the controller
instance, so route helpers work: `c.login_path = -> { login_path }`.

## Host requirements (both strategies)

The gem references two host constants, resolved where the concerns are included.

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
(find-or-create). Wired through `SicoobSso.config.provisioner`.

### Base controller

```ruby
class ApplicationController < ActionController::Base
  include SicoobSso::Authentication
  before_action :authenticate_user!
end
```

## Strategy: `:redirect`

### Routes

```ruby
get    "/login",        to: "sso/sessions#new"
get    "/sso/callback", to: "sso/sessions#callback"
delete "/logout",       to: "sso/sessions#destroy"
```

### Sessions controller

```ruby
class Sso::SessionsController < ApplicationController
  include SicoobSso::SessionsControllerConcern
  skip_before_action :authenticate_user!, only: %i[new callback]
end
```

- `new` generates a state nonce, stores it in the session, and redirects to the IdP.
- `callback` verifies the returned state, exchanges the code for user claims, runs the
  provisioner, signs the user in (httponly `:session_token` cookie), and redirects to
  the stored `return_to` (or `/`).
- `destroy` signs out.

No views are needed — `new` redirects immediately.

## Strategy: `:push_approval`

The user enters their e-mail on the host; the host opens a request at the IdP and polls
until the user approves it in the IdP's notification center.

### Routes

```ruby
get    "/login",       to: "sso/sessions#new"      # renders the e-mail form
post   "/login",       to: "sso/sessions#create"   # opens the auth request
get    "/sso/waiting", to: "sso/sessions#waiting", as: :sso_waiting
get    "/sso/status",  to: "sso/sessions#status",  as: :sso_status
delete "/logout",      to: "sso/sessions#destroy"
```

### Sessions controller

```ruby
class Sso::SessionsController < ApplicationController
  include SicoobSso::SessionsControllerConcern
  skip_before_action :authenticate_user!, only: %i[new create waiting status callback]

  # Required: ActionController::Metal already defines #status, so Rails drops it from
  # action_methods. Re-declaring it makes the polling action routable.
  def status = super
end
```

### Views (host-owned)

`app/views/sso/sessions/new.html.erb` — an e-mail-only form that POSTs to `login_path`.

`app/views/sso/sessions/waiting.html.erb` — a page that polls `sso_status_path` and
navigates on approval. Wire it to a Stimulus controller:

```erb
<div data-controller="sso-poll"
     data-sso-poll-url-value="<%= sso_status_path %>"
     data-sso-poll-login-value="<%= login_path %>">
  <p data-sso-poll-target="message">Approve the request in Tools to continue…</p>
</div>
```

### Stimulus poller (host-owned)

```javascript
// app/javascript/controllers/sso_poll_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, login: String }
  static targets = ["message"]

  connect() { this.timer = setInterval(() => this.check(), 2000) }
  disconnect() { clearInterval(this.timer) }

  async check() {
    const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
    const data = await res.json()
    if (data.status === "approved") {
      clearInterval(this.timer)
      window.location = data.redirect_to
    } else if (["denied", "expired", "error"].includes(data.status)) {
      clearInterval(this.timer)
      window.location = this.loginValue
    }
  }
}
```

### Flow

- `new` renders the e-mail form (returns early without redirecting).
- `create` calls `IdentityProvider.create_auth_request(email:)`, stores the returned
  `request_id` in the session, and redirects to `waiting`.
- `status` (polled as JSON) calls `IdentityProvider.poll_auth_request(request_id:)`.
  While pending it returns `{ status: "pending" }`. On approval it exchanges the code,
  runs the provisioner, signs in, and returns `{ status: "approved", redirect_to: ... }`.
  Denied/expired/error are reported so the client can return to login.

The IdP side (request creation, the approval notification, approve/deny, the signed
single-use code) lives in the Tools app, not in this gem.

## Errors

- `SicoobSso::Error` — base error
- `SicoobSso::ExchangeError` — raised by `IdentityProvider` on a non-2xx response from
  the IdP (token exchange, auth-request creation, or polling)

## Development

```bash
bundle install
bundle exec rake test
```

`IdentityProvider` and `Configuration` are unit-tested here. The controller concerns are
integration-tested in the host application (they need a Rails controller context,
`Session`, and `Current`); the gem suite only verifies they load and expose the expected
methods.

## License

MIT.
