defmodule Stormful.Queue.Job do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(pending processing completed failed rate_limited)
  @valid_task_types ~w(email ai_processing)

  schema "queue_jobs" do
    field :task_type, :string
    field :status, :string, default: "pending"
    field :payload, :map
    field :priority, :integer, default: 1
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 3
    field :scheduled_at, :utc_datetime
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_message, :string
    field :rate_limit_key, :string

    belongs_to :user, Stormful.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :task_type,
      :status,
      :payload,
      :priority,
      :attempts,
      :max_attempts,
      :scheduled_at,
      :started_at,
      :completed_at,
      :error_message,
      :rate_limit_key,
      :user_id
    ])
    |> validate_required([:task_type, :payload])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:task_type, @valid_task_types)
    |> validate_number(:priority, greater_than: 0)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_number(:max_attempts, greater_than: 0)
    |> validate_payload()
    |> set_rate_limit_key()
    |> set_scheduled_at()
  end

  @doc """
  Changeset for creating a new job
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @doc """
  Changeset for updating job status during processing
  """
  def status_changeset(job, status, attrs \\ %{}) do
    job
    |> cast(attrs, [:status, :started_at, :completed_at, :error_message, :attempts])
    |> put_change(:status, status)
    |> validate_inclusion(:status, @valid_statuses)
    |> set_timestamps_for_status(status)
  end

  # Private functions

  defp validate_payload(changeset) do
    case get_field(changeset, :payload) do
      nil -> changeset
      payload when is_map(payload) -> changeset
      _ -> add_error(changeset, :payload, "must be a valid map")
    end
  end

  defp set_rate_limit_key(changeset) do
    case get_field(changeset, :task_type) do
      "email" -> put_change(changeset, :rate_limit_key, "email")
      "ai_processing" -> put_change(changeset, :rate_limit_key, "ai")
      _ -> changeset
    end
  end

  defp set_scheduled_at(changeset) do
    case get_field(changeset, :scheduled_at) do
      nil ->
        # Truncate microseconds for PostgreSQL compatibility
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        put_change(changeset, :scheduled_at, now)
      _ -> changeset
    end
  end

  defp set_timestamps_for_status(changeset, status) do
    # Truncate microseconds for PostgreSQL compatibility
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case status do
      "processing" ->
        put_change(changeset, :started_at, now)

      status when status in ["completed", "failed"] ->
        put_change(changeset, :completed_at, now)

      _ ->
        changeset
    end
  end

  @doc """
  Returns jobs ready to be processed (pending status and scheduled time has passed)
  """
  def ready_for_processing_query do
    import Ecto.Query

    from j in __MODULE__,
      where: j.status == "pending" and j.scheduled_at <= ^DateTime.utc_now(),
      order_by: [asc: j.scheduled_at, asc: j.inserted_at]
  end

  @doc """
  Returns failed jobs that can be retried
  """
  def retriable_query do
    import Ecto.Query

    from j in __MODULE__,
      where: j.status == "failed" and j.attempts < j.max_attempts
  end
end
