package com.tcf.reminder_bridge

import java.time.LocalDate
import java.time.ZonedDateTime

/** Calendar-only calculations: no credentials, storage, or Android dependencies. */
internal object LocalExpiryPlanner {
    fun dates(values: List<String>): List<LocalDate> {
        require(values.size <= 500)
        val parsed = values.map {
            require(it.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}")))
            LocalDate.parse(it).also { date -> require(date.year in 1..9999) }
        }
        require(parsed.distinct().size == parsed.size)
        return parsed.sorted()
    }

    fun eligible(dates: List<LocalDate>, days: Int, day: LocalDate): Boolean {
        require(days in listOf(1, 3, 7))
        return dates.any { !it.isBefore(day) && !it.isAfter(day.plusDays(days.toLong())) }
    }

    fun next(dates: List<LocalDate>, days: Int, now: ZonedDateTime, claimed: LocalDate?): ZonedDateTime? {
        require(days in listOf(1, 3, 7))
        return dates.asSequence().flatMap { expiry ->
            (0..days).asSequence().map { expiry.minusDays(it.toLong()) }
        }.distinct().filter { claimed == null || it.isAfter(claimed) }
            .map { it.atTime(9, 0).atZone(now.zone) }.filter { it.isAfter(now) }.minOrNull()
    }

    fun canDeliver(dates: List<LocalDate>, days: Int, now: ZonedDateTime, scheduled: LocalDate, claimed: LocalDate?): Boolean =
        now.hour in 9..11 && now.toLocalDate() == scheduled &&
            (claimed == null || scheduled.isAfter(claimed)) && eligible(dates, days, scheduled)
}
