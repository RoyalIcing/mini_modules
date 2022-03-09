defmodule MiniModules.ImportResolverTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser
  alias MiniModules.UniversalModules.ImportResolver

  doctest ImportResolver

  @const_source Parser.decode(~S"""
                export const pi = 3.14;
                export const home = new URL("https://example.org");
                export const about = new URL("/about", home);
                """)

  @switch_source Parser.decode(~S"""
                 export function Switch() {
                   function* Off() {
                     yield on("FLICK", On);
                   }
                   function* On() {
                     yield on("FLICK", Off);
                   }

                   return Off;
                 }
                 """)

  @youtube_parser_source Parser.decode(~S"""
                         function* VideoID() {
                           const [videoID] = yield /^[a-zA-Z0-9_]+$/;
                           return videoID;
                         }
                         export function* Long() {
                           yield "https://www.youtube.com/watch?v=";
                           const videoID = yield VideoID;
                           return videoID;
                         }
                         """)

  setup_all do
    {:ok, const_module} = @const_source
    {:ok, switch_module} = @switch_source
    {:ok, youtube_parser_module} = @youtube_parser_source

    [
      const_module: const_module,
      switch_module: switch_module,
      youtube_parser_module: youtube_parser_module
    ]
  end

  describe "transform/2" do
    test "uses result of callback to create a new module", %{
      const_module: const_module,
      switch_module: switch_module
    } do
      {:ok, result} =
        Parser.decode(~S"""
        import { pi } from "https://example.org/const.js";
        import { Switch } from "https://example.org/switch-machine.js";
        import { NotLoaded } from "https://example.org/not-loaded.js";

        const enabled = false;

        export { pi };
        export { Switch };
        export { NotLoaded };
        """)

      assert ImportResolver.transform(result, fn
               "https://example.org/const.js" -> {:ok, const_module}
               "https://example.org/switch-machine.js" -> {:ok, switch_module}
               "https://example.org/not-loaded.js" -> {:ok, nil}
               _ -> :error
             end) ==
               {:ok,
                [
                  {:const, "home", {:url, "https://example.org"}},
                  {:const, "about", {:url, [relative: "/about", base: {:ref, "home"}]}},
                  {:const, "enabled", false},
                  {:export, {:const, "pi", 3.14}},
                  {:export,
                   {:function, "Switch", [],
                    [
                      {:generator_function, "Off", [],
                       [
                         yield: {:call, {:ref, "on"}, ["FLICK", {:ref, "On"}]}
                       ]},
                      {:generator_function, "On", [],
                       [
                         yield: {:call, {:ref, "on"}, ["FLICK", {:ref, "Off"}]}
                       ]},
                      {:return, {:ref, "Off"}}
                    ]}},
                  {:export, [{:ref, "NotLoaded"}]}
                ],
                %{
                  imported_modules: %{
                    "https://example.org/const.js" => const_module,
                    "https://example.org/switch-machine.js" => switch_module
                  }
                }}
    end

    test "includes", %{
      youtube_parser_module: youtube_parser_module
    } do
      {:ok, result} =
        Parser.decode(~S"""
        import { Long } from "https://example.org/youtube.js";
        export { Long };
        """)

      assert ImportResolver.transform(result, fn
               "https://example.org/youtube.js" -> {:ok, youtube_parser_module}
               _ -> :error
             end) ==
               {:ok,
                [
                  {:generator_function, "VideoID", [],
                   [
                     {:const, ["videoID"], {:yield, {:regex, "^[a-zA-Z0-9_]+$"}}},
                     {:return, {:ref, "videoID"}}
                   ]},
                  {:export,
                   {:generator_function, "Long", [],
                    [
                      {:yield, "https://www.youtube.com/watch?v="},
                      {:const, "videoID", {:yield, {:ref, "VideoID"}}},
                      {:return, {:ref, "videoID"}}
                    ]}}
                ],
                %{
                  imported_modules: %{
                    "https://example.org/youtube.js" => youtube_parser_module
                  }
                }}
    end
  end
end
