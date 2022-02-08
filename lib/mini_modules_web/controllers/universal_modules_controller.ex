defmodule MiniModulesWeb.UniversalModulesController do
  use MiniModulesWeb, :controller

  alias MiniModules.UniversalModules.Parser, as: Parser

  def index(conn, _params) do
    source = """
    const pi = 3.14;

    export const answer = 42;
    const negativeAnswer = -42;

    const isEnabled = true;
    const verbose = false;
    const alwaysNull = null;

    const debug = verbose;

    export const dateFormat = "YYYY/MM/DD";

    const exampleDotOrg = new URL("https://example.org");

    const array = [1, 2, 3];
    const arrayMultiline = [
      4,
      5,
      6
    ];
    export const flavors = ["vanilla", "chocolate", "caramel", "raspberry"];
    export const flavorsSet = new Set(["vanilla", "chocolate", "caramel", "raspberry", "vanilla"]);

    const object = { "key": "value" };

    function hello() {}
    function* gen() {
      const a = 1;
      yield [1, 2, 3];
    }
    """
    # decoded = decode_module(source)
    decoded = Parser.decode(source)
    identifiers = MiniModulesWeb.UniversalModulesInspector.list_identifiers(elem(decoded, 1))
    json = MiniModulesWeb.UniversalModules.JSONEncoder.to_json(elem(decoded, 1))

    render(conn, "index.html",
      page_title: "Universal Modules",
      source: source,
      decoded: inspect(decoded),
      identifiers: inspect(identifiers, pretty: true),
      json: Jason.encode!(json, pretty: true)
    )
  end
end

defmodule MiniModulesWeb.UniversalModulesInspector do
  defp is_identifier({:const, _, _}), do: true
  defp is_identifier({:function, _, _, _}), do: true
  defp is_identifier({:generator_function, _, _, _}), do: true
  defp is_identifier(_), do: false

  def list_identifiers(module_body) do
    for statement <- module_body, is_identifier(statement), do: statement
  end
end

defmodule MiniModulesWeb.UniversalModules.JSONEncoder do
  defp encode({:export, {:const, name, value}})
       when is_binary(value) or is_number(value) or is_list(value) or is_nil(value),
       do: [{name, value}]

  defp encode({:export, {:const, name, {:set, members}}}),
    do: [{name, MapSet.to_list(MapSet.new(members))}] # TODO: preserve order

  defp encode(_), do: []

  def to_json(module_body) do
    Map.new(for statement <- module_body, json <- encode(statement), do: json)
  end
end

defmodule MiniModulesWeb.UniversalModulesView do
  use MiniModulesWeb, :view
end
