defmodule MiniModulesWeb.PageControllerTest do
  use MiniModulesWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "MiniModules"
  end
end
