defmodule MiniModulesWeb.EditorController do
  use MiniModulesWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

defmodule MiniModulesWeb.EditorView do
  use MiniModulesWeb, :view
end
