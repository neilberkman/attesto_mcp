defmodule AttestoMCP.Router do
  @moduledoc """
  Phoenix router macros for OAuth protected-resource metadata discovery.

  The MCP authorization spec treats a protected HTTP MCP server as an OAuth
  resource server. Clients discover where to authorize by fetching RFC 9728
  protected-resource metadata from a well-known location derived from the
  resource path: `/.well-known/oauth-protected-resource/<resource-path>` (and,
  for clients that predate the path-suffixed form, the root
  `/.well-known/oauth-protected-resource`).

  `use AttestoMCP.Router` imports `attesto_mcp_protected_resource_metadata/2`,
  which mounts both routes for a resource at `AttestoMCP.MetadataController`. The
  served `resource` identifier is the request origin joined with the resource
  path, which is the same value `AttestoMCP.Plug.ProtectResource` advertises in
  its `WWW-Authenticate` `resource_metadata` challenge, so discovery and
  challenge always agree.

  ## Single resource

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use AttestoMCP.Router

        scope "/" do
          pipe_through :api
          attesto_mcp_protected_resource_metadata "/mcp", scopes: ["mcp:tools:call"]
        end
      end

  This serves:

    * `GET /.well-known/oauth-protected-resource/mcp`
    * `GET /.well-known/oauth-protected-resource` (root, backwards compatible,
      first declared resource)

  ## Multiple resources

  Declare one call per protected resource. Each gets its own well-known route
  and its own metadata document; the root compatibility route resolves to the
  first resource declared.

      attesto_mcp_protected_resource_metadata "/mcp/foo", scopes: ["foo:mcp:tools:call"]
      attesto_mcp_protected_resource_metadata "/mcp/bar", scopes: ["bar:mcp:tools:call"]

  ## Options

  Options are forwarded to `AttestoMCP.Metadata.protected_resource/3`. The most
  common is `:scopes` (served as `scopes_supported`); `:authorization_servers`,
  `:resource_name`, `:tls_client_certificate_bound_access_tokens`, and the other
  RFC 9728 fields are also accepted.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import AttestoMCP.Router

      Module.register_attribute(__MODULE__, :attesto_mcp_root_mounted, accumulate: false)
      Module.put_attribute(__MODULE__, :attesto_mcp_root_mounted, false)
    end
  end

  @doc """
  Mount the RFC 9728 protected-resource metadata routes for one MCP resource.

  `resource_path` is the path of the protected MCP endpoint, for example
  `"/mcp"` or `"/mcp/brokers"`. `opts` are forwarded to
  `AttestoMCP.Metadata.protected_resource/3`; pass `:scopes` to advertise the
  scopes the resource requires.
  """
  defmacro attesto_mcp_protected_resource_metadata(resource_path, opts \\ []) do
    quote bind_quoted: [resource_path: resource_path, opts: opts] do
      private = %{
        attesto_mcp_metadata_opts: opts,
        attesto_mcp_resource_path: resource_path
      }

      get "/.well-known/oauth-protected-resource" <> resource_path,
          AttestoMCP.MetadataController,
          :show,
          private: private

      # RFC 9728 §3.1 path-suffixed metadata is the current form, but some
      # clients still probe the root location. Mount it once, resolving to the
      # first resource declared.
      if !Module.get_attribute(__MODULE__, :attesto_mcp_root_mounted) do
        get "/.well-known/oauth-protected-resource",
            AttestoMCP.MetadataController,
            :show,
            private: private

        Module.put_attribute(__MODULE__, :attesto_mcp_root_mounted, true)
      end
    end
  end
end
