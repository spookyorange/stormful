defmodule Stormful.Repo.Migrations.AddTimezoneToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :timezone, :string, default: "UTC", null: false
    end
  end
end
