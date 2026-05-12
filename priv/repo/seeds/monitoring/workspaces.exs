defmodule Holter.Seeds.Monitoring.Workspaces do
  @moduledoc false

  alias Holter.Monitoring

  def create_default do
    attrs = %{
      name: "Development",
      slug: "dev",
      min_interval_seconds: 60,
      default_locale: "pt_BR"
    }

    {:ok, workspace} = Monitoring.create_workspace(attrs)
    IO.puts("[seeds] Created default workspace: dev")
    workspace
  end

  def create_secondary do
    attrs = %{
      name: "Development (EN)",
      slug: "dev-en",
      min_interval_seconds: 60,
      default_locale: "en"
    }

    {:ok, workspace} = Monitoring.create_workspace(attrs)
    IO.puts("[seeds] Created secondary workspace: dev-en")
    workspace
  end
end
