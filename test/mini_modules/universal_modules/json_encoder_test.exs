defmodule MiniModules.JSONEncoderTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser
  alias MiniModules.UniversalModules.JSONEncoder

  doctest Parser

  def subject(source) do
    with {:ok, module} <- Parser.decode(source) do
      JSONEncoder.to_json(module)
    end
  end

  describe "to_json/1" do
    test "empty" do
      assert subject("") == %{}
    end

    test "const not exported" do
      assert subject("""
             const isEnabled = true;
             """) == %{}
    end

    test "export const number" do
      assert subject("""
             export const a = 1;
             """) == %{"a" => 1.0}
    end

    test "export const string" do
      assert subject("""
             export const a = "abc";
             """) == %{"a" => "abc"}
    end

    test "new URL" do
      assert subject("""
             export const root = new URL("https://example.org");
             """) == %{"root" => "https://example.org"}
    end

    test "new URL with base" do
      assert subject("""
             export const aboutLink = new URL("/about", "https://example.org");
             """) == %{"aboutLink" => "https://example.org/about"}
    end

    test "new Set" do
      assert subject("""
             export const luckyNumbers = new Set([1, 2, 3]);
             """) == %{"luckyNumbers" => [1, 2, 3]}
    end
  end
end
