defmodule AttestoMCP.Test.Factory do
  @moduledoc false

  alias Attesto.Keystore.Static
  alias Attesto.Token

  @issuer "https://auth.example.com"
  @audience "https://mcp.example.com/mcp"
  @subject "usr_123"

  def config do
    Application.put_env(:attesto, Static, signing_pem: signing_pem())
    ExUnit.Callbacks.on_exit(fn -> Application.delete_env(:attesto, Static) end)

    Attesto.Config.new(
      issuer: @issuer,
      audience: @audience,
      keystore: Static,
      principal_kinds: [
        Attesto.PrincipalKind.new("user", "usr_", required_claims: [{"client_id", :non_empty_string}])
      ]
    )
  end

  def access_token(config, opts \\ []) do
    principal = %{
      claims: %{"client_id" => "client-1"},
      kind: "user",
      scopes: Keyword.get(opts, :scopes, [AttestoMCP.Scopes.tools_call()]),
      sub: @subject
    }

    {:ok, token} =
      Token.mint(
        config,
        principal,
        Keyword.take(opts, [:dpop_jkt, :mtls_cert_thumbprint])
      )

    token.access_token
  end

  def dpop_proof(access_token, opts \\ []) do
    jwk = Keyword.get_lazy(opts, :jwk, fn -> JOSE.JWK.generate_key({:ec, "P-256"}) end)
    {_, public_map} = JOSE.JWK.to_public_map(jwk)

    header = %{
      "alg" => "ES256",
      "jwk" => public_map,
      "typ" => "dpop+jwt"
    }

    payload = %{
      "ath" => Attesto.DPoP.compute_ath(access_token),
      "htm" => Keyword.get(opts, :htm, "POST"),
      "htu" => Keyword.get(opts, :htu, @audience),
      "iat" => System.system_time(:second),
      "jti" => "proof-" <> Integer.to_string(System.unique_integer([:positive]))
    }

    {_protected, proof} = jwk |> JOSE.JWT.sign(header, payload) |> JOSE.JWS.compact()
    {proof, JOSE.JWK.thumbprint(jwk)}
  end

  def dpop_jwk, do: JOSE.JWK.generate_key({:ec, "P-256"})

  def self_signed_cert_der do
    %{cert: der} = :public_key.pkix_test_root_cert(~c"CN=attesto-mcp-test", [])
    der
  end

  def htu, do: @audience

  defp signing_pem do
    JOSE.JWK.generate_key({:rsa, 2048}) |> JOSE.JWK.to_pem() |> elem(1)
  end
end
