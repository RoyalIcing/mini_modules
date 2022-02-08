defmodule MiniModules.ParserTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser

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
      assert Parser.decode("""
             const a = /[abc]+/;
             """) == {:ok, [{:const, "a", {:regex, "[abc]+"}}]}
    end

    test "const referring earlier const" do
      assert Parser.decode("""
             const a = "abc";
             const b = a;
             """) ==
               {:ok,
                [
                  {:const, "a", "abc"},
                  {:const, "b", [ref: "a"]}
                ]}
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
      assert Parser.decode("""
             function* hello() {
               yield 42;
             }
             """) ==
               {:ok,
                [
                  {:generator_function, "hello", [],
                   [
                     yield: 42.0
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

    test "new URL with base" do
      assert Parser.decode("""
             const aboutLink = new URL("/about", "https://example.org");
             """) ==
               {:ok,
                [{:const, "aboutLink", {:url, [relative: "/about", base: "https://example.org"]}}]}
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
  end
end
