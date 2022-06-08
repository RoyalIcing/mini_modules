defmodule MiniModulesWeb.ReactEditorController do
  use MiniModulesWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

defmodule MiniModulesWeb.ReactEditorView do
  use MiniModulesWeb, :view
end
