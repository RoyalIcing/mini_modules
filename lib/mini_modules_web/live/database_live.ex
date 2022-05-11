defmodule MiniModulesWeb.DatabaseLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  # See https://blog.appsignal.com/2019/08/13/elixir-alchemy-multiplayer-go-with-registry-pubsub-and-dynamic-supervisors.html

  # alias Phoenix.LiveView.Socket
  # alias MiniModules.{UniversalModules, Fetch}
  # alias MiniModulesWeb.Input.CodeEditorComponent

  alias MiniModules.DatabaseAgent

  @impl true
  def mount(%{"database_id" => database_id}, _session, socket) do
    server_pid =
      case DynamicSupervisor.start_child(
             MiniModules.DatabaseSupervisor,
             {MiniModules.DatabaseAgent,
              name: {:via, Registry, {MiniModules.DatabaseRegistry, database_id}}}
           ) do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid
      end

    current = DatabaseAgent.get_current!(server_pid)

    socket =
      socket
      |> assign(:database_id, database_id)
      |> assign(:server_pid, server_pid)
      |> assign(:current, current)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Hello world <%= inspect(@database_id) %> <%= inspect(@server_pid) %></div>
    <output class="block p-4 bg-green-200"><%= @current %></output>

    <form class="mt-4 flex gap-2">
      <button type="button" phx-click="increment" class="px-2 border">Increment</button>
      <button type="button" phx-click="reload" class="px-2 border">Reload</button>
    </form>
    """
  end

  @impl true
  def handle_event("increment", _, socket) do
    GenServer.cast(socket.assigns.server_pid, :increment)
    {:noreply, socket}
  end

  def handle_event("reload", _, socket) do
    current = GenServer.call(socket.assigns.server_pid, :current)
    socket = socket |> assign(:current, current)
    {:noreply, socket}
  end
end

defmodule MiniModules.DatabaseAgent do
  use GenServer

  def start_link(options) do
    GenServer.start_link(__MODULE__, 0, options)
  end

  @impl true
  def init(n) do
    {:ok, n}
  end

  @impl true
  def handle_call(:current, _from, n) do
    {:reply, n, n}
  end

  @impl true
  def handle_cast(:increment, n) do
    {:noreply, n + 1}
  end

  def get_current!(pid) do
    GenServer.call(pid, :current)
  end

  def increment(pid) do
    GenServer.cast(pid, :increment)
  end
end
