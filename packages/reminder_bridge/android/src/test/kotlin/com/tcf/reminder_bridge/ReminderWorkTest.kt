package com.tcf.reminder_bridge
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ReminderWorkTest {
    @Test fun waitsForCompletion() = runTest {
        var cleaned=false
        val result=async { awaitReminderCompletion(5000, { delay(2000); "done" }, { cleaned=true }) }
        runCurrent(); assertFalse(result.isCompleted); assertFalse(cleaned)
        advanceTimeBy(2000); runCurrent(); assertEquals("done",result.await()); assertTrue(cleaned)
    }
    @Test fun timeoutCleansUp() = runTest {
        var cleaned=false
        val result=async { runCatching { awaitReminderCompletion(1000, { delay(5000) }, { cleaned=true }) } }
        advanceUntilIdle(); assertTrue(result.await().exceptionOrNull() is TimeoutCancellationException); assertTrue(cleaned)
    }
    @Test fun cancellationCleansUp() = runTest {
        var cleaned=false
        val job=launch { awaitReminderCompletion(5000, { awaitCancellation() }, { cleaned=true }) }
        runCurrent(); job.cancelAndJoin(); assertTrue(cleaned)
    }
    @Test fun staleRunCannotDispatchOrClearNewRun() {
        ReminderLedgerChannel.beginWork("first")
        assertTrue(ReminderLedgerChannel.workCurrent("first"))
        assertFalse(ReminderLedgerChannel.workCurrent(null))
        ReminderLedgerChannel.endWork("first")
        assertFalse(ReminderLedgerChannel.workCurrent("first"))
        ReminderLedgerChannel.beginWork("second")
        ReminderLedgerChannel.endWork("first")
        assertTrue(ReminderLedgerChannel.workCurrent("second"))
        ReminderLedgerChannel.endWork("second")
    }
    @Test fun disabledByDefault() { assertFalse(ReminderWork.enabled) }
}
