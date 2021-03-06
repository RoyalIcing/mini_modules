defmodule MiniModules.ParserTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser

  @moduletag timeout: 1000

  doctest Parser

  describe "decode/1" do
    test "empty" do
      assert Parser.decode("") == {:ok, []}
    end

    test "comment" do
      assert Parser.decode("""
             // First

             // Second
             """) ==
               {:ok,
                [
                  {:comment, " First"},
                  {:comment, " Second"}
                ]}
    end

    test "comment without ending newline" do
      assert Parser.decode("// First") ==
               {:ok, [{:comment, " First"}]}
    end

    test "multiline comment" do
      assert Parser.decode("""
             /* First */

             /**
             * Multiple
             * lines
             */
             """) ==
               {:ok,
                [
                  {:comment, [" First "]},
                  {:comment, ["*", "* Multiple", "* lines", ""]}
                ]}
    end

    test "const true" do
      assert Parser.decode("""
             const isEnabled = true;
             """) == {:ok, [{:const, "isEnabled", true}]}
    end

    test "const number" do
      assert Parser.decode("""
             const a = 1;
             """) == {:ok, [{:const, "a", 1.0}]}
    end

    test "const string" do
      assert Parser.decode("""
             const a = "abc";
             """) == {:ok, [{:const, "a", "abc"}]}
    end

    test "const string with punctuations" do
      assert Parser.decode("""
             const a = "abc ' \\" ; ";
             """) == {:ok, [{:const, "a", "abc ' \" ; "}]}
    end

    test "const regex" do
      assert Parser.decode(~S"""
             const a = /[abc]+/;
             const b = /^[abc]+/;
             const c = /^\d+/;
             """) ==
               {:ok,
                [
                  {:const, "a", {:regex, "[abc]+"}},
                  {:const, "b", {:regex, "^[abc]+"}},
                  {:const, "c", {:regex, ~S"^\d+"}}
                ]}
    end

    test "const referring earlier const" do
      assert Parser.decode("""
             const a = "abc";
             const b = a;
             """) ==
               {:ok,
                [
                  {:const, "a", "abc"},
                  {:const, "b", {:ref, "a"}}
                ]}
    end

    test "const destructuring array" do
      assert Parser.decode("""
             const [a, b] = [1, 2];
             """) == {:ok, [{:const, ["a", "b"], [1, 2]}]}
    end

    test "const destructuring array with skipping" do
      assert Parser.decode("""
             const [, a,,, b] = [1, 2, 3, 4, 5];
             """) == {:ok, [{:const, [nil, "a", nil, nil, "b"], [1, 2, 3, 4, 5]}]}
    end

    test "const multiple" do
      assert Parser.decode("""
             const pi = 3.14;

             const answer = 42;
             const negativeAnswer = -42;

             const isEnabled = true;
             const verbose = false;
             const alwaysNull = null;
             """) ==
               {:ok,
                [
                  {:const, "pi", 3.14},
                  {:const, "answer", 42.0},
                  {:const, "negativeAnswer", -42.0},
                  {:const, "isEnabled", true},
                  {:const, "verbose", false},
                  {:const, "alwaysNull", nil}
                ]}
    end

    test "export const number" do
      assert Parser.decode("""
             export const a = 1;
             """) == {:ok, [export: {:const, "a", 1.0}]}
    end

    test "export const string" do
      assert Parser.decode("""
             export const a = "abc";
             """) == {:ok, [export: {:const, "a", "abc"}]}
    end

    test "empty function" do
      assert Parser.decode("""
             function hello() {}
             """) == {:ok, [{:function, "hello", [], []}]}
    end

    test "function returning number" do
      assert Parser.decode("""
             function hello() {
               return 42;
             }
             """) == {:ok, [{:function, "hello", [], [{:return, 42}]}]}
    end

    test "empty generator function" do
      assert Parser.decode("""
             function* hello() {}
             """) == {:ok, [{:generator_function, "hello", [], []}]}
    end

    test "generator function yielding number" do
      assert Parser.decode(~S"""
             function* hello() {
               yield 42;
               yield /^\d+/;
             }
             """) ==
               {:ok,
                [
                  {:generator_function, "hello", [],
                   [
                     yield: 42.0,
                     yield: {:regex, ~S"^\d+"}
                   ]}
                ]}
    end

    test "generator function yielding number with reply assigned to constant" do
      assert Parser.decode("""
             function* hello() {
               // We do some stuff
               const reply = yield 42;
             }
             """) ==
               {:ok,
                [
                  {:generator_function, "hello", [],
                   [
                     {:comment, " We do some stuff"},
                     {:const, "reply", {:yield, 42.0}}
                   ]}
                ]}
    end

    test "export empty function" do
      assert Parser.decode("""
             export function hello() {}
             """) == {:ok, [export: {:function, "hello", [], []}]}
    end

    test "export generator function yielding number" do
      assert Parser.decode("""
             export function* hello() {
               yield 42;
             }
             """) == {:ok, [export: {:generator_function, "hello", [], [yield: 42.0]}]}
    end

    test "new URL" do
      assert Parser.decode("""
             const root = new URL("https://example.org");
             """) == {:ok, [{:const, "root", {:url, "https://example.org"}}]}
    end

    test "new URL with string base" do
      assert Parser.decode("""
             const aboutLink = new URL("/about", "https://example.org");
             """) ==
               {:ok,
                [{:const, "aboutLink", {:url, [relative: "/about", base: "https://example.org"]}}]}
    end

    test "new URL with ref base" do
      assert Parser.decode("""
             const homeLink = new URL("https://example.org");
             const aboutLink = new URL("/about", homeLink);
             """) ==
               {:ok,
                [
                  {:const, "homeLink", {:url, "https://example.org"}},
                  {:const, "aboutLink", {:url, [relative: "/about", base: {:ref, "homeLink"}]}}
                ]}
    end

    test "new Set" do
      assert Parser.decode("""
             const luckyNumbers = new Set([1, 2, 3]);
             """) == {:ok, [{:const, "luckyNumbers", {:set, [1, 2, 3]}}]}
    end

    test "Symbol" do
      assert Parser.decode("""
             const key = Symbol();
             """) == {:ok, [{:const, "key", {:symbol, nil}}]}
    end

    test "Symbol with description" do
      assert Parser.decode("""
             const key = Symbol("special");
             """) == {:ok, [{:const, "key", {:symbol, "special"}}]}
    end

    test "new Error" do
      assert Parser.decode("""
             const oops = new Error("No network connection");
             """) == {:ok, [{:const, "oops", {:error, "No network connection"}}]}
    end

    test "import names" do
      assert Parser.decode("""
             import { a } from "https://first.org";
             import { a, b } from "https://second.org";
             import * as foo from "https://third.org";
             """) ==
               {:ok,
                [
                  {:import, ["a"], {:url, "https://first.org"}},
                  {:import, ["a", "b"], {:url, "https://second.org"}},
                  {:import, {:alias, "foo"}, {:url, "https://third.org"}}
                ]}
    end

    test "import then export" do
      assert Parser.decode("""
             import { Switch } from "https://example.org/switch-machine.js";
             export { Switch };
             """) ==
               {:ok,
                [
                  {
                    :import,
                    ["Switch"],
                    {:url, "https://example.org/switch-machine.js"}
                  },
                  {:export, [ref: "Switch"]}
                ]}
    end

    test "import then export 2" do
      assert Parser.decode("""
             import { YouTubeURL } from "https://gist.github.com/BurntCaramel/5cabb793e7e4ba961c00a807323e0afe/raw";
             export { YouTubeURL };
             """) ==
               {:ok,
                [
                  {
                    :import,
                    ["YouTubeURL"],
                    {:url,
                     "https://gist.github.com/BurntCaramel/5cabb793e7e4ba961c00a807323e0afe/raw"}
                  },
                  {:export, [ref: "YouTubeURL"]}
                ]}
    end

    test "yieldmachine definition" do
      assert Parser.decode(~S"""
             export function Switch() {
               function* OFF() {
                 yield on("FLICK", ON);
               }
               function* ON() {
                 yield on("FLICK", OFF);
               }

               return OFF;
             }
             """) ==
               {:ok,
                [
                  export:
                    {:function, "Switch", [],
                     [
                       {:generator_function, "OFF", [],
                        [
                          yield: {:call, {:ref, "on"}, ["FLICK", {:ref, "ON"}]}
                        ]},
                       {:generator_function, "ON", [],
                        [
                          yield: {:call, {:ref, "on"}, ["FLICK", {:ref, "OFF"}]}
                        ]},
                       {:return, {:ref, "OFF"}}
                     ]}
                ]}
    end
  end
end
