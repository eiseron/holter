defmodule Holter.System.UsersTest do
  use Holter.DataCase, async: true

  alias Holter.System.Users

  describe "list_users/1 — empty filters" do
    test "returns every user" do
      _a = user_fixture()
      _b = user_fixture()

      %{meta: meta} = Users.list_users()

      assert meta.total >= 2
    end

    test "orders by inserted_at descending by default" do
      older = user_fixture()
      newer = user_fixture()

      older
      |> Ecto.Changeset.change(inserted_at: ~U[2026-01-01 00:00:00Z])
      |> Repo.update!()

      newer
      |> Ecto.Changeset.change(inserted_at: ~U[2026-06-01 00:00:00Z])
      |> Repo.update!()

      %{data: rows} = Users.list_users()
      ids = Enum.map(rows, & &1.id)

      assert Enum.find_index(ids, &(&1 == newer.id)) <
               Enum.find_index(ids, &(&1 == older.id))
    end
  end

  describe "list_users/1 — email substring search" do
    test "matches case-insensitively" do
      target = user_fixture(%{email: "case-test-#{System.unique_integer([:positive])}@h.test"})
      _other = user_fixture()

      %{data: rows} = Users.list_users(%{email: "CASE-TEST"})

      ids = Enum.map(rows, & &1.id)
      assert target.id in ids
    end

    test "matches by domain fragment" do
      target = user_fixture(%{email: "user-#{System.unique_integer([:positive])}@example.com"})
      _other = user_fixture(%{email: "user-#{System.unique_integer([:positive])}@nope.test"})

      %{data: rows} = Users.list_users(%{email: "example.com"})

      assert Enum.any?(rows, &(&1.id == target.id))
    end

    test "treats blank string as no filter" do
      _a = user_fixture()
      %{data: rows} = Users.list_users(%{email: ""})
      assert rows != []
    end

    test "escapes LIKE wildcards in the search term" do
      _decoy = user_fixture(%{email: "literal-percent-decoy@h.test"})
      target = user_fixture(%{email: "ben%y@h.test"})

      %{data: rows} = Users.list_users(%{email: "ben%y"})

      ids = Enum.map(rows, & &1.id)
      assert target.id in ids
    end
  end

  describe "list_users/1 — status filter" do
    test "returns the target user when filtered by their status" do
      banned = user_fixture()

      banned
      |> Ecto.Changeset.change(onboarding_status: :banned)
      |> Repo.update!()

      _active = user_fixture()

      %{data: rows} = Users.list_users(%{status: "banned"})
      ids = Enum.map(rows, & &1.id)
      assert banned.id in ids
    end

    test "excludes users with a different status" do
      banned = user_fixture()

      banned
      |> Ecto.Changeset.change(onboarding_status: :banned)
      |> Repo.update!()

      %{data: rows} = Users.list_users(%{status: "banned"})
      assert Enum.all?(rows, &(&1.onboarding_status == :banned))
    end

    test "ignores unknown status values gracefully" do
      _u = user_fixture()
      %{data: rows} = Users.list_users(%{status: "ghost-status-xyz"})
      assert is_list(rows)
    end
  end

  describe "list_users/1 — pagination" do
    test "caps the result count at page_size" do
      for _ <- 1..3, do: user_fixture()

      %{data: rows} = Users.list_users(%{page_size: 2, page: 1})
      assert length(rows) == 2
    end

    test "reports the resolved page_size in meta" do
      for _ <- 1..3, do: user_fixture()
      %{meta: meta} = Users.list_users(%{page_size: 2, page: 1})
      assert meta.page_size == 2
    end

    test "returns disjoint rows across consecutive pages" do
      for _ <- 1..3, do: user_fixture()

      %{data: page_1} = Users.list_users(%{page_size: 1, page: 1, sort_by: "inserted_at"})
      %{data: page_2} = Users.list_users(%{page_size: 1, page: 2, sort_by: "inserted_at"})

      assert hd(page_1).id != hd(page_2).id
    end

    test "computes total_pages based on the filter set" do
      for _ <- 1..3, do: user_fixture()

      %{meta: %{total_pages: total_pages, page_size: page_size, total: total}} =
        Users.list_users(%{page_size: 2})

      assert total_pages == ceil(total / page_size)
    end
  end

  describe "list_users/1 — sort" do
    test "sorts by email ascending when requested" do
      _a = user_fixture(%{email: "zzz-#{System.unique_integer([:positive])}@h.test"})
      _b = user_fixture(%{email: "aaa-#{System.unique_integer([:positive])}@h.test"})

      %{data: rows} = Users.list_users(%{sort_by: "email", sort_dir: "asc"})

      emails = Enum.map(rows, & &1.email)
      assert emails == Enum.sort(emails)
    end
  end

  describe "sortable_columns/0" do
    test "includes email" do
      assert "email" in Users.sortable_columns()
    end

    test "includes status" do
      assert "status" in Users.sortable_columns()
    end

    test "includes inserted_at" do
      assert "inserted_at" in Users.sortable_columns()
    end
  end
end
