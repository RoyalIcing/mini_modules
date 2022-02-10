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

  describe "interpret_machine/1" do
    test "returns initial state", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module) == {:ok, %{state: "OFF"}}
    end
  end

  describe "interpret_machine/2" do
    test "recognizes events", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module, ["FLICK"]) ==
               {:ok, %{state: "ON"}}

      assert YieldMachine.interpret_machine(switch_module, ["FLICK", "FLICK"]) ==
               {:ok, %{state: "OFF"}}

      assert YieldMachine.interpret_machine(switch_module, ["FLICK", "FLICK", "FLICK"]) ==
               {:ok, %{state: "ON"}}
    end

    test "ignores unknown events", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module, ["BLAH"]) ==
               {:ok, %{state: "OFF"}}

      assert YieldMachine.interpret_machine(switch_module, ["BLAH", "FLICK"]) ==
               {:ok, %{state: "ON"}}

      assert YieldMachine.interpret_machine(switch_module, [
               "BLAH",
               "FLICK",
               "FOO",
               "BLAH",
               "FLICK"
             ]) == {:ok, %{state: "OFF"}}
    end
  end
end
