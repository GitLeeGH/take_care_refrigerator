package com.tcf.reminder_bridge

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.ZonedDateTime

class LocalExpiryPlannerTest {
    private fun dates(vararg values: String) = LocalExpiryPlanner.dates(values.toList())
    @Test fun includesZeroThroughThreeDaysOnly() {
        val day = LocalDate.parse("2026-11-10")
        assertTrue(LocalExpiryPlanner.eligible(dates("2026-11-10"), 3, day))
        assertTrue(LocalExpiryPlanner.eligible(dates("2026-11-13"), 3, day))
        assertFalse(LocalExpiryPlanner.eligible(dates("2026-11-09", "2026-11-14"), 3, day))
    }
    @Test fun picksTodayOnlyBeforeNineOtherwiseNextMorning() {
        val inventory = dates("2026-11-12")
        assertEquals("2026-11-10T09:00+09:00[Asia/Seoul]", LocalExpiryPlanner.next(inventory, 3,
            ZonedDateTime.parse("2026-11-10T08:59+09:00[Asia/Seoul]"), null).toString())
        assertEquals("2026-11-11T09:00+09:00[Asia/Seoul]", LocalExpiryPlanner.next(inventory, 3,
            ZonedDateTime.parse("2026-11-10T09:00+09:00[Asia/Seoul]"), null).toString())
    }
    @Test fun expiryTodayAfterNineAndEmptyHaveNoFutureAlarm() {
        val now = ZonedDateTime.parse("2026-11-10T10:00+09:00[Asia/Seoul]")
        assertNull(LocalExpiryPlanner.next(emptyList(), 3, now, null))
        assertNull(LocalExpiryPlanner.next(dates("2026-11-10"), 3, now, null))
        assertNull(LocalExpiryPlanner.next(dates("2026-11-09"), 3, now, null))
    }
    @Test fun daylightSavingUsesLocalNineNotTwentyFourHours() {
        val now = ZonedDateTime.parse("2026-03-07T10:00-05:00[America/New_York]")
        val next = LocalExpiryPlanner.next(dates("2026-03-09"), 3, now, null)!!
        assertEquals("2026-03-08T09:00-04:00[America/New_York]", next.toString())
        val fall = LocalExpiryPlanner.next(dates("2026-11-02"), 3,
            ZonedDateTime.parse("2026-10-31T10:00-04:00[America/New_York]"), null)!!
        assertEquals("2026-11-01T09:00-05:00[America/New_York]", fall.toString())
    }
    @Test fun duplicateEligibleDaysProduceOneEarliestTime() {
        assertEquals("2026-11-10", LocalExpiryPlanner.next(dates("2026-11-12", "2026-11-13"), 3,
            ZonedDateTime.parse("2026-11-10T08:00Z"), null)!!.toLocalDate().toString())
    }
    @Test fun claimsPreventRepeatAndClockRollback() {
        val now = ZonedDateTime.parse("2026-11-10T09:30Z")
        val day = now.toLocalDate()
        assertFalse(LocalExpiryPlanner.canDeliver(dates("2026-11-13"), 3, now, day, day))
        assertFalse(LocalExpiryPlanner.canDeliver(dates("2026-11-13"), 3, now, day, day.plusDays(1)))
        assertEquals("2026-11-12", LocalExpiryPlanner.next(dates("2026-11-13"), 3, now,
            day.plusDays(1))!!.toLocalDate().toString())
    }
    @Test fun deliveryWindowAndScheduledDateAreChecked() {
        val day = LocalDate.parse("2026-11-10")
        val inventory = dates("2026-11-13")
        assertTrue(LocalExpiryPlanner.canDeliver(inventory, 3, ZonedDateTime.parse("2026-11-10T09:00Z"), day, null))
        assertTrue(LocalExpiryPlanner.canDeliver(inventory, 3, ZonedDateTime.parse("2026-11-10T11:59Z"), day, null))
        assertFalse(LocalExpiryPlanner.canDeliver(inventory, 3, ZonedDateTime.parse("2026-11-10T08:59Z"), day, null))
        assertFalse(LocalExpiryPlanner.canDeliver(inventory, 3, ZonedDateTime.parse("2026-11-10T12:00Z"), day, null))
        assertFalse(LocalExpiryPlanner.canDeliver(inventory, 3, ZonedDateTime.parse("2026-11-11T09:00Z"), day, null))
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsDuplicateExpiryDates() { dates("2026-11-10", "2026-11-10") }
    @Test(expected = IllegalArgumentException::class) fun rejectsInvalidDays() {
        LocalExpiryPlanner.eligible(dates("2026-11-10"), 2, LocalDate.parse("2026-11-10"))
    }
    @Test(expected = java.time.DateTimeException::class) fun rejectsInvalidDate() { dates("2026-02-30") }
    @Test(expected = IllegalArgumentException::class) fun rejectsZeroYear() { dates("0000-11-10") }
    @Test(expected = IllegalArgumentException::class) fun rejectsMoreThanFiveHundred() {
        LocalExpiryPlanner.dates((0..500).map { LocalDate.parse("2026-11-10").plusDays(it.toLong()).toString() })
    }
}
