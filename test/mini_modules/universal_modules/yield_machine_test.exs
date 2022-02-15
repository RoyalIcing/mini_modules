defmodule MiniModules.YieldMachineTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.YieldMachine
  alias MiniModules.UniversalModules.Parser
  alias MiniModules.UniversalModules.ImportResolver

  doctest YieldMachine

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
  @switch_expected_components [{"Off", "FLICK", "On"}, {"On", "FLICK", "Off"}]

  @advanced_switch_source Parser.decode(~S"""
                          export function Switch() {
                            function* Off() {
                              yield on("FLICK", On);
                            }
                            function* On() {
                              yield on("FLICK", Off);
                              yield on("SHORT", CircuitBreakerTripped);
                            }
                            function* CircuitBreakerTripped() {
                              yield on("FLICK_CIRCUIT_BREAKER", Off);
                            }

                            return Off;
                          }
                          """)
  @advanced_switch_expected_components [
    {"CircuitBreakerTripped", "FLICK_CIRCUIT_BREAKER", "Off"},
    {"Off", "FLICK", "On"},
    {"On", "FLICK", "Off"},
    {"On", "SHORT", "CircuitBreakerTripped"}
  ]

  # @imported_switch_source with(
  #                           {:ok, result} <-
  #                             Parser.decode(~S"""
  #                             import { Switch } from "https://example.org/switch-machine.js";
  #                             export { Switch };
  #                             """),
  #                           do:
  #                             ImportResolver.transform(result, fn
  #                               "https://example.org/switch-machine.js" -> @switch_source
  #                               _ -> :error
  #                             end)
  #                         )

  setup_all do
    {:ok, switch_module} = @switch_source
    {:ok, advanced_switch_module} = @advanced_switch_source

    [
      switch_module: switch_module,
      advanced_switch_module: advanced_switch_module
    ]
  end

  describe "interpret_machine/1" do
    test "returns initial state", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module) ==
               {:ok, %{current: "Off", components: @switch_expected_components}}
    end
  end

  describe "interpret_machine/2" do
    test "recognizes events", %{
      switch_module: switch_module,
      advanced_switch_module: advanced_switch_module
    } do
      assert YieldMachine.interpret_machine(switch_module, ["FLICK"]) ==
               {:ok, %{current: "On", components: @switch_expected_components}}

      assert YieldMachine.interpret_machine(switch_module, ["FLICK", "FLICK"]) ==
               {:ok, %{current: "Off", components: @switch_expected_components}}

      assert YieldMachine.interpret_machine(switch_module, ["FLICK", "FLICK", "FLICK"]) ==
               {:ok, %{current: "On", components: @switch_expected_components}}

      assert YieldMachine.interpret_machine(advanced_switch_module, ["FLICK"]) ==
               {:ok, %{current: "On", components: @advanced_switch_expected_components}}

      assert YieldMachine.interpret_machine(advanced_switch_module, ["FLICK", "FLICK"]) ==
               {:ok, %{current: "Off", components: @advanced_switch_expected_components}}

      assert YieldMachine.interpret_machine(advanced_switch_module, ["FLICK", "FLICK", "FLICK"]) ==
               {:ok, %{current: "On", components: @advanced_switch_expected_components}}
    end

    test "ignores unknown events", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module, ["BLAH"]) ==
               {:ok, %{current: "Off", components: @switch_expected_components}}

      assert YieldMachine.interpret_machine(switch_module, ["BLAH", "FLICK"]) ==
               {:ok, %{current: "On", components: @switch_expected_components}}

      assert YieldMachine.interpret_machine(switch_module, [
               "BLAH",
               "FLICK",
               "FOO",
               "BLAH",
               "FLICK"
             ]) == {:ok, %{current: "Off", components: @switch_expected_components}}
    end
  end
end
