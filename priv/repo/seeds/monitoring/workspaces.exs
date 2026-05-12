defmodule Holter.Seeds.Monitoring.Workspaces do
  @moduledoc false

  alias Holter.Monitoring

  def create_default do
    attrs = %{
      name: "Development",
      slug: "dev",
      min_interval_seconds: 60,
      default_locale: "pt_BR",
      max_monitors: 10,
      max_channels: 6
    }

    {:ok, workspace} = Monitoring.create_workspace(attrs)
    IO.puts("[seeds] Created default workspace: dev (Pro placeholder, 10 monitors / 6 channels)")
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
    IO.puts("[seeds] Created secondary workspace: dev-en (Free placeholder, default 3/2 caps)")
    workspace
  end
end
