defmodule Holter.Security.RlsWorkspaceMembershipsTest do
  use Holter.DataCase, async: false

  alias Holter.Identity.Memberships
  alias Holter.Identity.WorkspaceMembership
  alias Holter.Repo

  setup do
    user_a = user_fixture()
    user_b = user_fixture()
    workspace_a = workspace_fixture(%{owner: user_a, name: "Alpha"})
    _workspace_b = workspace_fixture(%{owner: user_b, name: "Beta"})

    membership_a =
      Repo.one!(
        Ecto.Query.from(m in WorkspaceMembership,
          where: m.user_id == ^user_a.id and m.workspace_id == ^workspace_a.id
        )
      )

    %{
      user_a: user_a,
      user_b: user_b,
      workspace_a: workspace_a,
      membership_a: membership_a
    }
  end

  describe "USING policy (read path, keyed on user_id)" do
    test "as holter_app with another user set, the membership row is invisible",
         %{user_b: user_b, membership_a: membership_a} do
      result =
        run_as_app(user_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM workspace_memberships WHERE id = $1", [
              uuid_dump(membership_a.id)
            ])

          rows
        end)

      assert {:ok, []} = result
    end

    test "as holter_app with the matching user set, the membership row is visible",
         %{user_a: user_a, membership_a: membership_a} do
      result =
        run_as_app(user_a.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM workspace_memberships WHERE id = $1", [
              uuid_dump(membership_a.id)
            ])

          rows
        end)

      assert {:ok, [[_id]]} = result
    end

    test "as holter_app with no user set, the membership row is invisible",
         %{membership_a: membership_a} do
      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])

          %{rows: rows} =
            Repo.query!("SELECT id FROM workspace_memberships WHERE id = $1", [
              uuid_dump(membership_a.id)
            ])

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, []} = result
    end
  end

  describe "WITH CHECK policy (write path, keyed on user_id)" do
    test "as holter_app, INSERTing a membership for a different user_id raises 42501",
         %{user_a: user_a, user_b: user_b, workspace_a: workspace_a} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(user_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO workspace_memberships (id, user_id, workspace_id, role, inserted_at, updated_at)
            VALUES ($1, $2, $3, 'member', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(user_b.id),
              uuid_dump(workspace_a.id)
            ]
          )
        end)
      end
    end

    test "as holter_app, UPDATEing a membership to point at a different user_id raises 42501",
         %{user_a: user_a, user_b: user_b, membership_a: membership_a} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(user_a.id, fn ->
          Repo.query!(
            "UPDATE workspace_memberships SET user_id = $1 WHERE id = $2",
            [uuid_dump(user_b.id), uuid_dump(membership_a.id)]
          )
        end)
      end
    end
  end

  describe "Memberships context (with_user wrapper transparently passes through)" do
    test "Memberships.member?/2 returns true through the with_user wrapper", %{
      user_a: user_a,
      workspace_a: workspace_a
    } do
      assert Memberships.member?(user_a, workspace_a)
    end

    test "Memberships.list_workspaces_for_user/1 returns the caller's workspaces",
         %{user_a: user_a, workspace_a: workspace_a} do
      ids = user_a |> Memberships.list_workspaces_for_user() |> Enum.map(& &1.id)

      assert workspace_a.id in ids
    end

    test "Memberships.list_workspaces_for_user/1 does not leak another user's workspaces",
         %{user_b: user_b, workspace_a: workspace_a} do
      user_b_workspace_ids =
        user_b |> Memberships.list_workspaces_for_user() |> Enum.map(& &1.id)

      refute workspace_a.id in user_b_workspace_ids
    end
  end

  defp run_as_app(user_id, fun) do
    Repo.transaction(fn ->
      Repo.query!("SET LOCAL ROLE holter_app", [])
      Repo.query!("SELECT set_config('app.current_user_id', $1, true)", [user_id])
      result = fun.()
      Repo.query!("RESET ROLE", [])
      result
    end)
  end

  defp run_as_app!(user_id, fun) do
    case run_as_app(user_id, fun) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  defp uuid_dump(uuid) do
    {:ok, raw} = Ecto.UUID.dump(uuid)
    raw
  end
end
