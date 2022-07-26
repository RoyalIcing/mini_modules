defmodule MiniModulesWeb.JsAstLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:add_result, "")
      |> assign(:js_ast_result, nil)
      |> assign(:js_parse_ms, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="py-16 px-4 prose lg:prose-xl mx-auto">
      <h1 class="text-center">Deno</h1>

      <form phx-change="js">
        <label class="block">
          <div>JavaScript Source</div>
          <textarea name="source" rows="10" class="w-full border" placeholder="Enter your JavaScript masterpiece…"></textarea>
        </label>
        <output class="block bg-green-100">
          <pre class="empty:hidden p-2 text-black"><%= inspect(@js_ast_result) %></pre>
          <div class="empty:hidden"><%= if @js_parse_ms, do: "#{@js_parse_ms}ms", else: "" %></div>
        </output>
        <button class="mt-2 px-4 py-2 text-xl text-white bg-blue-600 border border-blue-700 rounded">Execute JavaScript</button>
      </form>
    </article>
    """
  end

  @impl true
  def handle_event("js", %{"source" => source}, socket) do
    start_ms = System.monotonic_time(:millisecond)

    result = Molten.parse_js(source)

    end_ms = System.monotonic_time(:millisecond)
    js_parse_ms = end_ms - start_ms

    socket = socket |> assign(:js_ast_result, result) |> assign(:js_parse_ms, js_parse_ms)
    {:noreply, socket}
  end
end
