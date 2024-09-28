defmodule Stormful.TaskManagement.Todo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "todos" do
    field :description, :string
    field :title, :string
    field :completed_at, :naive_datetime
    field :loose_thought_link, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:title, :description, :completed_at, :loose_thought_link])
    |> validate_required([:title, :loose_thought_link])
  end
end