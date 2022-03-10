defmodule MiniModulesWeb.YieldMachineLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias Phoenix.LiveView.Socket
  alias MiniModules.{UniversalModules, Fetch}
  alias MiniModulesWeb.Input.CodeEditorComponent

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  # TODO:
  # Allow timing events with integer events: e.g. "5" for 5 seconds passing
  # Show 'Start' button that starts a timer.
  # Each second the last line increments by 1 second.
  # Pause to allow editing the events field.
  # Clear the events field to start again.

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
      <CodeEditorComponent.monaco id="monaco-editor" input={@source} name="source" phx-keyup="source_enter_key"
      phx-key="Enter" />
      <!--<textarea
        name="source"
        rows={24}
        class="w-full font-mono bg-gray-800 text-white border border-gray-600"
        phx-keyup="source_enter_key"
        phx-key="Enter"
      ><%= @source %></textarea>-->

      <section class="block w-1/2 space-y-4">
        <textarea name="event_lines" rows={10} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @event_lines %></textarea>
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
        {n, ""} when n < 100_000 ->
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
    {:ok,
     assign(
       socket,
       process(
         socket.assigns,
         ~S"""
         import { TrafficLights } from "https://gist.githubusercontent.com/BurntCaramel/38fb200b9f32087e1d222b638b5957b2/raw";

         export { TrafficLights };
         """,
         "timer\ntimer\ntimer",
         :load
       )
     )}
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
end
