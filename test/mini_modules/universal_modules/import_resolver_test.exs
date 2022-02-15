defmodule MiniModules.ImportResolverTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.Parser
  alias MiniModules.UniversalModules.ImportResolver

  doctest ImportResolver

  @const_source Parser.decode(~S"""
                export const pi = 3.14;
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

  setup_all do
    {:ok, const_module} = @const_source
    {:ok, switch_module} = @switch_source

    [
      const_module: const_module,
      switch_module: switch_module
    ]
  end

  describe "transform/2" do
    test "uses callback", %{
      const_module: const_module,
      switch_module: switch_module
    } do
      {:ok, result} =
        Parser.decode(~S"""
        import { pi } from "https://example.org/const.js";
        import { Switch } from "https://example.org/switch-machine.js";
        export { pi };
        export { Switch };
        """)

      assert ImportResolver.transform(result, fn
               "https://example.org/const.js" -> {:ok, const_module}
               "https://example.org/switch-machine.js" -> {:ok, switch_module}
               _ -> :error
             end) ==
               {:ok,
                [
                  export: {:const, "pi", 3.14},
                  export:
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
                     ]}
                ]}
    end
  end
end
