defmodule Holter.Repo.Migrations.AddAntiPhishingCodeToEmailChannels do
  use Ecto.Migration

  import Ecto.Query

  @alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

  def up do
    alter table(:email_channels) do
      add :anti_phishing_code, :string
    end

    flush()

    Holter.Repo.transaction(fn ->
      "email_channels"
      |> select([e], e.id)
      |> Holter.Repo.all()
      |> Enum.each(fn id ->
        Holter.Repo.update_all(
          from(e in "email_channels", where: e.id == ^id),
          set: [anti_phishing_code: generate_code()]
        )
      end)
    end)

    alter table(:email_channels) do
      modify :anti_phishing_code, :string, null: false
    end
  end

  def down do
    alter table(:email_channels) do
      remove :anti_phishing_code
    end
  end

  defp generate_code do
    len = length(@alphabet)
    chars = for _ <- 1..8, do: Enum.at(@alphabet, :rand.uniform(len) - 1)
    {a, b} = Enum.split(chars, 4)
    "#{List.to_string(a)}-#{List.to_string(b)}"
  end
end
