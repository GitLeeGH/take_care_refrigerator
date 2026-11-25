package com.tcf.reminder_bridge

import android.content.Context
import androidx.work.*
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.UUID
import java.util.concurrent.TimeUnit

/** No credentials or inventory are ever put in WorkRequest data. OFF until device validation. */
object ReminderWork {
    const val enabled = false
    private const val name = "verified_expiry_work_v1"
    fun schedule(context: Context): Boolean {
        if (!enabled) return false
        val request = PeriodicWorkRequestBuilder<ReminderWorker>(1, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(name, ExistingPeriodicWorkPolicy.KEEP, request)
        return true // Enqueued, NOT proof of execution or exact timing.
    }
    fun cancel(context: Context) { WorkManager.getInstance(context).cancelUniqueWork(name) }
    fun register(context: Context, messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, "refrigerator/reminder_work_v1").setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "schedule" -> result.success(schedule(context))
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("work_unavailable", "Reminder work unavailable", null) }
        }
    }
}

/** Future completion, cancellation and timeout share one structured coroutine scope. */
internal suspend fun <T> awaitReminderCompletion(timeoutMillis: Long, run: suspend () -> T, cleanup: suspend () -> Unit): T {
    try { return withTimeout(timeoutMillis) { run() } }
    finally { withContext(NonCancellable) { cleanup() } }
}

class ReminderWorker(context: Context, params: WorkerParameters): CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (!ReminderWork.enabled) return Result.success()
        val runId = UUID.randomUUID().toString()
        var engine: FlutterEngine? = null
        var channel: MethodChannel? = null
        val completion = CompletableDeferred<String>()
        try {
            val status = awaitReminderCompletion(45000, {
                withContext(Dispatchers.Main.immediate) {
                    ReminderLedgerChannel.beginWork(runId)
                    val loader = FlutterInjector.instance().flutterLoader()
                    loader.startInitialization(applicationContext)
                    loader.ensureInitializationComplete(applicationContext, null)
                    val current = FlutterEngine(applicationContext); engine = current
                    channel = MethodChannel(current.dartExecutor.binaryMessenger, "refrigerator/reminder_completion_v1")
                    channel!!.setMethodCallHandler { call, reply ->
                        when(call.method) {
                            "start" -> reply.success(runId)
                            "complete" -> {
                                val status = call.argument<String>("status")
                                if(call.argument<String>("runId") == runId && status in listOf("sent", "skipped", "unavailable")) {
                                    completion.complete(status!!); reply.success(null)
                                } else { reply.error("invalid_completion", "Invalid completion", null) }
                            }
                            else -> reply.notImplemented()
                        }
                    }
                    current.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "verifiedExpiryWorkEntrypoint"))
                }
                completion.await()
            }, {
                // Same ledger lock as final notify: queued stale requests fail closed.
                ReminderLedgerChannel.endWork(runId)
                withContext(Dispatchers.Main.immediate) {
                    channel?.setMethodCallHandler(null); engine?.destroy()
                }
            })
            // Transient failure skips this interval, avoiding retries outside today's window.
            return if(status in listOf("sent", "skipped", "unavailable")) Result.success() else Result.failure()
        } catch (e: CancellationException) { throw e }
        catch (_: Exception) { return Result.failure() }
    }
}
