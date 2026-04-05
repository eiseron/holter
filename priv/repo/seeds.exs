# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Holter.Repo.insert!(%Holter.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Holter.Monitoring.Workspace
alias Holter.Repo

# Create a default workspace for development if none exists.
if Repo.aggregate(Workspace, :count) == 0 do
  %Workspace{}
  |> Workspace.changeset(%{name: "Development", slug: "dev"})
  |> Repo.insert!()

  IO.puts("[seeds] Created default workspace: dev")
end
