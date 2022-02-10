defmodule MiniModulesWeb.YieldParserLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias MiniModules.UniversalModules
  # alias MiniModules.UniversalModules.Parser, as: Parser

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  def render(assigns) do
    ~H"""
    <.form
      for={:editor}
      id="editor-form"
      class="flex gap-4"
      phx-change="changed">
      <textarea name="source" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @source %></textarea>

      <section class="block w-1/2 space-y-4">
        <textarea name="input" rows={1} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>
        <%= if @error_message do %>
          <div role="alert" class="text-red-300">
            <%= @error_message %>
          </div>
        <% end %>
        <%= if @result do %>
          <output class="block"><%= inspect(@result) %></output>
        <% end %>
        <dl class="block">
          <dt class="font-bold">Rest</dt>
          <dd class="ml-8"><pre>"<%= @rest %>"</pre></dd>
        </dl>
      </section>
    </.form>

    """
  end

  defp process(source, input) do
    decoded =
      try do
        UniversalModules.Parser.decode(source)
      rescue
        _ -> {:error, :rescue}
      catch
        _ -> {:error, :catch}
      end

    # decoded = UniversalModules.Parser.decode(input)
    # identifiers = UniversalModules.Inspector.list_identifiers(elem(decoded, 1))
    {result, rest, error_message} =
      case decoded do
        {:ok, elements} ->
          case UniversalModules.YieldParser.run_parser(elements, input) do
            {:ok, result, %{rest: rest}} ->
              {result, rest, nil}

            {:error, reason} ->
              {nil, "", inspect(reason)}
          end

        {:error, reason} ->
          {nil, "", inspect(reason)}
      end

    %{
      source: source,
      input: input,
      result: result,
      rest: rest,
      error_message: error_message
    }
  end

  def mount(_parmas, _session, socket) do
    {:ok,
     assign(
       socket,
       process(
         ~S"""
         function* Digit() {
           const [digit] = yield /^\d+/;
           return digit;
         }

         export function* IPAddress() {
           const first = yield Digit;
           yield ".";
           const second = yield Digit;
           yield ".";
           const third = yield Digit;
           yield ".";
           const fourth = yield Digit;
           yield mustEnd;
           return [first, second, third, fourth];
         }
         """,
         "1.2.3.4"
       )
     )}
  end

  def handle_event("changed", %{"source" => source, "input" => input}, socket) do
    {:noreply, assign(socket, process(source, input))}
  end
end
