# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
