defmodule AttestoMCP.Plug.RequireScopesTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias AttestoMCP.Plug.Authenticate
  alias AttestoMCP.Plug.RequireScopes
  alias AttestoMCP.Scopes
  alias AttestoMCP.Test.Factory

  setup do
    %{config: Factory.config()}
  end

  test "required scope is accepted", %{config: config} do
    token = Factory.access_token(config, scopes: [Scopes.tools_call()])

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "Bearer " <> token)
      |> authenticate(config)
      |> require_scopes([Scopes.tools_call()])

    refute conn.halted
  end

  test "required scope is rejected", %{config: config} do
    token = Factory.access_token(config, scopes: [Scopes.resources_read()])

    conn =
      :post
      |> conn("/mcp")
      |> put_req_header("authorization", "Bearer " <> token)
      |> authenticate(config)
      |> require_scopes([Scopes.tools_call()])

    assert conn.halted
    assert conn.status == 403
    assert JSON.decode!(conn.resp_body)["error"] == "insufficient_scope"
  end

  defp authenticate(conn, config) do
    Authenticate.call(conn, Authenticate.init(config: config, htu: fn _conn -> Factory.htu() end))
  end

  defp require_scopes(conn, scopes) do
    RequireScopes.call(conn, RequireScopes.init(scopes: scopes))
  end
end
