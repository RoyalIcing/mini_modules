defmodule MiniModules.JSONEncoderTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser
  alias MiniModules.UniversalModules.JSONEncoder

  doctest Parser

  def subject(source) do
    {:ok, module} = Parser.decode(source)
    JSONEncoder.to_json(module)
  end

  describe "to_json/1" do
    test "empty" do
      assert subject("") == %{}
    end

    test "const not exported" do
      assert subject(~S"""
             // Hello
             const isEnabled = true;
             """) == %{}
    end

    test "export const boolean" do
      assert subject(~S"""
             export const isEnabled = true;
             """) == %{"isEnabled" => true}
    end

    test "export const null" do
      assert subject(~S"""
             export const isEnabled = null;
             """) == %{"isEnabled" => nil}
    end

    test "export const number" do
      assert subject(~S"""
             export const a = 1;
             """) == %{"a" => 1.0}
    end

    test "export const string" do
      assert subject(~S"""
             export const a = "abc";
             """) == %{"a" => "abc"}
    end

    test "new URL" do
      assert subject(~S"""
             export const root = new URL("https://example.org");
             """) == %{"root" => "https://example.org"}
    end

    test "new URL with string base" do
      assert subject(~S"""
             export const aboutLink = new URL("/about", "https://example.org");
             """) == %{"aboutLink" => "https://example.org/about"}
    end

    test "new URL with ref base" do
      assert subject(~S"""
             export const homeLink = new URL("https://example.org");
             export const aboutLink1 = new URL("about", homeLink);
             export const aboutLink2 = new URL("./about", homeLink);
             export const aboutLink3 = new URL("/about", homeLink);
             export const legalLink = new URL("legal/", homeLink);
             export const legalTermsLink1 = new URL("terms", legalLink);
             export const legalTermsLink2 = new URL("./terms", legalLink);
             export const legalTermsLink3 = new URL("/terms", legalLink);
             """) == %{
               "homeLink" => "https://example.org",
               "aboutLink1" => "https://example.org/about",
               "aboutLink2" => "https://example.org/about",
               "aboutLink3" => "https://example.org/about",
               "legalLink" => "https://example.org/legal/",
               "legalTermsLink1" => "https://example.org/legal/terms",
               "legalTermsLink2" => "https://example.org/legal/terms",
               "legalTermsLink3" => "https://example.org/terms"
             }
    end

    test "new Set" do
      assert subject(~S"""
             export const luckyNumbers = new Set([1, 2, 3]);
             """) == %{"luckyNumbers" => [1, 2, 3]}
    end
  end
end
