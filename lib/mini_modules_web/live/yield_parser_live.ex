defmodule MiniModulesWeb.YieldParserLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias MiniModules.UniversalModules
  alias MiniModules.Fetch

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  def render(assigns) do
    ~H"""
    <.form
      for={:editor}
      id="editor-form"
      class="flex gap-4"
      phx-change="changed">
      <textarea
        name="source"
        rows={24}
        class="w-full font-mono bg-gray-800 text-white border border-gray-600"
        phx-keyup="source_enter_key"
        phx-key="Enter"
      ><%= @source %></textarea>

      <section class="block w-1/2 space-y-4">
        <textarea name="input" rows={6} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>
        <%= if @error_message do %>
          <div role="alert" class="text-red-300">
            <%= @error_message %>
          </div>
        <% end %>
        <%= if @result do %>
          <output class="block p-4 bg-blue-900/20 text-blue-900 border border-blue-800"><pre><%= inspect(@result, pretty: true) %></pre></output>
        <% end %>
        <dl class="block">
          <dt class="font-bold">Rest</dt>
          <dd class="ml-8"><pre>"<%= @rest %>"</pre></dd>
        </dl>
      </section>
    </.form>

    """
  end

  defp process(assigns, source, input, load \\ nil) do
    decoded =
      try do
        UniversalModules.Parser.decode(source)
      rescue
        _ -> {:error, :rescue}
      catch
        _ -> {:error, :catch}
      end

    {decoded, imported_modules} =
      case decoded do
        {:ok, module} ->
          {:ok, module, %{imported_modules: imported_modules}} =
            resolve_imports(load, module, assigns[:imported_modules])

          {{:ok, module}, imported_modules}

        _ ->
          imported_modules = assigns[:imported_modules] || %{}
          {decoded, imported_modules}
      end

    IO.inspect(decoded)

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
      error_message: error_message,
      imported_modules: imported_modules
    }
  end

  defp resolve_imports(action, module, previously_imported_modules) do
    UniversalModules.ImportResolver.transform(module, fn url ->
      case {previously_imported_modules, action} do
        # Use previously loaded module.
        {%{^url => loaded_module}, _} ->
          {:ok, loaded_module}

        # Otherwise, load if we are being asked to.
        {_, :load} ->
          case Fetch.Get.load(url) do
            %{done: true, data: data} ->
              UniversalModules.Parser.decode(data)

            response ->
              {:error, {:did_not_load, response}}
          end

        # Otherwise, returning nothing.
        {_, _} ->
          {:ok, nil}
      end
    end)
  end

  def mount(_parmas, _session, socket) do
    {:ok,
     assign(
       socket,
       process(
         socket.assigns,
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
         "1.2.3.4",
         :load
       )
     )}
  end

  def handle_event("changed", %{"source" => source, "input" => input}, socket) do
    {:noreply, assign(socket, process(socket.assigns, source, input))}
  end

  def handle_event("source_enter_key", %{"value" => source}, socket) do
    IO.puts("source_enter_key")
    {:noreply, assign(socket, process(socket.assigns, source, socket.assigns.input, :load))}
  end
end
