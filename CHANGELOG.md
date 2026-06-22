# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/) and the
project adheres to [Semantic Versioning](https://semver.org/).

## 1.1.0

- The engine now auto-includes `SicoobSso::Authentication` into
  `ActionController::Base` (via `on_load`), so hosts no longer need
  `include SicoobSso::Authentication` — just `before_action :authenticate_user!`.

## 1.0.0

First stable release. The public API (`SicoobSso.configure`,
`SicoobSso::IdentityProvider`, `SicoobSso::Authentication`,
`SicoobSso::SessionsControllerConcern`, `sicoob_sso_routes`) is now considered
stable.

### Added
- Rails Engine packaging: ships the sessions controller, routes helper, and
  default views (`new`, `waiting`) — plug-and-play and overridable by the host.
- Two login strategies selectable per host: `:redirect` (OAuth-style) and
  `:push_approval` (passwordless e-mail + in-app approval).
- `app_name` configuration (`SSO_APP_NAME`) used in the default views.
- Bounded polling on the waiting view: the poller stops after ~3 minutes and
  shows a "tente novamente" message instead of looping forever.
- Test coverage for `IdentityProvider` back-channel calls and for the
  `SessionsControllerConcern` state check and poll dispatch.

### Security
- Back-channel HTTP calls to the IdP now enforce TLS (SSL enabled for `https`
  URIs, keeping the default `VERIFY_PEER`) and explicit open/read timeouts
  (5s / 10s), so a hung or unreachable IdP cannot block app threads.

### Changed
- `IdentityProvider` centralizes all HTTP through a single private request
  helper. Public function signatures and return values are unchanged.
