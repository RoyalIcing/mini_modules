defmodule MiniModulesWeb.LandingController do
  use MiniModulesWeb, :controller

  alias MiniModules.Fetch.Get

  def index(conn, _params) do
    start = System.monotonic_time(:millisecond)
    Get.load("https://workers.cloudflare.com/cf.json")
    duration = System.monotonic_time(:millisecond) - start

    render(conn, "index.html", duration: duration)
  end
end
