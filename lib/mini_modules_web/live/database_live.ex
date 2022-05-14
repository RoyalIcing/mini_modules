defmodule MiniModulesWeb.DatabaseLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  # See https://blog.appsignal.com/2019/08/13/elixir-alchemy-multiplayer-go-with-registry-pubsub-and-dynamic-supervisors.html

  # alias Phoenix.LiveView.Socket
  # alias MiniModules.{UniversalModules, Fetch}
  # alias MiniModulesWeb.Input.CodeEditorComponent

  alias MiniModulesWeb.Endpoint
  alias MiniModules.DatabaseAgent, as: Model

  defp refresh_data(socket) do
    model_pid = socket.assigns[:model_pid]
    table_name = socket.assigns[:table_name]

    current = Model.get_current!(model_pid)
    all_tables = Model.show_tables!(socket.assigns.model_pid)

    list_table =
      case table_name do
        nil ->
          nil

        s ->
          Model.list_table(model_pid, s)
      end

    socket
    |> assign(%{
      current: current,
      list_table: list_table,
      all_tables: all_tables
    })
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:query_result, nil)
      |> assign(:changed_rows, nil)

    {:ok, socket}
  end

  defp path_to(database_id, table_name) do
    case table_name do
      nil ->
        Routes.database_path(Endpoint, :index, database_id)

      table_name ->
        Routes.database_path(Endpoint, :index, database_id, table_name)
    end
  end

  @impl true
  def handle_params(%{"database_id" => database_id} = params, _uri, socket) do
    table_name = params["table_name"]

    model_pid =
      case Model.start(database_id) do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid
      end

    current_path = path_to(database_id, table_name)
    database_path = path_to(database_id, nil)

    socket =
      socket
      |> assign(:current_path, current_path)
      |> assign(:database_path, database_path)
      |> assign(:database_id, database_id)
      |> assign(:table_name, table_name)
      |> assign(:model_pid, model_pid)

    socket = refresh_data(socket)
    {:noreply, socket}
  end

  def table_link(%{
        database_id: database_id,
        table_name: table_name,
        current_path: current_path,
        inner_block: inner_block
      }) do
    # opts = assigns |> assigns_to_attributes() |> Keyword.put(:to, to)

    path = path_to(database_id, table_name)
    aria_current = if current_path == path, do: "page", else: "false"

    class =
      "block px-4 py-2 text-black bg-white hover:bg-blue-100 current:bg-blue-500 current:text-white"

    opts = [to: path, class: class, aria_current: aria_current]
    # assign(assigns, :opts, opts)
    assigns = %{opts: opts, inner_block: inner_block}

    ~H"""
    <%= live_patch @opts do %><%= render_slot(@inner_block) %><% end %>
    """
  end

  def table_link(%{database_id: _, inner_block: _} = assigns),
    do: table_link(Map.put(assigns, :table_name, nil))

  # do: table_link(%{assigns | table_name: nil})

  @impl true
  def render(assigns) do
    ~H"""
    <form class="mt-4 px-4 pb-4 flex gap-2">
      <button type="button" phx-click="create_table_sqlar" class="px-2 bg-gray-100 border rounded shadow-sm">Create SQL Archive Table</button>
    </form>
    <div class="text-right opacity-50">Hello world <%= inspect(@database_id) %> <%= inspect(@model_pid) %></div>

    <form phx-submit="submit_query" class="mb-4">
      <textarea id="query-textbox" name="query" cols="60" rows="6" placeholder="Enter SQL…" phx-update="ignore" class="w-full border"></textarea>
      <div class="flex px-4 gap-4">
        <button type="submit" phx-disable-with="Querying..." class="px-2 text-black bg-blue-300 border border-blue-400 rounded">Query</button>
        <details class="relative" hidden>
          <summary class="block px-2 text-black bg-blue-300 border border-blue-400 rounded">Quickly Create</summary>
          <details-menu role="menu" class="absolute top-full left-0 flex flex-col px-4 py-2 text-left whitespace-nowrap bg-white rounded shadow-lg">
            <button type="button" role="menuitem">select datetime()</button>
            <button type="button" role="menuitem">Bender</button>
            <button type="button" role="menuitem">BB-8</button>
          </details-menu>
        </details>
      </div>
    </form>

    <%= if ok?(@query_result) do %>
      <section aria-labelledby="result-success-heading" class="flex-1 pl-8 pt-4 bg-green-100">
        <details open>
          <summary class="block cursor-pointer">
            <h2 id="result-success-heading" class="pb-4 text-sm uppercase font-bold text-green-600">Results</h2>
          </summary>
          <div class="prose lg:prose-lg">
            <.query_result_table cols={get_cols(@query_result)} rows={get_rows(@query_result)} />
          </div>
        </details>
      </section>
    <% end %>
    <%= if @changed_rows do %>
      <output class="block p-4 bg-green-200"><%= @changed_rows %> rows changed</output>
    <% end %>
    <%= if error?(@query_result) do %>
      <output class="block p-4 bg-red-200">
        <h2 id="result-error-heading" class="pb-4 text-sm uppercase font-bold text-red-700">Error</h2>
        <%= inspect(@query_result) %>
      </output>
    <% end %>

    <section aria-label="Tables" class="flex w-full divide-x">
      <%= if @all_tables do %>
        <nav aria-labelledby="all-tables-heading" class="w-full max-w-sm">
          <h2 id="all-tables-heading" class="px-4 py-4 text-sm uppercase font-bold text-gray-500">All Tables</h2>
          <ul>
            <li>
              <.table_link database_id={@database_id} current_path={@current_path}>[root]</.table_link>
            </li>
            <%= for [table_name, _] <- get_rows(@all_tables) do %>
              <li>
                <.table_link database_id={@database_id} table_name={table_name} current_path={@current_path}><%= table_name %></.table_link>
              </li>
            <% end %>
          </ul>
        </nav>
      <% end %>

      <%= if @table_name == nil do %>
        <div class="flex-1 pl-8 pt-4 prose lg:prose-lg">
          <dl>
            <dt class="font-bold">Database ID</dt>
            <dd><%= @database_id %></dd>
          </dl>
        </div>
      <% end %>

      <%= if @list_table do %>
        <div class="flex-1 pl-8 pt-4 prose lg:prose-lg">
          <h1><%= @table_name %></h1>
          <.query_result_table cols={get_cols(@list_table)} rows={get_rows(@list_table)} />
        </div>
      <% end %>
    </section>
    """
  end

  defp query_result_table(assigns) do
    ~H"""
    <table>
      <thead>
        <tr>
          <%= for name <- @cols do %>
            <td><%= name %></td>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @rows do %>
          <tr>
            <%= for value <- row do %>
              <td><%= inspect(value) %></td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp ok?({:ok, _}), do: true
  defp ok?(_), do: false
  defp error?({:error, _}), do: true
  defp error?(_), do: false
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
    result = Model.run_query(socket.assigns.model_pid, query)
    socket = socket |> assign(%{query_result: result})
    socket = refresh_data(socket)

    {:noreply, socket}
  end
end

defmodule MiniModules.DatabaseAgent do
  use GenServer

  @select_all_tables "SELECT tbl_name, sql FROM sqlite_master WHERE type = 'table'"
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
         {:ok, rows} <- Exqlite.Sqlite3.fetch_all(db_conn, statement),
         {:ok, columns} <- Exqlite.Sqlite3.columns(db_conn, statement) do
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
