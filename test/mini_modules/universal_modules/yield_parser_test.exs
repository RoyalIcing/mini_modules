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

  @ip_address_2_source Parser.decode(~S"""
                       function* Digit() {
                         const [digit] = yield /^\d+/;
                         return digit;
                       }

                       export function* IPAddress() {
                         const first = yield Digit;
                         yield ".";
                         const second = yield Digit;
                         yield ".";
                         const third = yield Digit;
                         yield ".";
                         const fourth = yield Digit;
                         yield mustEnd;
                         return [first, second, third, fourth];
                       }
                       """)

  setup_all do
    {:ok, fruit_module} = @fruit_source
    {:ok, ip_address_module} = @ip_address_source
    {:ok, ip_address_2_module} = @ip_address_2_source

    [
      fruit_module: fruit_module,
      ip_address_module: ip_address_module,
      ip_address_2_module: ip_address_2_module
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
      assert YieldParser.run_parser(ip_address_module, "1.2.4.9") ==
               {:ok, ["1", "2", "4", "9"], %{rest: ""}}
    end

    test "ip address module with invalid input", %{ip_address_module: ip_address_module} do
      assert YieldParser.run_parser(ip_address_module, "1.2.4.a") ==
               {:error, {:did_not_match, {:regex, ~S"^\d+"}, %{rest: "a"}}}
    end

    test "composed ip address module with valid input", %{ip_address_2_module: ip_address_2_module} do
      assert YieldParser.run_parser(ip_address_2_module, "1.2.4.9") ==
               {:ok, ["1", "2", "4", "9"], %{rest: ""}}
    end
  end
end
