defmodule MiniModules.ParserTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser

  doctest Parser

  describe "decode/1" do
    test "empty" do
      assert Parser.decode("") == {:ok, []}
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
             """) == {:ok, [{:generator_function, "hello", [], [yield: 42.0]}]}
    end
  end
end
