defmodule MiniModulesWeb.LandingController do
  use MiniModulesWeb, :controller

  alias MiniModules.UniversalModules
  alias MiniModules.Fetch.Get

  def index(conn, _params) do
    source = ~S"""
    export const pi = 3.14159265;
    export const dateFormat = "YYYY/MM/DD";
    export const isEnabled = true;
    export const flavors = ["vanilla", "chocolate", "caramel", "raspberry"];

    export const homeURL = new URL("https://example.org/");
    export const aboutURL = new URL("/about", homeURL);
    export const blogURL = new URL("/blog/", homeURL);
    export const firstArticle = new URL("./first-article", blogURL);
    """

    {:ok, module} = UniversalModules.Parser.decode(source)
    json_output = UniversalModules.JSONEncoder.to_json(module) |> Jason.encode!(pretty: true)

    start = System.monotonic_time(:millisecond)
    Get.load("https://workers.cloudflare.com/cf.json")
    duration = System.monotonic_time(:millisecond) - start

    render(conn, "index.html",
      source: source,
      json_output: json_output,
      duration: duration
    )
  end
end
