defmodule MiniModules.YieldMachineTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.YieldMachine
  alias MiniModules.UniversalModules.Parser

  doctest YieldMachine

  @switch_source Parser.decode(~S"""
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

  setup_all do
    {:ok, switch_module} = @switch_source

    [
      switch_module: switch_module
    ]
  end

  describe "interpret_machine/2" do
    test "switch module", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module) == {:ok, %{state: "OFF"}}
    end
  end
end
