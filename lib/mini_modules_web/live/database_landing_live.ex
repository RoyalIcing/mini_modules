defmodule MiniModulesWeb.DatabaseLandingLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias MiniModulesWeb.Endpoint

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
  def render(assigns) do
    ~H"""
    <article class="py-16 px-4 prose lg:prose-xl mx-auto text-center">
      <h1>Shared SQLite Databases</h1>

      <form phx-submit="create">
        <button class="px-4 py-2 text-xl text-white bg-blue-600 border border-blue-700 rounded">Create New Database</button>
      </form>

      <h2 class="text-left">Why?</h2>
      <ul class="text-left">
        <li>Great for prototyping ideas.</li>
        <li>Share just by copying and pasting the link with anyone.</li>
        <li>Multiple people can work on the same database.</li>
        <li>Run real SQL.</li>
        <li>Export your databases at any time.</li>
      </ul>
    </article>
    """
  end

  @impl true
  def handle_event("create", _params, socket) do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:noreply, push_redirect(socket, to: "/database/#{id}")}
  end
end
