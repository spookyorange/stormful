defmodule Stormful.Repo.Migrations.CreateQueueJobs do
  use Ecto.Migration

  def change do
    create table(:queue_jobs) do
      add :task_type, :string, null: false # "email", "ai_processing", etc.
      add :status, :string, null: false, default: "pending" # "pending", "processing", "completed", "failed", "rate_limited"
      add :payload, :map, null: false # JSON data for the task
      add :priority, :integer, default: 1 # Future use for priority queues
      add :attempts, :integer, default: 0 # Number of retry attempts
      add :max_attempts, :integer, default: 3 # Maximum retry attempts
      add :scheduled_at, :utc_datetime # When to run the job (for delayed jobs)
      add :started_at, :utc_datetime # When processing started
      add :completed_at, :utc_datetime # When job completed/failed
      add :error_message, :text # Error details for failed jobs
      add :rate_limit_key, :string # Key for rate limiting (e.g., "email", "ai")
      add :user_id, references(:users, on_delete: :delete_all) # Optional user association

      timestamps()
    end

    create index(:queue_jobs, [:status])
    create index(:queue_jobs, [:task_type])
    create index(:queue_jobs, [:scheduled_at])
    create index(:queue_jobs, [:rate_limit_key])
    create index(:queue_jobs, [:user_id])
    create index(:queue_jobs, [:status, :scheduled_at])
  end
end
