defmodule AttestoMCP do
  @moduledoc """
  Authentication helpers for HTTP-based Model Context Protocol servers.

  `attesto_mcp` does not implement the Model Context Protocol. It wraps
  Plug/Phoenix endpoints that already speak MCP and connects them to Attesto's
  OAuth/OIDC verifier, DPoP proof verification, mTLS token binding, scope
  algebra, and metadata builders.
  """
end
