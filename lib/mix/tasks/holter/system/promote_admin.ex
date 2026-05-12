defmodule Mix.Tasks.Holter.System.PromoteAdmin do
  @moduledoc """
  Promotes a user to admin (`Holter.System.Models.Admin`).

      mix holter.system.promote_admin alice@holter.test
      mix holter.system.promote_admin guilherme@eiseron.com --actor alice@holter.test

  Bootstrap rules:

    * Without `--actor` AND the `admins` table is empty, the first admin
      is created via `Holter.System.bootstrap_promote!/1`. The audit log
      row carries `actor_type=system` and `actor_id=null`.
    * Without `--actor` AND at least one admin already exists, the task
      refuses — every subsequent promotion must be attributable.
    * With `--actor`, the named admin is loaded and the promotion runs
      through `Holter.System.promote_user/2`, producing an
      `actor_type=admin` audit log row.

  Re-running on a user who is already an active admin is a no-op with
  an informational message.
  """

  @shortdoc "Promote a user to admin (God Mode)"

  use Mix.Task

  import Ecto.Query

  alias Holter.Identity.Models.User
  alias Holter.Repo
  alias Holter.System
  alias Holter.System.Models.Admin

  @switches [actor: :string]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, args, _} = OptionParser.parse(argv, switches: @switches)

    case args do
      [target_email] ->
        promote(target_email, Keyword.get(opts, :actor))

      _ ->
        Mix.shell().error(
          "Usage: mix holter.system.promote_admin <email> [--actor <admin-email>]"
        )

        exit({:shutdown, 1})
    end
  end

  defp promote(target_email, actor_email) do
    case Repo.get_by(User, email: target_email) do
      nil ->
        Mix.shell().error("[ERR] No user with email #{target_email}")
        exit({:shutdown, 1})

      %User{} = target ->
        cond do
          System.admin?(target) ->
            Mix.shell().info("[NOOP] #{target_email} is already an admin")

          is_nil(actor_email) ->
            promote_without_actor(target)

          true ->
            promote_with_actor(target, actor_email)
        end
    end
  end

  defp promote_without_actor(target) do
    if Repo.exists?(Admin) do
      Mix.shell().error(
        "[ERR] Admins already exist. Pass --actor <admin-email> to attribute the promotion."
      )

      exit({:shutdown, 1})
    else
      _admin = System.bootstrap_promote!(target)
      Mix.shell().info("[OK] Bootstrapped first admin: #{target.email}")
    end
  end

  defp promote_with_actor(target, actor_email) do
    actor = load_actor!(actor_email)

    case System.promote_user(target, actor) do
      {:ok, _admin} ->
        Mix.shell().info("[OK] Promoted #{target.email} (actor: #{actor_email})")

      {:error, reason} ->
        Mix.shell().error("[ERR] Could not promote #{target.email}: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp load_actor!(actor_email) do
    case Repo.get_by(User, email: actor_email) do
      nil ->
        Mix.shell().error("[ERR] Actor email #{actor_email} not found")
        exit({:shutdown, 1})

      %User{} = user ->
        active_admin_query =
          from a in Admin,
            where: a.user_id == ^user.id and is_nil(a.revoked_at)

        case Repo.one(active_admin_query) do
          nil ->
            Mix.shell().error("[ERR] Actor #{actor_email} is not an active admin")
            exit({:shutdown, 1})

          admin ->
            admin
        end
    end
  end
end
