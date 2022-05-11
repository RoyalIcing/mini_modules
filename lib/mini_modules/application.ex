defmodule MiniModules.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      MiniModulesWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: MiniModules.PubSub},
      # Start the Endpoint (http/https)
      MiniModulesWeb.Endpoint,
      # Start a worker by calling: MiniModules.Worker.start_link(arg)
      # {MiniModules.Worker, arg}
      {Registry, keys: :unique, name: MiniModules.DatabaseRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: MiniModules.DatabaseSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MiniModules.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MiniModulesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
