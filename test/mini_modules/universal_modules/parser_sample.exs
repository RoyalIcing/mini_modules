Benchee.run(
  %{
    "empty" => fn ->
      MiniModules.UniversalModules.Parser.decode("")
    end,
    "const true" => fn ->
      MiniModules.UniversalModules.Parser.decode(~S"""
      const isEnabled = true;
      """)
    end,
    "imports" => fn ->
      MiniModules.UniversalModules.Parser.decode(~S"""
      import { a } from "https://first.org";
      import { a, b } from "https://second.org";
      import * as foo from "https://third.org";
      """)
    end,
    "yieldmachine" => fn ->
      MiniModules.UniversalModules.Parser.decode(~S"""
      export function Switch() {
        function* OFF() {
          yield on("FLICK", ON);
        }
        function* ON() {
          yield on("FLICK", OFF);
        }

        return OFF;
      }
      """)
    end
  },
  memory_time: 2
)
