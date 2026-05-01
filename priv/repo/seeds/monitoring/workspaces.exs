defmodule Holter.Seeds.Monitoring.Workspaces do
  @moduledoc false

  alias Holter.Monitoring.Workspace
  alias Holter.Repo

  def create_default do
    # `min_interval_seconds: 60` so seeded monitors with sub-600s intervals
    # validate cleanly. Mirrors a paid-plan workspace, which is the realistic
    # case reviewers should land on.
    attrs = %{name: "Development", slug: "dev", min_interval_seconds: 60}

    workspace =
      %Workspace{}
      |> Workspace.changeset(attrs)
      |> Repo.insert!()

    IO.puts("[seeds] Created default workspace: dev")
    workspace
  end
end
