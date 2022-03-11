defmodule MiniModules.YieldMachineTest do
  use ExUnit.Case, async: true

  alias MiniModules.UniversalModules.YieldMachine
  alias MiniModules.UniversalModules.Parser

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

  @switch_timer_source Parser.decode(~S"""
                       export function Switch() {
                         function* Off() {
                           yield on(3, On);
                           yield on("short", Disabled)
                         }
                         function* On() {
                           yield on(4, Off);
                         }
                         function* Disabled() {}

                         return Off;
                       }
                       """)
  @switch_timer_expected_components [
    {"Off", 3000, "On"},
    {"Off", "short", "Disabled"},
    {"On", 4000, "Off"}
  ]

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

  @snake_game Parser.decode(~S"""
              export function Snake() {
                function* HeadedNorth() {
                    yield on("left", HeadedWest);
                    yield on("right", HeadedEast);
                }
                function* HeadedWest() {
                    yield on("up", HeadedNorth);
                    yield on("down", HeadedSouth);
                }
                function* HeadedEast() {
                    yield on("up", HeadedNorth);
                    yield on("down", HeadedSouth);
                }
                function* HeadedSouth() {
                    yield on("left", HeadedWest);
                    yield on("right", HeadedEast);
                }
                return HeadedEast;
              }
              """)
  @snake_game_components [
    {"HeadedEast", "up", "HeadedNorth"},
    {"HeadedEast", "down", "HeadedSouth"},
    {"HeadedNorth", "left", "HeadedWest"},
    {"HeadedNorth", "right", "HeadedEast"},
    {"HeadedSouth", "left", "HeadedWest"},
    {"HeadedSouth", "right", "HeadedEast"},
    {"HeadedWest", "up", "HeadedNorth"},
    {"HeadedWest", "down", "HeadedSouth"}
  ]

  setup_all do
    {:ok, switch_module} = @switch_source
    {:ok, switch_timer_module} = @switch_timer_source
    {:ok, advanced_switch_module} = @advanced_switch_source
    {:ok, snake_game} = @snake_game

    [
      switch_module: switch_module,
      switch_timer_module: switch_timer_module,
      advanced_switch_module: advanced_switch_module,
      snake_game: snake_game
    ]
  end

  describe "interpret_machine/1" do
    test "returns initial state", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module) ==
               {:ok,
                %YieldMachine.State{
                  current: "Off",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}
    end
  end

  describe "interpret_machine/2" do
    test "recognizes events", %{
      switch_module: switch_module,
      advanced_switch_module: advanced_switch_module
    } do
      assert YieldMachine.interpret_machine(switch_module, ["FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "On",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(switch_module, ["FLICK", "FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "Off",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(switch_module, ["FLICK", "FLICK", "FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "On",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(advanced_switch_module, ["FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "On",
                  components: @advanced_switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(advanced_switch_module, ["FLICK", "FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "Off",
                  components: @advanced_switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(advanced_switch_module, ["FLICK", "FLICK", "FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "On",
                  components: @advanced_switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}
    end

    test "ignores unknown events", %{switch_module: switch_module} do
      assert YieldMachine.interpret_machine(switch_module, ["BLAH"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "Off",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(switch_module, ["BLAH", "FLICK"]) ==
               {:ok,
                %YieldMachine.State{
                  current: "On",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}

      assert YieldMachine.interpret_machine(switch_module, [
               "BLAH",
               "FLICK",
               "FOO",
               "BLAH",
               "FLICK"
             ]) ==
               {:ok,
                %YieldMachine.State{
                  current: "Off",
                  components: @switch_expected_components,
                  overall_clock: 0,
                  local_clock: 0
                }}
    end

    test "recognizes time events", %{
      switch_timer_module: switch_timer_module
    } do
      off_state = %YieldMachine.State{
        current: "Off",
        components: @switch_timer_expected_components
      }

      on_state = %YieldMachine.State{
        current: "On",
        components: @switch_timer_expected_components
      }

      disabled_state = %YieldMachine.State{
        current: "Disabled",
        components: @switch_timer_expected_components
      }

      assert YieldMachine.interpret_machine(switch_timer_module, []) ==
               {:ok, %{off_state | overall_clock: 0, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [0]) ==
               {:ok, %{off_state | overall_clock: 0, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [1000]) ==
               {:ok, %{off_state | overall_clock: 1000, local_clock: 1000}}

      assert YieldMachine.interpret_machine(switch_timer_module, [1000, "short"]) ==
               {:ok, %{disabled_state | overall_clock: 1000, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [2000]) ==
               {:ok, %{off_state | overall_clock: 2000, local_clock: 2000}}

      assert YieldMachine.interpret_machine(switch_timer_module, [2999]) ==
               {:ok, %{off_state | overall_clock: 2999, local_clock: 2999}}

      assert YieldMachine.interpret_machine(switch_timer_module, [2998, 1]) ==
               {:ok, %{off_state | overall_clock: 2999, local_clock: 2999}}

      assert YieldMachine.interpret_machine(switch_timer_module, [3000]) ==
               {:ok, %{on_state | overall_clock: 3000, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [2999, 1]) ==
               {:ok, %{on_state | overall_clock: 3000, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [3001]) ==
               {:ok, %{on_state | overall_clock: 3001, local_clock: 1}}

      assert YieldMachine.interpret_machine(switch_timer_module, [3002]) ==
               {:ok, %{on_state | overall_clock: 3002, local_clock: 2}}

      assert YieldMachine.interpret_machine(switch_timer_module, [6999]) ==
               {:ok, %{on_state | overall_clock: 6999, local_clock: 3999}}

      assert YieldMachine.interpret_machine(switch_timer_module, [6998, 1]) ==
               {:ok, %{on_state | overall_clock: 6999, local_clock: 3999}}

      assert YieldMachine.interpret_machine(switch_timer_module, [7000]) ==
               {:ok, %{off_state | overall_clock: 7000, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [6999, 1]) ==
               {:ok, %{off_state | overall_clock: 7000, local_clock: 0}}

      assert YieldMachine.interpret_machine(switch_timer_module, [7001]) ==
               {:ok, %{off_state | overall_clock: 7001, local_clock: 1}}

      assert YieldMachine.interpret_machine(switch_timer_module, [6999, 1, 1]) ==
               {:ok, %{off_state | overall_clock: 7001, local_clock: 1}}
    end

    test "snake game", %{snake_game: snake_game} do
      headed_east = %YieldMachine.State{
        current: "HeadedEast",
        components: @snake_game_components,
        overall_clock: 0,
        local_clock: 0
      }
      headed_north = %YieldMachine.State{
        current: "HeadedNorth",
        components: @snake_game_components,
        overall_clock: 0,
        local_clock: 0
      }

      assert YieldMachine.interpret_machine(snake_game, []) ==
               {:ok, headed_east}
      assert YieldMachine.interpret_machine(snake_game, ["up"]) ==
               {:ok, headed_north}
      assert YieldMachine.interpret_machine(snake_game, ["up", "right"]) ==
               {:ok, headed_east}
    end
  end
end
