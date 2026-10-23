package io.appbeyond.freelance.deep.feature.mindgarden.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/** The practice card's two derived figures (`GardenState.swift`). */
class GardenStateTest {

  @Test
  @DisplayName("Progress is today's share of the goal, clamped to one")
  fun progress() {
    assertEquals(0.7, GardenState.sample.progress, 1e-9)
    assertEquals(1.0, GardenState(minutesToday = 25, dailyGoalMinutes = 10, streakDays = 0).progress)
    assertEquals(0.0, GardenState(minutesToday = 5, dailyGoalMinutes = 0, streakDays = 0).progress)
  }

  @Test
  @DisplayName("Minutes remaining never go below zero")
  fun minutesRemaining() {
    assertEquals(3, GardenState.sample.minutesRemaining)
    assertEquals(0, GardenState.flourishing.minutesRemaining)
    assertEquals(0, GardenState(minutesToday = 25, dailyGoalMinutes = 10, streakDays = 0).minutesRemaining)
  }
}
