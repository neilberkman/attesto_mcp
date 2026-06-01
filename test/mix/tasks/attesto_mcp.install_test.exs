defmodule Mix.Tasks.AttestoMcp.InstallTest do
  # Module name is `AttestoMcp` (not `AttestoMCP`) so the test module mirrors the
  # task module Mix resolves; see the note on Mix.Tasks.AttestoMcp.Install.
  use ExUnit.Case, async: true

  import Igniter.Test

  # The router is passed explicitly so the task never falls back to igniter's
  # module-scanning router discovery, which is not deterministic when the whole
  # suite runs against the shared igniter test scratch project.
  @argv ["--resource-path", "/mcp", "--scopes", "mcp:use", "--router", "TestWeb.Router"]

  describe "mix attesto_mcp.install" do
    test "scaffolds the protecting pipeline and the metadata routes into the router" do
      source =
        phx_test_project()
        |> Igniter.compose_task("attesto_mcp.install", @argv)
        |> apply_igniter!()
        |> router_source()

      # The bearer-token + scope pipeline (RFC 6750 / RFC 6749 Section 3.3).
      assert source =~ "AttestoMCP.Plug.ProtectResource"
      assert source =~ ~s(scopes: ["mcp:use"])
      # The RFC 9728 protected-resource metadata routes.
      assert source =~ "AttestoMCP.MetadataController"
      assert source =~ "/oauth-protected-resource/mcp"
    end

    test "is idempotent across re-runs" do
      installed_router =
        phx_test_project()
        |> Igniter.compose_task("attesto_mcp.install", @argv)
        |> apply_igniter!()
        |> router_source()

      # Seed a fresh project with the already-installed router, then run the
      # task again and apply it. The router source must be byte-for-byte
      # identical: the pipeline is matched by name, and each scope addition is
      # guarded by a marker already present in the source, so a second run adds
      # nothing.
      rerun_router =
        phx_test_project(files: %{"lib/test_web/router.ex" => installed_router})
        |> Igniter.compose_task("attesto_mcp.install", @argv)
        |> apply_igniter!()
        |> router_source()

      assert rerun_router == installed_router
    end
  end

  # Read the post-apply contents of the generated router from the igniter's
  # Rewrite project. `Igniter.Test` exposes no public source-reader, so go
  # through Rewrite directly (the same path its own `assert_content_equals` uses).
  defp router_source(igniter) do
    igniter.rewrite
    |> Rewrite.source!("lib/test_web/router.ex")
    |> Rewrite.Source.get(:content)
  end
end
