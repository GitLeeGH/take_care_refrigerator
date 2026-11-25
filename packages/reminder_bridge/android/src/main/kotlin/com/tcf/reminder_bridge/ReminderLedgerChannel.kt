package com.tcf.reminder_bridge

import android.content.Context
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.time.LocalDate
import java.util.UUID
import org.json.JSONObject

/** Preparation only: no scheduler or delivery. Register on each engine before
 * use. Same-process synchronized lock protects all foreground/background engines;
 * AtomicFile alone is NOT a mutex. The app must not host workers in another process.
 * Contains no auth tokens, inventory, names or notification content. */
object ReminderLedgerChannel {
    private const val deliveryEnabled = false
    private const val notificationId = 730042
    private const val channelId = "expiry_verified_v1"
    private val lock = Any()
    private const val maxBytes = 32768
    private var workRun: String? = null
    fun beginWork(id: String) = synchronized(lock) { check(workRun == null); workRun = id }
    fun endWork(id: String) = synchronized(lock) { if(workRun == id) workRun = null }
    internal fun workCurrent(id: String?): Boolean = synchronized(lock) { workRun != null && workRun == id }


    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "refrigerator/reminder_ledger_v1")
            .setMethodCallHandler { call, result ->
                try {
                    val response = synchronized(lock) {
                        val root = context.noBackupFilesDir.canonicalFile
                        val file = File(root, "reminder_ledger_v1.json")
                        for (candidate in listOf(file, File(file.path + ".bak"), File(file.path + ".new"))) {
                            require(candidate.canonicalFile == candidate.absoluteFile)
                            require(!candidate.exists() || candidate.length() <= maxBytes)
                        }
                        val atomic = AtomicFile(file)
                        val state = if (!file.exists() && !File(file.path + ".bak").exists()) {
                            JSONObject().put("version", 1).put("claims", JSONObject())
                        } else {
                            atomic.openRead().use { input ->
                                val buffer = ByteArray(maxBytes + 1)
                                var count = 0
                                while (count < buffer.size) {
                                    val read = input.read(buffer, count, buffer.size - count)
                                    if (read < 0) break
                                    count += read
                                }
                                require(count <= maxBytes)
                                JSONObject(String(buffer, 0, count, Charsets.UTF_8))
                            }
                        }
                        require(state.getInt("version") == 1)
                        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        fun permission(): Boolean = manager.areNotificationsEnabled() &&
                            (android.os.Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(channelId)?.importance != android.app.NotificationManager.IMPORTANCE_NONE)
                        val claims = state.getJSONObject("claims")
                        require(claims.length() <= 128)
                        fun persist() {
                            val bytes = state.toString().toByteArray(Charsets.UTF_8)
                            require(bytes.size <= maxBytes)
                            val stream = atomic.startWrite()
                            try { stream.write(bytes); atomic.finishWrite(stream) }
                            catch (error: Throwable) { atomic.failWrite(stream); throw error }
                        }
                        fun ownerHash(): String {
                            val owner = call.argument<String>("owner")
                            require(!owner.isNullOrBlank() && owner.length <= 256)
                            return MessageDigest.getInstance("SHA-256")
                                .digest(owner.toByteArray(Charsets.UTF_8))
                                .joinToString("") { "%02x".format(it.toInt() and 0xff) }
                        }
                        fun current(): Boolean {
                            val active = state.optJSONObject("active") ?: return false
                            return active.getString("owner") == ownerHash() &&
                                active.getString("generation") == call.argument<String>("generation") &&
                                active.getInt("days") == call.argument<Int>("days")
                        }
                        when (call.method) {
                            "activate" -> {
                                val days = call.argument<Int>("days")
                                require(days in listOf(1, 3, 7))
                                val generation = UUID.randomUUID().toString()
                                state.put("active", JSONObject().put("owner", ownerHash())
                                    .put("generation", generation).put("days", days))
                                persist()
                                generation
                            }
                            "invalidate" -> {
                                // Must complete BEFORE logout/account change or setting OFF.
                                // Preserve day claims across OFF/ON and account switches.
                                OneShotReceiptChannel.revoke(context)
                                state.remove("active"); persist()
                                workRun = null
                                if (ReminderWork.enabled) ReminderWork.cancel(context)
                                manager.cancel(channelId, notificationId)
                                null
                            }
                            "current" -> current()
                            "permission" -> permission()
                            "resume" -> {
                                val active = state.optJSONObject("active")
                                if (active == null || active.getString("owner") != ownerHash()) null
                                else mapOf("generation" to active.getString("generation"), "days" to active.getInt("days"))
                            }
                            "deliver" -> {
                                // Compile-time OFF is independent of the Dart gate.
                                require(deliveryEnabled && current() && permission())
                                require(workCurrent(call.argument<String>("runId")))
                                val now = System.currentTimeMillis()
                                val validatedAt = call.argument<Number>("validatedAt")?.toLong() ?: 0L
                                require(validatedAt <= now && now - validatedAt <= 15000)
                                val local = java.time.ZonedDateTime.now()
                                require(local.hour in 9..11)
                                require(call.argument<Int>("offsetMinutes") == local.offset.totalSeconds / 60)
                                val today = local.toLocalDate().toString()
                                val key = ownerHash()
                                require(claims.optString(key, "") == today)
                                val project = call.argument<String>("project") ?: ""
                                require(project.matches(Regex("[a-zA-Z0-9_-]{1,128}")))
                                val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                    .getString("flutter.sb-$project-auth-token", null)
                                require(raw != null && raw.length <= 32768)
                                val session = JSONObject(raw)
                                require(session.getJSONObject("user").getString("id") == call.argument<String>("owner"))
                                require(session.getLong("expires_at") > now / 1000 + 30)
                                val digest = MessageDigest.getInstance("SHA-256")
                                    .digest(session.getString("access_token").toByteArray(Charsets.UTF_8))
                                    .joinToString("") { "%02x".format(it.toInt() and 0xff) }
                                require(digest == call.argument<String>("credentialDigest"))
                                require(!state.has("delivered") || state.opt("delivered") is JSONObject)
                                val delivered = state.optJSONObject("delivered") ?: JSONObject()
                                require(delivered.length() <= 128)
                                val prior = delivered.optString(key, "")
                                require(prior.isEmpty() || local.toLocalDate().isAfter(LocalDate.parse(prior)))
                                require(delivered.has(key) || delivered.length() < 128)
                                delivered.put(key, today); state.put("delivered", delivered)
                                persist() // record attempt BEFORE notify, including uncertain failures
                                val builder = if (android.os.Build.VERSION.SDK_INT >= 26) {
                                    manager.createNotificationChannel(android.app.NotificationChannel(channelId, "재료 기한 확인", android.app.NotificationManager.IMPORTANCE_LOW))
                                    android.app.Notification.Builder(context, channelId)
                                } else android.app.Notification.Builder(context)
                                val notification = builder.setSmallIcon(context.applicationInfo.icon)
                                    .setContentTitle("재료 기한을 확인해 주세요")
                                    .setContentText("앱에서 현재 재고와 포장지 날짜를 확인해 주세요.")
                                    .setVisibility(android.app.Notification.VISIBILITY_PRIVATE)
                                    .setAutoCancel(true).build()
                                manager.notify(channelId, notificationId, notification)
                                null
                            }
                            "claim" -> {
                                if (!current()) false else {
                                    val day = LocalDate.parse(call.argument<String>("day"))
                                    require(day == LocalDate.now())
                                    val key = ownerHash()
                                    val previous = claims.optString(key, "")
                                    if (previous.isNotEmpty() && !day.isAfter(LocalDate.parse(previous))) false
                                    else {
                                        require(claims.has(key) || claims.length() < 128)
                                        claims.put(key, day.toString()); persist(); true
                                    }
                                }
                            }
                            else -> throw IllegalArgumentException("Unsupported ledger operation")
                        }
                    }
                    result.success(response)
                } catch (_: Exception) {
                    // Never propagate file contents, owner IDs, or raw errors.
                    result.error("reminder_state_unavailable", "Reminder state unavailable", null)
                }
            }
    }
}
