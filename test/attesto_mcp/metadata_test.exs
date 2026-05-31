defmodule AttestoMCP.MetadataTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Plug.Test

  alias AttestoMCP.Metadata
  alias AttestoMCP.Scopes
  alias AttestoMCP.Test.Factory

  test "protected resource metadata includes MCP OAuth handoff fields" do
    metadata =
      Metadata.protected_resource(
        resource: "https://mcp.example.com/mcp",
        authorization_servers: ["https://auth.example.com"],
        resource_name: "Example MCP server",
        tls_client_certificate_bound_access_tokens: true
      )

    assert metadata["resource"] == "https://mcp.example.com/mcp"
    assert metadata["authorization_servers"] == ["https://auth.example.com"]
    assert Scopes.tools_call() in metadata["scopes_supported"]
    assert metadata["bearer_methods_supported"] == ["header"]
    assert metadata["tls_client_certificate_bound_access_tokens"] == true
  end

  test "protected resource metadata can be derived from a Plug connection" do
    conn = conn(:get, "https://mcp.example.com/.well-known/oauth-protected-resource/mcp/user")

    metadata =
      Metadata.protected_resource(conn, "/mcp/user", scopes_supported: ["mcp:user"])

    assert metadata["resource"] == "https://mcp.example.com/mcp/user"
    assert metadata["authorization_servers"] == ["https://mcp.example.com"]
    assert metadata["scopes_supported"] == ["mcp:user"]
  end

  test "protected resource URL can be derived from a Plug connection" do
    conn = conn(:get, "https://mcp.example.com/mcp/user")

    assert Metadata.protected_resource_url(conn, "/mcp/user") ==
             "https://mcp.example.com/.well-known/oauth-protected-resource/mcp/user"
  end

  test "authorization server metadata delegates to Attesto discovery" do
    metadata =
      Factory.config()
      |> Metadata.authorization_server(
        authorization_endpoint: "https://auth.example.com/oauth/authorize",
        registration_endpoint: "https://auth.example.com/oauth/register"
      )

    assert metadata["issuer"] == "https://auth.example.com"
    assert metadata["authorization_endpoint"] == "https://auth.example.com/oauth/authorize"
    assert metadata["registration_endpoint"] == "https://auth.example.com/oauth/register"
  end
end
