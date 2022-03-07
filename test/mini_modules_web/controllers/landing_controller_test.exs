defmodule MiniModulesWeb.LandingControllerTest do
  use MiniModulesWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "MiniModules"
  end
end
