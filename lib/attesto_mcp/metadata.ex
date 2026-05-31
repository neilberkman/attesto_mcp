defmodule AttestoMCP.Metadata do
  @moduledoc """
  Builders for OAuth metadata used by HTTP MCP authorization.

  MCP HTTP servers that require authorization act as OAuth protected resources.
  The MCP authorization spec points clients at RFC 9728 protected-resource
  metadata first, then at RFC 8414 authorization-server metadata. This module
  builds those documents without coupling the package to any MCP server SDK.
  """

  alias Attesto.Config
  alias Attesto.Discovery
  alias Attesto.DPoP
  alias AttestoMCP.Scopes

  @protected_resource_fields ~w(
    authorization_details_types_supported
    bearer_methods_supported
    dpop_bound_access_tokens_required
    dpop_signing_alg_values_supported
    jwks_uri
    resource_documentation
    resource_name
    resource_policy_uri
    resource_signing_alg_values_supported
    resource_tos_uri
    scopes_supported
    signed_metadata
    tls_client_certificate_bound_access_tokens
  )a

  @doc """
  Build an RFC 9728 protected-resource metadata document.

  Required options:

    * `:resource` - the protected resource identifier, usually the canonical
      MCP server URI such as `"https://mcp.example.com/mcp"`.
    * `:authorization_servers` - a non-empty list of issuer identifiers.

  Common options include `:scopes_supported`, `:bearer_methods_supported`,
  `:dpop_signing_alg_values_supported`, and
  `:tls_client_certificate_bound_access_tokens`.
  """
  @spec protected_resource(keyword()) :: %{required(String.t()) => term()}
  def protected_resource(opts) when is_list(opts) do
    resource = Keyword.fetch!(opts, :resource)
    authorization_servers = Keyword.fetch!(opts, :authorization_servers)

    %{
      "authorization_servers" => authorization_servers,
      "resource" => resource
    }
    |> put_new(:bearer_methods_supported, ["header"])
    |> put_new(:dpop_signing_alg_values_supported, DPoP.allowed_algs())
    |> put_new(:scopes_supported, Scopes.all())
    |> merge_supported_fields(opts)
  end

  @doc """
  Build protected-resource metadata from a Plug connection and resource path.

  `resource_path` is the path of the MCP endpoint, for example `"/mcp"` or
  `"/mcp/admin"`. The resource identifier is the current request origin joined
  with that path. `:authorization_servers` defaults to the same origin.
  """
  @spec protected_resource(Plug.Conn.t(), String.t(), keyword()) :: %{required(String.t()) => term()}
  def protected_resource(%Plug.Conn{} = conn, resource_path, opts \\ []) when is_binary(resource_path) do
    base_url = base_url(conn)

    opts
    |> Keyword.put_new(:authorization_servers, [base_url])
    |> Keyword.put(:resource, base_url <> normalize_path(resource_path))
    |> protected_resource()
  end

  @doc """
  Build the well-known metadata URL for an MCP resource path.

      iex> AttestoMCP.Metadata.protected_resource_url("https://mcp.example.com", "/mcp")
      "https://mcp.example.com/.well-known/oauth-protected-resource/mcp"

  A Plug connection can also be passed as the first argument.
  """
  @spec protected_resource_url(String.t(), String.t()) :: String.t()
  def protected_resource_url(base_url, resource_path) when is_binary(base_url) and is_binary(resource_path) do
    String.trim_trailing(base_url, "/") <> "/.well-known/oauth-protected-resource" <> normalize_path(resource_path)
  end

  @spec protected_resource_url(Plug.Conn.t(), String.t()) :: String.t()
  def protected_resource_url(%Plug.Conn{} = conn, resource_path) when is_binary(resource_path) do
    conn
    |> base_url()
    |> protected_resource_url(resource_path)
  end

  @doc """
  Build the `WWW-Authenticate` auth-param value for RFC 9728 metadata discovery.
  """
  @spec resource_metadata_param(String.t()) :: String.t()
  def resource_metadata_param(url) when is_binary(url), do: ~s(resource_metadata="#{escape(url)}")

  @doc """
  Append `resource_metadata` to a `WWW-Authenticate` challenge.
  """
  @spec append_resource_metadata(String.t(), String.t()) :: String.t()
  def append_resource_metadata(challenge, url) when is_binary(challenge) and is_binary(url) do
    challenge <> ", " <> resource_metadata_param(url)
  end

  @doc """
  Build the authorization-server metadata document by delegating to Attesto.
  """
  @spec authorization_server(Config.t(), keyword()) :: %{required(String.t()) => term()}
  def authorization_server(%Config{} = config, opts \\ []), do: Discovery.metadata(config, opts)

  defp merge_supported_fields(map, opts) do
    Enum.reduce(@protected_resource_fields, map, fn field, acc ->
      case Keyword.get(opts, field) do
        nil -> acc
        value -> Map.put(acc, Atom.to_string(field), value)
      end
    end)
  end

  defp put_new(map, key, value) do
    Map.put_new(map, Atom.to_string(key), value)
  end

  defp escape(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp base_url(%Plug.Conn{} = conn) do
    scheme = Atom.to_string(conn.scheme)
    scheme <> "://" <> conn.host <> port_suffix(scheme, conn.port)
  end

  defp port_suffix("https", 443), do: ""
  defp port_suffix("http", 80), do: ""
  defp port_suffix(_scheme, port), do: ":" <> Integer.to_string(port)

  defp normalize_path("/" <> _rest = path), do: path
  defp normalize_path(path), do: "/" <> path
end
