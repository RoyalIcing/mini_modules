defmodule MiniModules.YieldParserTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.YieldParser
  alias MiniModules.UniversalModules.Parser

  doctest YieldParser

  @fruit_source Parser.decode(~S"""
                export function* Fruit() {
                  yield ["apple", "grape", "blueberry"];
                  // Some comment
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

  @youtube_url_source Parser.decode(~S"""
                      function* VideoID() {
                        const [videoID] = yield /^[a-zA-Z0-9_]+$/;
                        return videoID;
                      }
                      function* Long() {
                        yield "https://www.youtube.com/watch?v=";
                        const videoID = yield VideoID;
                        return videoID;
                      }
                      function* Embed() {
                        yield "https://www.youtube.com/embed/";
                        const videoID = yield VideoID;
                        return videoID;
                      }
                      function* Short() {
                        yield "https://youtu.be/";
                        const videoID = yield VideoID;
                        return videoID;
                      }

                      export function* IPAddress() {
                        const first = yield [Long, Embed, Short];
                        yield mustEnd;
                        return first;
                      }
                      """)

  setup_all do
    {:ok, fruit_module} = @fruit_source
    {:ok, ip_address_module} = @ip_address_source
    {:ok, ip_address_2_module} = @ip_address_2_source
    {:ok, youtube_url_module} = @youtube_url_source

    [
      fruit_module: fruit_module,
      ip_address_module: ip_address_module,
      ip_address_2_module: ip_address_2_module,
      youtube_url_module: youtube_url_module
    ]
  end

  describe "run_parser/2" do
    test "fruit module with valid input", %{fruit_module: m} do
      assert YieldParser.run_parser(m, "apple") == {:ok, true, %{rest: ""}}
      assert YieldParser.run_parser(m, "apple!") == {:ok, true, %{rest: "!"}}
      assert YieldParser.run_parser(m, "appleapple") == {:ok, true, %{rest: "apple"}}
      assert YieldParser.run_parser(m, "grape") == {:ok, true, %{rest: ""}}
      assert YieldParser.run_parser(m, "grapefruit") == {:ok, true, %{rest: "fruit"}}
      assert YieldParser.run_parser(m, "blueberry") == {:ok, true, %{rest: ""}}
    end

    test "fruit module with invalid input", %{fruit_module: m} do
      assert YieldParser.run_parser(m, " apple") ==
               {:error, {:no_matching_choice, ["apple", "grape", "blueberry"], %{rest: " apple"}}}

      assert YieldParser.run_parser(m, "blah") ==
               {:error, {:no_matching_choice, ["apple", "grape", "blueberry"], %{rest: "blah"}}}

      assert YieldParser.run_parser(m, "") ==
               {:error, {:no_matching_choice, ["apple", "grape", "blueberry"], %{rest: ""}}}
    end

    test "ip address module with valid input", %{ip_address_module: m} do
      assert YieldParser.run_parser(m, "1.2.4.9") ==
               {:ok, ["1", "2", "4", "9"], %{rest: ""}}
    end

    test "ip address module with invalid input", %{ip_address_module: m} do
      assert YieldParser.run_parser(m, "1.2.4.a") ==
               {:error, {:did_not_match, {:regex, ~S"^\d+"}, %{rest: "a"}}}
    end

    test "composed ip address module with valid input", %{
      ip_address_2_module: m
    } do
      assert YieldParser.run_parser(m, "1.2.4.9") ==
               {:ok, ["1", "2", "4", "9"], %{rest: ""}}
    end

    test "youtube url module with valid input", %{youtube_url_module: m} do
      assert YieldParser.run_parser(m, "https://www.youtube.com/watch?v=HRb7B9fPhfA") ==
               {:ok, "HRb7B9fPhfA", %{rest: ""}}
      assert YieldParser.run_parser(m, "https://www.youtube.com/embed/HRb7B9fPhfA") ==
               {:ok, "HRb7B9fPhfA", %{rest: ""}}
      assert YieldParser.run_parser(m, "https://youtu.be/HRb7B9fPhfA") ==
               {:ok, "HRb7B9fPhfA", %{rest: ""}}
    end
  end
end
