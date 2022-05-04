defmodule MiniModulesWeb.SQLiteLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias Phoenix.LiveView.Socket
  alias MiniModules.{UniversalModules, Fetch}
  alias MiniModulesWeb.Input.CodeEditorComponent

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  @example_traffic_lights {~S"""
                           create table state_machine_definitions(id integer primary key, name text, initial_state text);
                           create table state_transition_definitions(machine_definition_id integer, from_state text, event_name text, to_state text);
                           create table state_machine_instances(id integer primary key, machine_definition_id integer, current_state text);

                           insert into state_machine_definitions(name, initial_state) values('TrafficLight', 'Red');
                           insert into state_transition_definitions values(1, 'Red', 'timer', 'Green');
                           insert into state_transition_definitions values(1, 'Green', 'timer', 'Yellow');
                           insert into state_transition_definitions values(1, 'Yellow', 'timer', 'Red');

                           insert into state_machine_instances(machine_definition_id, current_state) values(1, 'Red');

                           update state_machine_instances set current_state = (select to_state from state_transition_definitions where machine_definition_id = 1 and from_state = (select current_state from state_machine_instances where id = 1) and event_name = 'timer') where id = 1;
                           update state_machine_instances set current_state = (select to_state from state_transition_definitions where machine_definition_id = 1 and from_state = (select current_state from state_machine_instances where id = 1) and event_name = 'timer') where id = 1;

                           """, "select * from state_machine_instances;"}

  @example_traffic_lights_timed {~S"""
                                 export function* TrafficLights() {
                                   function* Green() {
                                     yield on(3, Yellow);
                                   }
                                   function* Yellow() {
                                     yield on(3, Red);
                                   }
                                   function* Red() {
                                     yield on(3, Green);
                                   }

                                   return Red;
                                 }

                                 """, "0"}

  @example_import_traffic_lights {~S"""
                                  import { TrafficLights } from "https://gist.githubusercontent.com/BurntCaramel/38fb200b9f32087e1d222b638b5957b2/raw";

                                  export { TrafficLights };
                                  """, "timer\ntimer\ntimer"}

  @example_aborter {~S"""
                    export function* Aborter() {
                      function* Initial() {
                        yield on("abort", Aborted);
                      }
                      function* Aborted() {}

                      return Initial;
                    }
                    """, "5000\nabort"}

  @example_promise {~S"""
                    export function* PromiseMachine() {
                      function* Pending() {
                        yield on("resolve", Resolved);
                        yield on("reject", Rejected);
                      }
                      function* Resolved() {}
                      function* Rejected() {}

                      return Pending;
                    }
                    """, "5000\nresolve"}

  @impl true
  def render(assigns) do
    ~H"""
    <.form
      for={:editor}
      id="editor-form"
      class="flex gap-4"
      phx-change="changed"
      phx-submit="submit"
    >
      <div class="w-full">
        <CodeEditorComponent.monaco
          id="monaco-editor"
          change_clock={@change_clock}
          input={@source}
          name="source"
          phx-keyup="source_enter_key"
          phx-key="Enter"
        />
        <textarea name="query" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @query %></textarea>
        <div class="px-4 py-2 space-x-8">
        <button type="button" phx-click="example_traffic_lights">Traffic Lights</button>
        <button type="button" phx-click="example_traffic_lights_timed">Traffic Lights Timed</button>
        <button type="button" phx-click="example_import_traffic_lights">Import Traffic Lights</button>
        <button type="button" phx-click="example_aborter">Aborter</button>
        <button type="button" phx-click="example_promise">Promise</button>
        </div>
      </div>
      <!--<textarea
        name="source"
        rows={24}
        class="w-full font-mono bg-gray-800 text-white border border-gray-600"
        phx-keyup="source_enter_key"
        phx-key="Enter"
      ><%= @source %></textarea>-->

      <section class="block w-1/2 space-y-4">
        <%= if @result do %>
          <output class="block text-green-300">
            <%= inspect(@result) %>
          </output>
        <% end %>
        <%= if @error_message do %>
          <div role="alert" class="text-red-300">
            <%= @error_message %>
          </div>
        <% end %>
      </section>
    </.form>

    """
  end

  defp parse_event_lines(event_lines) do
    event_lines
    |> String.split([" ", "\n", "\r"], trim: true)
    |> Enum.map(fn s ->
      case Float.parse(s) do
        {n, ""} when n < 1_000_000 ->
          n

        _ ->
          s
      end
    end)
  end

  defp process(assigns, source, query, load \\ nil) do
    {:ok, conn} = Exqlite.Sqlite3.open(":memory:")

    {result, error_message} =
      with :ok <- Exqlite.Sqlite3.execute(conn, source),
           {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
           {:ok, rows} <- Exqlite.Sqlite3.fetch_all(conn, statement) do
        {rows, nil}
      else
        {:error, reason} ->
          {nil, reason}
      end

    # {result, error_message} =
    #   case Exqlite.Sqlite3.prepare(conn, source) do
    #     {:ok, statement} ->
    #       case Exqlite.Sqlite3.fetch_all(conn, statement) do
    #         {:ok, rows} ->
    #           {rows, nil}

    #         {:error, reason} ->
    #           {nil, reason}
    #       end

    #     {:error, reason} ->
    #       {nil, reason}
    #   end

    Exqlite.Sqlite3.close(conn)

    %{
      mode: assigns[:mode] || :idle,
      source: source,
      query: query,
      error_message: error_message,
      result: result
    }
  end

  @impl true
  def mount(_parmas, _session, socket) do
    {source, event_lines} = @example_traffic_lights

    socket =
      socket
      |> assign(:change_clock, 0)
      |> assign(
        process(
          socket.assigns,
          source,
          event_lines,
          :load
        )
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("changed", %{"source" => source, "query" => query}, socket) do
    IO.puts("changed")
    {:noreply, assign(socket, process(socket.assigns, source, query))}
  end

  def handle_event("source_enter_key", %{"value" => source}, socket) do
    IO.puts("source_enter_key")
    {:noreply, assign(socket, process(socket.assigns, source, socket.assigns.query, :load))}
  end

  def handle_event("example_" <> name, _value, socket) do
    socket = use_example(name, socket)
    {:noreply, socket}
  end

  defp use_example("traffic_lights", socket = %Socket{}),
    do: reset_content(@example_traffic_lights, socket)

  defp use_example("traffic_lights_timed", socket = %Socket{}),
    do: reset_content(@example_traffic_lights_timed, socket)

  defp use_example("import_traffic_lights", socket = %Socket{}),
    do: reset_content(@example_import_traffic_lights, socket)

  defp use_example("aborter", socket = %Socket{}),
    do: reset_content(@example_aborter, socket)

  defp use_example("promise", socket = %Socket{}),
    do: reset_content(@example_promise, socket)

  defp reset_content({source, event_lines}, socket = %Socket{}) do
    socket
    |> assign(process(socket.assigns, source, event_lines, :load))
    |> assign(:change_clock, socket.assigns.change_clock + 1)
  end
end
