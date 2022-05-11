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
      |> assign(:query_result, nil)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Hello world <%= inspect(@database_id) %> <%= inspect(@server_pid) %></div>
    <output class="block p-4 bg-green-200"><%= @current %></output>
    <output class="block p-4 bg-green-200"><%= inspect(@query_result) %></output>
    <%= if @error do %>
      <output class="block p-4 bg-red-200"><%= inspect(@error) %></output>
    <% end %>

    <form class="mt-4 flex gap-2">
      <button type="button" phx-click="increment" class="px-2 border">Increment</button>
      <button type="button" phx-click="reload" class="px-2 border">Reload</button>
      <button type="button" phx-click="show_tables" class="px-2 border">Show Tables</button>
      <button type="button" phx-click="create_table_sqlar" class="px-2 border">Create SQL Archive Table</button>
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

  def handle_event("show_tables", _, socket) do
    result = GenServer.call(socket.assigns.server_pid, :show_tables)
    socket = socket |> assign(:query_result, result)
    {:noreply, socket}
  end

  def handle_event("create_table_sqlar", _, socket) do
    socket =
      case GenServer.call(socket.assigns.server_pid, :create_table_sqlar) do
        {:ok, changes} ->
          socket |> assign(:changes, changes)

        {:error, reason} ->
          socket |> assign(:error, reason)
      end

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
    {:ok, db_conn} = Exqlite.Sqlite3.open(":memory:")
    {:ok, %{n: n, db_conn: db_conn}}
  end

  @impl true
  def handle_call(:current, _from, %{n: n} = state) do
    {:reply, n, state}
  end

  @impl true
  def handle_call(:show_tables, _from, %{db_conn: db_conn} = state) do
    {:ok, statement} =
      Exqlite.Sqlite3.prepare(db_conn, "SELECT * FROM sqlite_master WHERE type = 'table'")

    {:ok, rows} = Exqlite.Sqlite3.fetch_all(db_conn, statement)
    {:reply, rows, state}
  end

  @impl true
  def handle_call(:create_table_sqlar, _from, %{db_conn: db_conn} = state) do
    case Exqlite.Sqlite3.execute(
           db_conn,
           "CREATE TABLE sqlar(name TEXT PRIMARY KEY, mode INT, mtime INT, sz INT, data BLOB)"
         ) do
      :ok ->
        changes = Exqlite.Sqlite3.changes(db_conn)
        {:reply, {:ok, changes}, state}

      {:error, _reason} = result ->
        {:reply, result, state}
    end
  end

  @impl true
  def handle_cast(:increment, %{n: n} = state) do
    {:noreply, %{state | n: n + 1}}
  end

  @impl true
  def terminate(_reason, %{db_conn: db_conn}) do
    Exqlite.Sqlite3.close(db_conn)
  end

  def get_current!(pid) do
    GenServer.call(pid, :current)
  end

  def show_tables!(pid) do
    GenServer.call(pid, :show_tables)
  end

  def create_table_sqlar!(pid) do
    GenServer.call(pid, :create_table_sqlar)
  end

  def increment(pid) do
    GenServer.cast(pid, :increment)
  end
end
