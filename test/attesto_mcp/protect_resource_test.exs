defmodule AttestoMCP.Plug.ProtectResourceTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias AttestoMCP.Plug.ProtectResource
  alias AttestoMCP.Scopes
  alias AttestoMCP.Test.DPoPReplay
  alias AttestoMCP.Test.Factory

  setup do
    %{config: Factory.config()}
  end

  test "bearer token with the required scope is accepted", %{config: config} do
    token = Factory.access_token(config, scopes: [Scopes.tools_call()])

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "Bearer " <> token)
      |> protect(config, scopes: [Scopes.tools_call()])

    refute conn.halted
    assert conn.assigns.attesto_mcp_claims["sub"] == "usr_123"
    assert conn.assigns.attesto_mcp_scopes == [Scopes.tools_call()]
  end

  test "a token missing the required scope is rejected with insufficient_scope", %{config: config} do
    token = Factory.access_token(config, scopes: [Scopes.resources_read()])

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "Bearer " <> token)
      |> protect(config, scopes: [Scopes.tools_call()])

    assert conn.halted
    assert conn.status == 403
    assert JSON.decode!(conn.resp_body)["error"] == "insufficient_scope"
  end

  test "scope enforcement is skipped once authentication halts", %{config: config} do
    token = Factory.access_token(config, dpop_jkt: dpop_jkt())

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "Bearer " <> token)
      |> protect(config, scopes: [Scopes.tools_call()])

    assert conn.halted
    assert conn.status == 401
    assert JSON.decode!(conn.resp_body)["error"] == "invalid_token"
  end

  test "a DPoP-bound token is accepted with a valid proof", %{config: config} do
    jwk = Factory.dpop_jwk()
    {_unused, jkt} = Factory.dpop_proof("placeholder", jwk: jwk)
    token = Factory.access_token(config, dpop_jkt: jkt, scopes: [Scopes.tools_call()])
    {proof, ^jkt} = Factory.dpop_proof(token, jwk: jwk)

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "DPoP " <> token)
      |> put_req_header("dpop", proof)
      |> protect(config, scopes: [Scopes.tools_call()], replay_check: DPoPReplay.callback())

    refute conn.halted
    assert conn.assigns.attesto_mcp_sender == %{binding: :dpop, jkt: jkt}
  end

  test "the resource path drives the RFC 9728 resource_metadata challenge", %{config: config} do
    conn =
      :post
      |> conn("https://mcp.example.com/mcp/brokers")
      |> protect(config, scopes: [Scopes.tools_call()], resource: "/mcp/brokers")

    assert conn.halted
    assert [challenge] = get_resp_header(conn, "www-authenticate")
    assert challenge =~ ~s(resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource/mcp/brokers")
  end

  test "the single required scope is accepted via :scope", %{config: config} do
    token = Factory.access_token(config, scopes: [Scopes.tools_call()])

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "Bearer " <> token)
      |> protect(config, scope: Scopes.tools_call())

    refute conn.halted
  end

  defp dpop_jkt do
    {_proof, jkt} = Factory.dpop_proof("placeholder")
    jkt
  end

  defp protect(conn, config, opts) do
    opts =
      Keyword.merge(
        [
          config: config,
          htu: fn _conn -> Factory.htu() end
        ],
        opts
      )

    ProtectResource.call(conn, ProtectResource.init(opts))
  end
end
