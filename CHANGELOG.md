# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `AttestoMCP.Plug.ProtectResource`: a single plug composing
  `AttestoMCP.Plug.Authenticate` then `AttestoMCP.Plug.RequireScopes` into a
  correctly ordered, halt-respecting pipeline, with the RFC 9728
  `resource_metadata` `WWW-Authenticate` challenge auto-wired from the resource
  path.
- `AttestoMCP.Router` with the `attesto_mcp_protected_resource_metadata/2`
  Phoenix router macro, and `AttestoMCP.MetadataController`, serving
  per-resource `/.well-known/oauth-protected-resource/<path>` metadata plus a
  backwards-compatible root `/.well-known/oauth-protected-resource` route. The
  served `resource` identifier matches the `ProtectResource` challenge.
- `AttestoMCP.Test.DPoPAssertions`: shipped ExUnit assertions for host apps
  proving a DPoP-bound token presented as a plain Bearer is rejected and is
  accepted with a valid DPoP proof.
- `guides/mcp_wiring.md`: copy-pasteable end-to-end wiring guide.
- `phoenix` as an optional dependency (only needed by `AttestoMCP.Router` and
  `AttestoMCP.MetadataController`).

## [0.1.0] - 2026-05-31

### Added

- Initial Plug/Phoenix authentication wrapper for protecting HTTP MCP endpoints
  with Attesto access-token verification, DPoP proof checks, and mTLS
  certificate-bound token checks.
- MCP scope convention helpers.
- OAuth protected-resource metadata builder and authorization-server metadata
  delegation.
- Focused tests for Bearer, DPoP, mTLS, scope enforcement, principal mapping,
  custom error rendering, and public assign names.
