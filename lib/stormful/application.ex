defmodule Stormful.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StormfulWeb.Telemetry,
      Stormful.Repo,
      {DNSCluster, query: Application.get_env(:stormful, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Stormful.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Stormful.Finch},
      # Start the Queue Processor for background jobs
      {Stormful.Queue.Processor, []},
      # Start a worker by calling: Stormful.Worker.start_link(arg)
      # {Stormful.Worker, arg},
      # Start to serve requests, typically the last entry
      StormfulWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Stormful.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StormfulWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
