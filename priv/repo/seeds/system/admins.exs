defmodule Holter.Seeds.System.Admins do
  @moduledoc false

  alias Holter.Identity.Models.User
  alias Holter.Repo
  alias Holter.System
  alias Holter.System.Models.Admin

  def bootstrap_dev(%User{} = user) do
    if Repo.aggregate(Admin, :count) == 0 do
      _admin = System.bootstrap_promote!(user)
      IO.puts("[seeds] Promoted dev user #{user.email} to admin (bootstrap)")
    else
      :noop
    end
  end
end
