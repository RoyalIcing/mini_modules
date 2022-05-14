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
  def mount(%{"database_id" => database_id}, _session, socket) do
    socket =
      socket
      |> assign(:query_result, nil)
      |> assign(:changed_rows, nil)

    if connected?(socket) do
      Model.subscribe(database_id)
    end

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

    model_pid = Model.start_dynamic(database_id)

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
      "block px-4 py-2 text-black border-l-8 border-white hover:text-blue-800 hover:bg-blue-100 hover:border-blue-300 current:text-blue-800 current:bg-blue-100 current:border-blue-700"

    opts = [to: path, class: class, aria_current: aria_current]
    # assign(assigns, :opts, opts)
    assigns = %{opts: opts, inner_block: inner_block}

    ~H"""
    <%= live_patch @opts do %><%= render_slot(@inner_block) %><% end %>
    """
  end

  def table_link(%{database_id: _, inner_block: _} = assigns),
    do: table_link(Map.put(assigns, :table_name, nil))

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-right opacity-50">debug <%= inspect(@database_id) %> <%= inspect(@model_pid) %></div>

    <form id="sql-form" phx-submit="submit_query" class="pb-4 px-6 bg-gray-50">
      <textarea id="query-textbox" name="query" cols="60" rows="6" placeholder="Enter SQL…" phx-update="ignore" class="w-full font-mono text-lg text-blue-800 border"></textarea>
      <div class="flex gap-4 items-center">
        <button type="submit" phx-disable-with="Running..." class="px-2 text-lg text-white bg-blue-600 border border-blue-700 rounded" name="query" value="query">Run</button>
        <fieldset class="flex gap-4">
          <label><input type="radio" name="type" value="query" checked> Read-only Query</label>
          <label><input type="radio" name="type" value="statements"> Execute Multiple Statements</label>
        </fieldset>
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
      <section aria-labelledby="result-success-heading" class="flex-1 pl-6 pt-4 pb-4 bg-green-100">
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
    <%= if @changed_rows && false do %>
      <output class="block px-6 py-4 bg-green-200"><%= @changed_rows %> rows changed</output>
    <% end %>
    <%= if error?(@query_result) do %>
      <output class="block px-6 py-4 bg-red-200">
        <h2 id="result-error-heading" class="pb-4 text-sm uppercase font-bold text-red-700">Error</h2>
        <div class="prose lg:prose-lg">
          <%= inspect(@query_result) %>
        </div>
      </output>
    <% end %>

    <section aria-label="Tables" class="flex w-full divide-x border-t border-gray-400">
      <%= if @all_tables do %>
        <nav aria-labelledby="all-tables-heading" class="w-full min-h-screen max-w-sm pt-4 bg-gray-50">
          <ul>
            <li>
              <.table_link database_id={@database_id} current_path={@current_path}>Database info</.table_link>
            </li>
          </ul>
          <h2 id="all-tables-heading" class="pl-6 pr-4 py-4 text-sm uppercase font-bold text-gray-500">Tables</h2>
          <ul>
            <%= for [table_name, _] <- get_rows(@all_tables) do %>
              <li>
                <.table_link database_id={@database_id} table_name={table_name} current_path={@current_path}><%= table_name %></.table_link>
              </li>
            <% end %>
          </ul>
          <form class="pt-16 px-4 pb-4 flex gap-2">
            <button type="button" phx-click="create_table_sqlar" class="px-2 bg-white border border-gray-400 rounded shadow-sm">Create SQL Archive Table</button>
          </form>
        </nav>
      <% end %>

      <%= if @table_name == nil do %>
        <div class="flex-1 pl-8 pt-4 prose lg:prose-lg">
          <h1>Database <%= @database_id %></h1>
          <p class="italic">Choose a table from the sidebar.</p>
        </div>
      <% end %>

      <%= if @list_table do %>
        <div class="flex-1 pl-8 pt-4 prose lg:prose-lg">
          <h1><%= @table_name %></h1>
          <p><%= get_count(@list_table) %> rows</p>
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
  defp get_count({:ok, %{count: count}}), do: count
  defp get_count(_), do: nil
  defp get_cols({:ok, %{values: values}}), do: get_cols({:ok, values})
  defp get_cols({:ok, {cols, _rows}}), do: cols
  defp get_cols(_), do: []
  defp get_rows({:ok, %{values: values}}), do: get_rows({:ok, values})
  defp get_rows({:ok, {_cols, rows}}), do: rows
  defp get_rows(_), do: []

  defp execute_statements(sql, socket) do
    socket =
      case Model.execute_statements(socket.assigns.model_pid, sql) do
        {:error, _reason} = result ->
          socket |> assign(:query_result, result)

        {:ok, changed_rows} ->
          socket |> assign(:changed_rows, changed_rows)
      end

    socket = refresh_data(socket)

    {:noreply, socket}
  end

  defp run_query(sql, socket) do
    result = Model.run_query(socket.assigns.model_pid, sql)
    socket = socket |> assign(%{query_result: result})
    socket = refresh_data(socket)

    {:noreply, socket}
  end

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

  def handle_event("create_table_sqlar", _, socket) do
    socket =
      case Model.create_table_sqlar!(socket.assigns.model_pid) do
        {:ok, changed_rows} ->
          socket |> assign(:changed_rows, changed_rows)

        {:error, _reason} = result ->
          socket |> assign(:query_result, result)
      end

    socket = refresh_data(socket)

    {:noreply, socket}
  end

  def handle_event("submit_query", %{"type" => "statements", "query" => sql}, socket),
    do: execute_statements(sql, socket)

  def handle_event("submit_query", %{"query" => sql}, socket),
    do: run_query(sql, socket)

  @impl true
  def handle_info({Model, _}, socket) do
    IO.puts("MODEL CHANGED!!!!")
    socket = refresh_data(socket)
    {:noreply, socket}
  end
end

defmodule MiniModules.DatabaseAgent do
  use GenServer

  @pubsub MiniModules.PubSub

  @select_all_tables "SELECT tbl_name, sql FROM sqlite_master WHERE type = 'table'"
  @create_table_sqlar """
  CREATE TABLE sqlar(name TEXT PRIMARY KEY, mode INT, mtime INT, sz INT, data BLOB)
  """

  def start_link(database_id) do
    IO.puts("start_link")
    IO.inspect(database_id)
    GenServer.start_link(__MODULE__, %{database_id: database_id}, name: process_name(database_id))
  end

  defp process_name(database_id),
    do: {:via, Registry, {MiniModules.DatabaseRegistry, database_id}}

  @impl true
  def init(%{database_id: database_id}) do
    {:ok, db_conn} = Exqlite.Sqlite3.open(":memory:")
    {:ok, %{n: 0, database_id: database_id, db_conn: db_conn}}
  end

  defp internal_run_query(db_conn, query, bindings) do
    with {:ok, statement} <- Exqlite.Sqlite3.prepare(db_conn, query),
         :ok <- Exqlite.Sqlite3.bind(db_conn, statement, bindings),
         :ok <- Exqlite.Sqlite3.execute(db_conn, "PRAGMA query_only = true;"),
         {:ok, rows} <- Exqlite.Sqlite3.fetch_all(db_conn, statement),
         {:ok, columns} <- Exqlite.Sqlite3.columns(db_conn, statement),
         :ok <- Exqlite.Sqlite3.execute(db_conn, "PRAGMA query_only = false;"),
         :ok <- Exqlite.Sqlite3.release(db_conn, statement) do
      {:ok, {columns, rows}}
    else
      {:error, reason} ->
        {:error, reason}
    end
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
    IO.inspect(Process.get())
    result = internal_run_query(db_conn, query, bindings)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:execute, sql}, _from, %{db_conn: db_conn, database_id: database_id} = state) do
    case Exqlite.Sqlite3.execute(db_conn, sql) do
      :ok ->
        changes = Exqlite.Sqlite3.changes(db_conn)
        broadcast(database_id)
        {:reply, {:ok, changes}, state}

      {:error, _reason} = result ->
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call(:show_tables, from, state) do
    handle_call({:run_query, @select_all_tables}, from, state)
  end

  @impl true
  def handle_call({:list_table, table_name}, _from, %{db_conn: db_conn} = state) do
    with {:ok, {_, [[count]]}} <-
           internal_run_query(db_conn, ~s{select count(*) from "#{table_name}"}, []),
         {:ok, values} <- internal_run_query(db_conn, ~s{select * from "#{table_name}"}, []) do
      {:reply, {:ok, %{count: count, values: values}}, state}
    end
  end

  @impl true
  def handle_call(:create_table_sqlar, from, state),
    do: handle_call({:execute, @create_table_sqlar}, from, state)

  @impl true
  def handle_cast(:increment, %{n: n} = state) do
    {:noreply, %{state | n: n + 1}}
  end

  @impl true
  def terminate(_reason, %{db_conn: db_conn}) do
    Exqlite.Sqlite3.close(db_conn)
  end

  # TODO: move somewhere else
  # https://thoughtbot.com/blog/how-to-start-processes-with-dynamic-names-in-elixir
  def start_dynamic(database_id) do
    result =
      DynamicSupervisor.start_child(
        MiniModules.DatabaseSupervisor,
        {__MODULE__, database_id}
        # {__MODULE__, name: {:via, Registry, {MiniModules.DatabaseRegistry, database_id, database_id}}}
      )

    case result do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
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

  def execute_statements(pid, sql) do
    GenServer.call(pid, {:execute, sql})
  end

  def create_table_sqlar!(pid) do
    GenServer.call(pid, :create_table_sqlar)
  end

  def increment(pid) do
    GenServer.cast(pid, :increment)
  end

  defp topic(database_id), do: "database:#{database_id}"

  def subscribe(database_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(database_id))
  end

  defp broadcast(database_id, change \\ nil) do
    IO.puts("broadcast #{database_id}")
    Phoenix.PubSub.local_broadcast(@pubsub, topic(database_id), {__MODULE__, change})
  end
end
