defmodule MiniModules.YieldParserTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.YieldParser
  alias MiniModules.UniversalModules.Parser

  doctest YieldParser

  @fruit_source Parser.decode(~S"""
                export function* Fruit() {
                  yield ["apple", "grape", "blueberry"];
                  return true;
                }
                """)

  @ip_address_source Parser.decode(~S"""
                     export function* IPAddress() {
                       const [first] = yield /^\d+/;
                       yield ".";
                       const [second] = yield /^\d+/;
                       yield ".";
                       const [third] = yield /^\d+/;
                       yield ".";
                       const [fourth] = yield /^\d+/;
                       yield mustEnd;
                       return [first, second, third, fourth];
                     }
                     """)

  setup_all do
    {:ok, fruit_module} = @fruit_source
    {:ok, ip_address_module} = @ip_address_source

    [
      fruit_module: fruit_module,
      ip_address_module: ip_address_module
    ]
  end

  describe "run_parser/2" do
    test "fruit module with valid input", %{fruit_module: fruit_module} do
      assert YieldParser.run_parser(fruit_module, "apple") == {:ok, true, %{rest: ""}}
      assert YieldParser.run_parser(fruit_module, "apple!") == {:ok, true, %{rest: "!"}}
      assert YieldParser.run_parser(fruit_module, "appleapple") == {:ok, true, %{rest: "apple"}}
      assert YieldParser.run_parser(fruit_module, "grape") == {:ok, true, %{rest: ""}}
      assert YieldParser.run_parser(fruit_module, "grapefruit") == {:ok, true, %{rest: "fruit"}}
      assert YieldParser.run_parser(fruit_module, "blueberry") == {:ok, true, %{rest: ""}}
    end

    test "fruit module with invalid input", %{fruit_module: fruit_module} do
      assert YieldParser.run_parser(fruit_module, " apple") ==
               {:error, {:no_matching_choice, ["apple", "grape", "blueberry"], %{rest: " apple"}}}

      assert YieldParser.run_parser(fruit_module, "blah") ==
               {:error, {:no_matching_choice, ["apple", "grape", "blueberry"], %{rest: "blah"}}}

      assert YieldParser.run_parser(fruit_module, "") ==
               {:error, {:no_matching_choice, ["apple", "grape", "blueberry"], %{rest: ""}}}
    end

    test "ip address module with valid input", %{ip_address_module: ip_address_module} do
      assert YieldParser.run_parser(ip_address_module, "1.1.1.1") ==
               {:ok,
                [
                  [ref: "first"],
                  [ref: "second"],
                  [ref: "third"],
                  [ref: "fourth"]
                ], %{rest: ""}}
    end
  end
end
