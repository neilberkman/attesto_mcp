defmodule AttestoMCP.Plug.Authenticate do
  @moduledoc """
  Authenticate a protected MCP endpoint with Attesto.

  This plug delegates token, DPoP, and mTLS verification to
  `Attesto.Plug.Authenticate`, then assigns MCP-friendly auth context for the
  host server.

  Defaults:

    * `:claims_key` - `:attesto_mcp_claims`
    * `:scopes_key` - `:attesto_mcp_scopes`
    * `:sender_key` - `:attesto_mcp_sender`
    * `:principal_key` - `:attesto_mcp_principal`

  Options accepted by `Attesto.Plug.Authenticate`, including `:config`,
  `:replay_check`, `:nonce_check`, `:nonce_issue`, `:cert_der`, `:htu`,
  `:credential_from_conn`, `:send_error`, `:www_authenticate`, and
  `:no_store`, are passed through.

  Additional options:

    * `:principal` - optional callback that receives verified claims and sender
      context, returning `{:ok, principal}` or `{:error, reason}`.
    * `:resource_metadata_url` - URL string or `(conn -> url)` callback that
      appends an RFC 9728 `resource_metadata` auth-param to
      `WWW-Authenticate` challenges unless a custom `:www_authenticate`
      callback is already supplied.
    * `:resource_path` - MCP endpoint path used to derive
      `:resource_metadata_url` from the live request origin.
  """

  @behaviour Plug

  import Plug.Conn

  alias Attesto.Plug.Authenticate, as: AttestoAuthenticate
  alias AttestoMCP.Metadata
  alias AttestoMCP.Plug.Error

  @claims_key :attesto_mcp_claims
  @scopes_key :attesto_mcp_scopes
  @sender_key :attesto_mcp_sender
  @principal_key :attesto_mcp_principal

  @impl Plug
  def init(opts) when is_list(opts) do
    AttestoAuthenticate.init(core_opts(opts, @claims_key))
    opts
  end

  @impl Plug
  def call(conn, opts) do
    claims_key = Keyword.get(opts, :claims_key, @claims_key)

    conn =
      conn
      |> AttestoAuthenticate.call(core_opts(opts, claims_key))

    if conn.halted do
      conn
    else
      assign_context(conn, opts, claims_key)
    end
  end

  defp assign_context(conn, opts, claims_key) do
    claims = conn.assigns[claims_key]
    sender = sender_context(claims)
    scopes = scopes(claims)

    conn =
      conn
      |> assign(Keyword.get(opts, :scopes_key, @scopes_key), scopes)
      |> assign(Keyword.get(opts, :sender_key, @sender_key), sender)

    assign_principal(conn, opts, claims, sender)
  end

  defp assign_principal(conn, opts, claims, sender) do
    case Keyword.get(opts, :principal) do
      nil ->
        conn

      callback ->
        case invoke(callback, [claims, sender]) do
          {:ok, principal} ->
            assign(conn, Keyword.get(opts, :principal_key, @principal_key), principal)

          {:error, _reason} ->
            Error.unauthorized(conn, scheme_of(claims), "invalid_token", error_opts(opts, []))
        end
    end
  end

  defp core_opts(opts, claims_key) do
    opts
    |> Keyword.drop([:principal, :principal_key, :resource_metadata_url, :resource_path, :scopes_key, :sender_key])
    |> Keyword.put(:claims_key, claims_key)
    |> maybe_put_metadata_challenge(opts)
  end

  defp maybe_put_metadata_challenge(core_opts, opts) do
    cond do
      Keyword.has_key?(core_opts, :www_authenticate) ->
        core_opts

      metadata_url = metadata_url_resolver(opts) ->
        Keyword.put(core_opts, :www_authenticate, fn conn, challenge ->
          put_resp_header(conn, "www-authenticate", Metadata.append_resource_metadata(challenge, metadata_url.(conn)))
        end)

      true ->
        core_opts
    end
  end

  defp metadata_url_resolver(opts) do
    case Keyword.get(opts, :resource_metadata_url) do
      url when is_binary(url) ->
        fn _conn -> url end

      fun when is_function(fun, 1) ->
        fun

      _ ->
        metadata_url_from_resource_path(Keyword.get(opts, :resource_path))
    end
  end

  defp metadata_url_from_resource_path(path) when is_binary(path) do
    fn conn -> Metadata.protected_resource_url(conn, path) end
  end

  defp metadata_url_from_resource_path(_path), do: nil

  defp scopes(%{"scope" => scope}) when is_binary(scope), do: String.split(scope, ~r/\s+/, trim: true)
  defp scopes(_claims), do: []

  defp sender_context(%{"cnf" => %{"jkt" => jkt}}) when is_binary(jkt) do
    %{binding: :dpop, jkt: jkt}
  end

  defp sender_context(%{"cnf" => %{"x5t#S256" => thumbprint}}) when is_binary(thumbprint) do
    %{binding: :mtls, x5t_s256: thumbprint}
  end

  defp sender_context(_claims), do: %{binding: :bearer}

  defp scheme_of(%{"cnf" => %{"jkt" => jkt}}) when is_binary(jkt), do: :dpop
  defp scheme_of(_claims), do: :bearer

  defp error_opts(opts, extra) do
    opts
    |> Keyword.take([:send_error, :www_authenticate, :no_store])
    |> Keyword.merge(extra)
  end

  defp invoke(fun, args) when is_function(fun), do: apply(fun, args)

  defp invoke({module, fun}, args) when is_atom(module) and is_atom(fun), do: apply(module, fun, args)

  defp invoke({module, fun, extra}, args) when is_atom(module) and is_atom(fun) and is_list(extra),
    do: apply(module, fun, args ++ extra)
end
