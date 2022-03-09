defmodule MiniModulesWeb.LandingController do
  use MiniModulesWeb, :controller

  alias MiniModules.UniversalModules
  alias MiniModules.Fetch.Get

  @hello 2

  @example_module_code Get.load_text(
                         "https://collected.press/1/s3/highlight/us-west-2/collected-workspaces/sha256/application/javascript/bbdf5c799fb70e05161702a437381fe3ee4aa7c480bcb19902e9767e78a171f1"
                       )
  @example_output_json Get.load_text(
                         "https://collected.press/1/s3/highlight/us-west-2/collected-workspaces/sha256/application/json/9474506e7022e08b87387e7772c9366d2db3bda3ca4dbf55a3491b3523a3d729"
                       )
  @example_html_sha Path.join(__DIR__, "../templates/landing/example.md") |> File.read!() |> then(fn data -> :crypto.hash(:sha256, data) end) |> Base.encode16(case: :lower)
  @example_html Get.load_text(
                  "https://collected.press/1/s3/object/us-west-2/collected-workspaces/sha256/text/markdown/#{@example_html_sha}"
                )
  # @example_html Get.load_text(
  #                 "https://collected.press/1/s3/object/us-west-2/collected-workspaces/sha256/text/markdown/f9e3b4139279ec6b9d12360a13f09eb3d1bec49d666493116a2641457ae8050a"
  #               )

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
      duration: duration,
      example_module_code: @example_module_code,
      example_output_json: @example_output_json,
      example_html: @example_html,
      example_html_sha: @example_html_sha
    )
  end
end
