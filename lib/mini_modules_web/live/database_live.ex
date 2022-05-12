defmodule MiniModulesWeb.DatabaseLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  # See https://blog.appsignal.com/2019/08/13/elixir-alchemy-multiplayer-go-with-registry-pubsub-and-dynamic-supervisors.html

  # alias Phoenix.LiveView.Socket
  # alias MiniModules.{UniversalModules, Fetch}
  # alias MiniModulesWeb.Input.CodeEditorComponent

  alias MiniModules.DatabaseAgent, as: Model

  @impl true
  def mount(%{"database_id" => database_id} = params, _session, socket) do
    table_name = params["table_name"]

    model_pid =
      case Model.start(database_id) do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid
      end

    current = Model.get_current!(model_pid)

    list_table =
      case table_name do
        nil ->
          nil

        s ->
          Model.list_table(model_pid, s)
      end

    socket =
      socket
      |> assign(:database_id, database_id)
      |> assign(:table_name, table_name)
      |> assign(:model_pid, model_pid)
      |> assign(:current, current)
      |> assign(:error, nil)
      |> assign(:query_result, nil)
      |> assign(:list_table, list_table)
      |> assign(:changed_rows, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form class="mt-4 pb-4 flex gap-2">
      <button type="button" phx-click="increment" class="px-2 border">Increment</button>
      <button type="button" phx-click="reload" class="px-2 border">Reload</button>
      <button type="button" phx-click="show_tables" class="px-2 border">Show Tables</button>
      <button type="button" phx-click="create_table_sqlar" class="px-2 border">Create SQL Archive Table</button>
    </form>
    <div>Hello world <%= inspect(@database_id) %> <%= inspect(@model_pid) %></div>

    <form phx-submit="submit_query" class="mb-4">
      <textarea id="query-textbox" name="query" cols="60" rows="6" placeholder="Enter SQL…" phx-update="ignore" class="w-full border"></textarea>
      <button type="submit" phx-disable-with="Querying..." class="px-2 border">Query</button>
    </form>

    <output class="block p-4 bg-green-200"><%= @current %></output>
    <output class="block p-4 bg-green-200"><%= @changed_rows %></output>
    <output class="block p-4 bg-green-200"><%= inspect(@query_result) %></output>
    <%= if @error do %>
      <output class="block p-4 bg-red-200"><%= inspect(@error) %></output>
    <% end %>

    <%= if @list_table do %>
      <div class="prose lg:prose-lg mx-auto">
        <h1><%= @table_name %></h1>
        <table>
          <thead>
            <tr>
              <%= for name <- get_cols(@list_table) do %>
                <td><%= name %></td>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for row <- get_rows(@list_table) do %>
              <tr>
                <%= for value <- row do %>
                  <td><%= inspect(value) %></td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  defp get_cols({:ok, {cols, _rows}}), do: cols
  defp get_cols(_), do: []
  defp get_rows({:ok, {_cols, rows}}), do: rows
  defp get_rows(_), do: []

  @impl true
  def handle_event("increment", _, socket) do
    Model.increment(socket.assigns.model_pid)
    {:noreply, socket}
  end

  def handle_event("reload", _, socket) do
    current = Model.get_current!(socket.assigns.model_pid)
    socket = socket |> assign(:current, current)
    {:noreply, socket}
  end

  def handle_event("show_tables", _, socket) do
    {:ok, result} = Model.show_tables!(socket.assigns.model_pid)
    socket = socket |> assign(:query_result, result)
    {:noreply, socket}
  end

  def handle_event("create_table_sqlar", _, socket) do
    socket =
      case Model.create_table_sqlar!(socket.assigns.model_pid) do
        {:ok, changes} ->
          socket |> assign(:changed_rows, changes)

        {:error, reason} ->
          socket |> assign(:error, reason)
      end

    {:noreply, socket}
  end

  def handle_event("submit_query", %{"query" => query}, socket) do
    socket =
      case Model.run_query(socket.assigns.model_pid, query) do
        {:ok, result} ->
          socket |> assign(%{query_result: result, error: nil})

        {:error, reason} ->
          socket |> assign(:error, reason)
      end

    {:noreply, socket}
  end
end

defmodule MiniModules.DatabaseAgent do
  use GenServer

  @select_all_tables "SELECT * FROM sqlite_master WHERE type = 'table'"
  @create_table_sqlar """
  CREATE TABLE sqlar(name TEXT PRIMARY KEY, mode INT, mtime INT, sz INT, data BLOB)
  """

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
  def handle_call({:run_query, query}, from, state) do
    handle_call({:run_query, query, []}, from, state)
  end

  @impl true
  def handle_call({:run_query, query, bindings}, _from, %{db_conn: db_conn} = state) do
    with {:ok, statement} <- Exqlite.Sqlite3.prepare(db_conn, query),
         :ok <- Exqlite.Sqlite3.bind(db_conn, statement, bindings),
         {:ok, rows} = Exqlite.Sqlite3.fetch_all(db_conn, statement),
         {:ok, columns} = Exqlite.Sqlite3.columns(db_conn, statement) do
      {:reply, {:ok, {columns, rows}}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:show_tables, from, state) do
    handle_call({:run_query, @select_all_tables}, from, state)
  end

  @impl true
  def handle_call({:list_table, table_name}, from, state) do
    handle_call({:run_query, ~s{select * from "#{table_name}"}}, from, state)
  end

  @impl true
  def handle_call(:create_table_sqlar, _from, %{db_conn: db_conn} = state) do
    case Exqlite.Sqlite3.execute(db_conn, @create_table_sqlar) do
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

  def start(name) do
    DynamicSupervisor.start_child(
      MiniModules.DatabaseSupervisor,
      {__MODULE__, name: {:via, Registry, {MiniModules.DatabaseRegistry, name}}}
    )
  end

  def get_current!(pid) do
    GenServer.call(pid, :current)
  end

  def show_tables!(pid) do
    GenServer.call(pid, :show_tables)
  end

  def list_table(pid, table_name) do
    GenServer.call(pid, {:list_table, table_name})
  end

  def run_query(pid, query) do
    GenServer.call(pid, {:run_query, query})
  end

  def create_table_sqlar!(pid) do
    GenServer.call(pid, :create_table_sqlar)
  end

  def increment(pid) do
    GenServer.cast(pid, :increment)
  end
end
