import LeanTest
import Lasagna

open LeanTest

-- This test file mirrors the "Lasagna" example from the Exercism test
-- runner interface spec's `task_id` documentation, to exercise the v3
-- `task_id` code path even though no Concept Exercises exist on the track
-- yet: https://exercism.org/docs/building/tooling/test-runners/interface

def lasagnaTests : TestSuite :=
  (TestSuite.empty "Lasagna")
  |>.addTest "Expected oven time in minutes" (do
      return assertEqual 40 Lasagna.expectedMinutesInOven) (taskId := some 1)
  |>.addTest "Remaining oven time in minutes" (do
      return assertEqual 10 (Lasagna.remainingMinutesInOven 30)) (taskId := some 2)

def main : IO UInt32 := do
  runTestSuitesWithExitCode [lasagnaTests]
