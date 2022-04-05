defmodule MiniModulesWeb.YieldMachineLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias Phoenix.LiveView.Socket
  alias MiniModules.{UniversalModules, Fetch}
  alias MiniModulesWeb.Input.CodeEditorComponent

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  @example_traffic_lights {~S"""
                           export function* TrafficLights() {
                             function* Green() {
                               yield on("timer", Yellow);
                             }
                             function* Yellow() {
                               yield on("timer", Red);
                             }
                             function* Red() {
                               yield on("timer", Green);
                             }

                             return Red;
                           }

                           """, "timer\ntimer\ntimer"}

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
          input={@source}
          name="source"
          phx-keyup="source_enter_key"
          phx-key="Enter"
        />
        <div class="px-4 py-2 space-x-8">
        <button type="button" phx-click="example_traffic_lights">Traffic Lights</button>
        <button type="button" phx-click="example_traffic_lights_timed">Traffic Lights Timed</button>
        <button type="button" phx-click="example_import_traffic_lights">Import Traffic Lights</button>
        <button type="button" phx-click="example_aborter">Aborter</button>
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
        <textarea name="event_lines" rows={10} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @event_lines %></textarea>
        <%= if @mode == :idle do %>
          <button type="button" phx-click="start_timer">Start Timer</button>
        <% else %>
          <button type="button" phx-click="stop_timer">Stop Timer</button>
        <% end %>
        <%= if @error_message do %>
          <div role="alert" class="text-red-300">
            <%= @error_message %>
          </div>
        <% end %>
        <%= if @state do %>
          <output class="block text-center">Currently <strong><%= @state %></strong> after <strong><%= @clock / 1000 %></strong>s</output>
          <mermaid-image source={render_mermaid(@state, @components)} class="block bg-white text-center">
          </mermaid-image>
        <% end %>
      </section>
    </.form>

    """
  end

  defp render_mermaid(state, components) do
    """
    graph TB
    #{for {from, event, to} <- components, do: "#{from}-->|#{format_event(event)}|#{to}\n"}
    style #{state} fill:#222,color:#ffde00
    """
  end

  defp format_event(event) when is_binary(event), do: event
  defp format_event(event) when is_number(event), do: event / 1000

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

  defp process(assigns, source, event_lines, load \\ nil) do
    decoded =
      try do
        UniversalModules.Parser.decode(source)
      rescue
        _ -> {:error, :invalid_module}
      catch
        _ -> {:error, :catch}
      end

    {decoded, imported_modules} =
      case decoded do
        {:ok, module} ->
          {:ok, module, %{imported_modules: imported_modules}} =
            UniversalModules.ImportResolver.transform(module, fn url ->
              case {load, assigns[:imported_modules]} do
                # Use previously loaded module.
                {_, %{^url => loaded_module}} ->
                  {:ok, loaded_module}

                # Otherwise, load if we are being asked to.
                {:load, _} ->
                  %{done: true, data: data} = Fetch.Get.load(url)
                  UniversalModules.Parser.decode(data)

                # Otherwise, returning nothing.
                {_, _} ->
                  {:ok, nil}
              end
            end)

          {{:ok, module}, imported_modules}

        _ ->
          imported_modules = assigns[:imported_modules] || %{}
          {decoded, imported_modules}
      end

    events = parse_event_lines(event_lines)

    {state, clock, components, error_message} =
      case decoded do
        {:ok, elements} ->
          case UniversalModules.YieldMachine.interpret_machine(elements, events) do
            {:ok, %{current: state, overall_clock: clock, components: components}} ->
              {state, clock, components, nil}

            {:error, reason} ->
              {nil, nil, nil, inspect(reason)}
          end

        {:error, reason} ->
          {nil, nil, nil, inspect(reason)}
      end

    %{
      mode: assigns[:mode] || :idle,
      source: source,
      state: state,
      clock: clock,
      event_lines: event_lines,
      error_message: error_message,
      components: components,
      imported_modules: imported_modules
    }
  end

  @impl true
  def mount(_parmas, _session, socket) do
    {source, event_lines} = @example_traffic_lights

    socket =
      socket
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
  def handle_event("changed", %{"source" => source, "event_lines" => event_lines}, socket) do
    IO.puts("changed")
    {:noreply, assign(socket, process(socket.assigns, source, event_lines))}
  end

  def handle_event("source_enter_key", %{"value" => source}, socket) do
    IO.puts("source_enter_key")
    {:noreply, assign(socket, process(socket.assigns, source, socket.assigns.event_lines, :load))}
  end

  @timer_interval 1000

  def handle_event("start_timer", _, socket) do
    IO.puts("start_timer")
    {:ok, timer_ref} = :timer.send_interval(@timer_interval, self(), :timer_tick)
    socket = socket |> assign(mode: {:timer, timer_ref})
    {:noreply, socket}
  end

  def handle_event("stop_timer", _, socket) do
    IO.puts("stop_timer #{inspect(socket.assigns.mode)}")

    socket =
      case socket.assigns.mode do
        {:timer, timer_ref} ->
          :timer.cancel(timer_ref)
          socket |> assign(mode: :idle)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("example_" <> name, _value, socket) do
    socket = use_example(name, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:timer_tick, %Socket{assigns: %{event_lines: event_lines}} = socket) do
    IO.puts("timer_tick")
    event_lines = event_lines |> String.split([" ", "\n", "\r"], trim: true) |> Enum.reverse()

    {last_event, event_lines} =
      case event_lines do
        [last_event | reversed_events] ->
          {last_event, reversed_events |> Enum.reverse()}

        [] ->
          {"0", []}
      end

    event_lines =
      case Float.parse(last_event) do
        {n, ""} ->
          event_lines ++ [format_float(n + @timer_interval)]

        _ ->
          event_lines ++ [last_event, format_float(@timer_interval)]
      end

    IO.inspect(event_lines)

    event_lines = Enum.join(event_lines, "\n")
    socket = socket |> assign(event_lines: event_lines)
    assigns = process(socket.assigns, socket.assigns.source, socket.assigns.event_lines, :load)
    socket = assign(socket, assigns)
    {:noreply, socket}
  end

  defp format_float(f) do
    :erlang.float_to_binary(f / 1, [{:decimals, 0}, :compact])
  end

  defp use_example("traffic_lights", socket = %Socket{}),
    do: reset_content(@example_traffic_lights, socket)

  defp use_example("traffic_lights_timed", socket = %Socket{}),
    do: reset_content(@example_traffic_lights_timed, socket)

  defp use_example("import_traffic_lights", socket = %Socket{}),
    do: reset_content(@example_import_traffic_lights, socket)

  defp use_example("aborter", socket = %Socket{}),
    do: reset_content(@example_aborter, socket)

  defp reset_content({source, event_lines}, socket = %Socket{}) do
    socket
    |> assign(process(socket.assigns, source, event_lines, :load))
  end
end
