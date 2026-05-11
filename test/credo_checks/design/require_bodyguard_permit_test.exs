defmodule Holter.Credo.Check.Design.RequireBodyguardPermitTest do
  use ExUnit.Case, async: true

  Code.require_file(
    "../../../credo_checks/design/require_bodyguard_permit.ex",
    __DIR__
  )

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  alias Credo.SourceFile
  alias Holter.Credo.Check.Design.RequireBodyguardPermit

  describe "boundary module (lib/holter_web/...)" do
    test "flags a mutation call without authorize/3" do
      source =
        """
        defmodule HolterWeb.Api.MonitorController do
          def delete(conn, %{"id" => id}) do
            with {:ok, monitor} <- Monitoring.get_monitor(id),
                 {:ok, _} <- Monitoring.delete_monitor(monitor) do
              send_resp(conn, :no_content, "")
            end
          end
        end
        """
        |> parse("lib/holter_web/api/controllers/monitor_controller.ex")

      issues = RequireBodyguardPermit.run(source)

      assert length(issues) == 1
    end

    test "passes when authorize/3 is called in the same body" do
      source =
        """
        defmodule HolterWeb.Api.MonitorController do
          def delete(conn, %{"id" => id}) do
            actor = conn.assigns.current_user

            with {:ok, monitor} <- Monitoring.get_monitor(id),
                 :ok <- authorize(actor, :delete, monitor),
                 {:ok, _} <- Monitoring.delete_monitor(monitor) do
              send_resp(conn, :no_content, "")
            end
          end
        end
        """
        |> parse("lib/holter_web/api/controllers/monitor_controller.ex")

      assert RequireBodyguardPermit.run(source) == []
    end

    test "accepts an explicit Bodyguard.permit/4 call as a permit" do
      source =
        """
        defmodule HolterWeb.Api.MonitorController do
          def delete(conn, %{"id" => id}) do
            actor = conn.assigns.current_user

            with {:ok, monitor} <- Monitoring.get_monitor(id),
                 :ok <- Bodyguard.permit(MonitorPolicy, :delete, actor, monitor),
                 {:ok, _} <- Monitoring.delete_monitor(monitor) do
              send_resp(conn, :no_content, "")
            end
          end
        end
        """
        |> parse("lib/holter_web/api/controllers/monitor_controller.ex")

      assert RequireBodyguardPermit.run(source) == []
    end

    test "ignores non-mutating reads" do
      source =
        """
        defmodule HolterWeb.Api.MonitorController do
          def show(conn, %{"id" => id}) do
            with {:ok, monitor} <- Monitoring.get_monitor(id) do
              render(conn, :show, monitor: monitor)
            end
          end
        end
        """
        |> parse("lib/holter_web/api/controllers/monitor_controller.ex")

      assert RequireBodyguardPermit.run(source) == []
    end

    test "detects all configured mutation prefixes" do
      source =
        """
        defmodule HolterWeb.Probe do
          def a(_), do: Monitoring.create_monitor(%{})
          def b(_), do: Monitoring.update_monitor(nil, %{})
          def c(_), do: Monitoring.delete_monitor(nil)
          def d(_), do: Monitoring.mark_manual_check_triggered(nil)
          def e(_), do: Identity.ApiTokens.revoke_token(nil)
          def f(_), do: Delivery.EmailChannels.regenerate_anti_phishing_code(nil)
          def g(_), do: Delivery.EmailChannels.apply_staged_changes(nil, %{})
          def h(_), do: Delivery.EmailChannels.resend_recipient_verification(nil)
          def i(_), do: Delivery.Engine.dispatch_test_email(nil)
          def j(_), do: Monitoring.enqueue_checks(nil)
          def k(_), do: Monitoring.recalculate_health_status(nil)
        end
        """
        |> parse("lib/holter_web/web/probe.ex")

      issues = RequireBodyguardPermit.run(source)

      assert length(issues) == 11
    end

    test "ignores self-action exemptions (login, logout, register, preferences)" do
      source =
        """
        defmodule HolterWeb.Web.Identity.UserSessionController do
          def create(_, _) do
            Identity.create_session_token(user, %{})
          end

          def delete(_, _) do
            Identity.delete_session_token(token)
          end
        end

        defmodule HolterWeb.Web.Identity.UserLive.Show do
          def handle_event("save", _, _) do
            Identity.update_user_preferences(user, %{})
          end
        end
        """
        |> parse("lib/holter_web/web/identity/user_session_controller.ex")

      assert RequireBodyguardPermit.run(source) == []
    end

    test "ignores calls to non-guarded namespaces (Repo, etc.)" do
      source =
        """
        defmodule HolterWeb.Api.SomethingController do
          def delete(conn, _) do
            Repo.delete_all(SomeSchema)
            send_resp(conn, :no_content, "")
          end
        end
        """
        |> parse("lib/holter_web/api/controllers/something_controller.ex")

      assert RequireBodyguardPermit.run(source) == []
    end

    test "message identifies the offending function name" do
      source =
        """
        defmodule HolterWeb.Api.MonitorController do
          def delete(_, _) do
            Monitoring.delete_monitor(nil)
          end
        end
        """
        |> parse("lib/holter_web/api/controllers/monitor_controller.ex")

      [issue] = RequireBodyguardPermit.run(source)

      assert issue.message =~ "delete"
    end
  end

  describe "non-boundary code (lib/holter/...)" do
    test "is exempt — workers and contexts can mutate without permit" do
      source =
        """
        defmodule Holter.Monitoring.Workers.HTTPCheck do
          def perform(_job) do
            Monitoring.update_monitor(nil, %{})
            :ok
          end
        end
        """
        |> parse("lib/holter/monitoring/workers/http_check.ex")

      assert RequireBodyguardPermit.run(source) == []
    end

    test "is exempt — coordinator helpers can call mutations" do
      source =
        """
        defmodule Holter.Monitoring.Engine do
          defp record_check(_), do: Monitoring.create_monitor_log(%{})
        end
        """
        |> parse("lib/holter/monitoring/engine.ex")

      assert RequireBodyguardPermit.run(source) == []
    end
  end

  defp parse(source, filename), do: SourceFile.parse(source, filename)
end
