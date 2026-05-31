defmodule AttestoMCP.Plug.Error do
  @moduledoc false

  import Plug.Conn

  alias Attesto.Plug.OAuthError

  @type body :: %{required(String.t()) => term()}

  @spec unauthorized(Plug.Conn.t(), OAuthError.scheme(), String.t(), keyword()) :: Plug.Conn.t()
  def unauthorized(conn, scheme, error, opts) do
    OAuthError.unauthorized(conn, scheme, error, opts)
  end

  @spec insufficient_scope(Plug.Conn.t(), [String.t()], OAuthError.scheme(), keyword()) :: Plug.Conn.t()
  def insufficient_scope(conn, required, scheme, opts) do
    scope = Enum.join(required, " ")

    body = %{
      "error" => "insufficient_scope",
      "error_description" => "requires scope: #{scope}"
    }

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
    |> put_www_authenticate(challenge(scheme, required), opts)
    |> send_error(403, body, opts)
  end

  @spec send_error(Plug.Conn.t(), non_neg_integer(), body(), keyword()) :: Plug.Conn.t()
  def send_error(conn, status, body, opts) do
    case Keyword.get(opts, :send_error) do
      fun when is_function(fun, 3) ->
        fun.(conn, status, body)

      {module, fun} when is_atom(module) and is_atom(fun) ->
        apply(module, fun, [conn, status, body])

      {module, fun, extra} when is_atom(module) and is_atom(fun) and is_list(extra) ->
        apply(module, fun, [conn, status, body | extra])

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, JSON.encode!(body))
        |> halt()
    end
  end

  defp put_www_authenticate(conn, challenge, opts) do
    case Keyword.get(opts, :www_authenticate) do
      fun when is_function(fun, 2) ->
        fun.(conn, challenge)

      {module, fun} when is_atom(module) and is_atom(fun) ->
        apply(module, fun, [conn, challenge])

      {module, fun, extra} when is_atom(module) and is_atom(fun) and is_list(extra) ->
        apply(module, fun, [conn, challenge | extra])

      _ ->
        put_resp_header(conn, "www-authenticate", challenge)
    end
  end

  defp challenge(scheme, required) do
    scope = Enum.join(required, " ")

    scheme_label =
      case scheme do
        :dpop -> "DPoP"
        _ -> "Bearer"
      end

    ~s(#{scheme_label} error="insufficient_scope", error_description="requires scope: #{scope}", scope="#{scope}")
  end
end
