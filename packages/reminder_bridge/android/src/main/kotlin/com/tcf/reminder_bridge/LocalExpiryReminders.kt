package com.tcf.reminder_bridge

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.UUID

/** Device-synced expiry dates only. This path intentionally never refreshes auth. */
object LocalExpiryReminders {
    private val lock = Any()
    private const val channelId = "local_expiry_v1"
    private const val normalAction = "com.tcf.reminder_bridge.LOCAL_EXPIRY"
    private const val testAction = "com.tcf.reminder_bridge.LOCAL_EXPIRY_TEST"
    private const val normalId = 730050
    private const val testId = 730051
    private const val maxBytes = 65536

    private fun hash(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it.toInt() and 255) }
    private fun owner(value: String?): String {
        require(!value.isNullOrBlank() && value.length <= 256)
        return hash(value)
    }
    private fun manager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun permitted(context: Context): Boolean {
        val manager = manager(context)
        return manager.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 ||
            manager.getNotificationChannel(channelId)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    private fun file(context: Context): AtomicFile {
        val root = context.noBackupFilesDir.canonicalFile
        val target = File(root, "local_expiry_v1.json")
        listOf(target, File(target.path + ".bak"), File(target.path + ".new")).forEach {
            require(it.canonicalFile == it.absoluteFile && (!it.exists() || it.length() <= maxBytes))
        }
        return AtomicFile(target)
    }
    private fun persist(context: Context, state: JSONObject) {
        val bytes = state.toString().toByteArray(Charsets.UTF_8)
        require(bytes.size <= maxBytes)
        val atomic = file(context)
        val stream = atomic.startWrite()
        try { stream.write(bytes); atomic.finishWrite(stream) }
        catch (error: Throwable) { atomic.failWrite(stream); throw error }
    }
    private fun parseDates(array: JSONArray): List<LocalDate> {
        require(array.length() <= 500)
        return LocalExpiryPlanner.dates((0 until array.length()).map { array.get(it).also { v -> require(v is String) } as String })
    }
    private fun state(context: Context): JSONObject {
        val atomic = file(context)
        val target = atomic.baseFile
        if (!target.exists() && !File(target.path + ".bak").exists()) {
            return JSONObject().put("version", 1).put("revision", UUID.randomUUID().toString())
                .put("claims", JSONObject()).also { persist(context, it) }
        }
        val value = atomic.openRead().use { stream ->
            val buffer = ByteArray(maxBytes + 1)
            var count = 0
            while (count < buffer.size) {
                val got = stream.read(buffer, count, buffer.size - count)
                if (got < 0) break
                count += got
            }
            require(count <= maxBytes)
            JSONObject(String(buffer, 0, count, Charsets.UTF_8))
        }
        require(value.getInt("version") == 1)
        UUID.fromString(value.getString("revision"))
        val claims = value.getJSONObject("claims")
        require(claims.length() <= 128)
        claims.keys().forEach { key ->
            require(key.matches(Regex("[a-f0-9]{64}")))
            LocalDate.parse(claims.getString(key))
        }
        if (value.has("active")) {
            val active = value.getJSONObject("active")
            require(active.getString("owner").matches(Regex("[a-f0-9]{64}")))
            require(active.getString("project").matches(Regex("[a-zA-Z0-9_-]{1,128}")))
            UUID.fromString(active.getString("generation"))
            require(active.getInt("days") in listOf(1, 3, 7))
            require(active.has("updatedAt") && (active.isNull("updatedAt") || active.getLong("updatedAt") > 0))
            val dates = parseDates(active.getJSONArray("dates"))
            require(!active.isNull("updatedAt") || dates.isEmpty())
            if (active.has("scheduledDay")) LocalExpiryPlanner.dates(listOf(active.getString("scheduledDay")))
        }
        return value
    }
    private fun identityMatches(context: Context, active: JSONObject): Boolean = try {
        val project = active.getString("project")
        val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.sb-$project-auth-token", null)
        if (raw == null || raw.length > 32768) false else {
            val id = JSONObject(raw).getJSONObject("user").getString("id")
            id.isNotBlank() && id.length <= 256 && hash(id) == active.getString("owner")
        }
    } catch (_: Exception) { false }
    private fun claimed(state: JSONObject, active: JSONObject): LocalDate? {
        val text = state.getJSONObject("claims").optString(active.getString("owner"), "")
        return if (text.isEmpty()) null else LocalDate.parse(text)
    }
    private fun intent(context: Context, test: Boolean) = Intent(context, LocalExpiryReceiver::class.java)
        .setAction(if (test) testAction else normalAction)
    private fun pending(context: Context, test: Boolean, generation: String = "", day: String = "", dueAt: Long = 0): PendingIntent =
        PendingIntent.getBroadcast(context, if (test) testId else normalId,
            intent(context, test).putExtra("generation", generation).putExtra("day", day).putExtra("dueAt", dueAt),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(context: Context, test: Boolean) {
        val pi = PendingIntent.getBroadcast(context, if (test) testId else normalId, intent(context, test),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pi != null) { (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi); pi.cancel() }
        manager(context).cancel(if (test) "${channelId}_test" else channelId, if (test) testId else normalId)
    }
    private fun alarm(context: Context, test: Boolean, at: Long, generation: String, day: String) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, test, generation, day, at))
    }
    private fun next(state: JSONObject, active: JSONObject): ZonedDateTime? {
        val now = ZonedDateTime.now()
        val dates = parseDates(active.getJSONArray("dates"))
        // Do not cancel today's already scheduled, OS-delayed alarm on a read/sync.
        // A new enable after 09:00 still starts with the next future morning.
        if (active.optString("scheduledDay", "") == now.toLocalDate().toString() &&
            LocalExpiryPlanner.canDeliver(dates, active.getInt("days"), now, now.toLocalDate(), claimed(state, active))) {
            return now.toLocalDate().atTime(9, 0).atZone(now.zone)
        }
        return LocalExpiryPlanner.next(dates, active.getInt("days"), now, claimed(state, active))
    }
    private fun rearm(context: Context, state: JSONObject) {
        // Cancel only our alarm here; leave an already displayed daily reminder visible.
        val pi = PendingIntent.getBroadcast(context, normalId, intent(context, false), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pi != null) { (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi); pi.cancel() }
        val active = state.optJSONObject("active") ?: return
        if (!identityMatches(context, active) || !permitted(context)) return
        val at = next(state, active)
        if (at == null) { active.remove("scheduledDay"); persist(context, state); return }
        active.put("scheduledDay", at.toLocalDate().toString()); persist(context, state)
        alarm(context, false, at.toInstant().toEpochMilli(), active.getString("generation"), at.toLocalDate().toString())
    }
    private fun read(context: Context, state: JSONObject, ownerHash: String): Map<String, Any?> {
        val active = state.optJSONObject("active")?.takeIf { it.getString("owner") == ownerHash }
        return mapOf("enabled" to (active != null), "days" to (active?.getInt("days") ?: 3),
            "revision" to state.getString("revision"), "generation" to active?.getString("generation"),
            "nextAt" to (if (active != null && identityMatches(context, active) && permitted(context)) next(state, active)?.toInstant()?.toEpochMilli() else null),
            "updatedAt" to (if (active == null || active.isNull("updatedAt")) null else active.getLong("updatedAt")),
            "snapshotReady" to (active != null && !active.isNull("updatedAt")), "permission" to permitted(context))
    }
    private fun revoke(context: Context, state: JSONObject) {
        state.remove("active")
        state.remove("test")
        state.put("revision", UUID.randomUUID().toString())
        persist(context, state) // Durable tombstone precedes cancellation.
        cancel(context, false); cancel(context, true)
    }
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "refrigerator/local_expiry_v1").setMethodCallHandler { call, result ->
            try {
                val response = synchronized(lock) {
                    val state = state(context)
                    if (call.method == "invalidate") { revoke(context, state); null } else {
                        val ownerHash = owner(call.argument<String>("owner"))
                        when (call.method) {
                            "read" -> { rearm(context, state); read(context, state, ownerHash) }
                            "enable" -> {
                                require(call.argument<String>("expectedRevision") == state.getString("revision"))
                                val project = call.argument<String>("project") ?: ""
                                require(project.matches(Regex("[a-zA-Z0-9_-]{1,128}")))
                                val days = call.argument<Int>("days")
                                require(days in listOf(1, 3, 7))
                                val dates = LocalExpiryPlanner.dates(call.argument<List<String>>("dates") ?: throw IllegalArgumentException())
                                val active = JSONObject().put("owner", ownerHash).put("project", project).put("days", days)
                                    .put("generation", UUID.randomUUID().toString()).put("dates", JSONArray(dates.map { it.toString() }))
                                    .put("updatedAt", System.currentTimeMillis())
                                require(identityMatches(context, active))
                                state.put("active", active).put("revision", UUID.randomUUID().toString()); state.remove("test")
                                persist(context, state); cancel(context, true); rearm(context, state)
                                read(context, state, ownerHash)
                            }
                            "sync" -> {
                                require(call.argument<String>("expectedRevision") == state.getString("revision"))
                                val active = state.getJSONObject("active")
                                require(active.getString("owner") == ownerHash && active.getString("generation") == call.argument<String>("generation"))
                                require(identityMatches(context, active))
                                val dates = LocalExpiryPlanner.dates(call.argument<List<String>>("dates") ?: throw IllegalArgumentException())
                                active.put("dates", JSONArray(dates.map { it.toString() })).put("updatedAt", System.currentTimeMillis())
                                state.put("revision", UUID.randomUUID().toString()); state.remove("test")
                                persist(context, state); cancel(context, true); rearm(context, state)
                                read(context, state, ownerHash)
                            }
                            "suspend" -> {
                                val active = state.optJSONObject("active")
                                if (active == null) {
                                    revoke(context, state)
                                } else if (active.getString("owner") == ownerHash) {
                                    active.put("dates", JSONArray()).put("updatedAt", JSONObject.NULL); active.remove("scheduledDay")
                                    state.remove("test"); state.put("revision", UUID.randomUUID().toString())
                                    persist(context, state); cancel(context, false); cancel(context, true)
                                }
                                read(context, state, ownerHash)
                            }
                            "disable" -> {
                                val active = state.optJSONObject("active")
                                // An already-disabled OFF must also invalidate pending enables.
                                if (active == null || active.getString("owner") == ownerHash) revoke(context, state)
                                read(context, state, ownerHash)
                            }
                            "test" -> {
                                require(context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0)
                                val active = state.getJSONObject("active")
                                require(active.getString("owner") == ownerHash && active.getString("generation") == call.argument<String>("generation"))
                                require(identityMatches(context, active) && permitted(context))
                                val today = LocalDate.now()
                                require(LocalExpiryPlanner.eligible(parseDates(active.getJSONArray("dates")), active.getInt("days"), today))
                                val dueAt = System.currentTimeMillis() + 60000
                                state.put("test", JSONObject().put("generation", active.getString("generation")).put("day", today.toString()).put("dueAt", dueAt))
                                persist(context, state)
                                alarm(context, true, dueAt, active.getString("generation"), today.toString())
                                dueAt
                            }
                            else -> throw IllegalArgumentException()
                        }
                    }
                }
                result.success(response)
            } catch (_: Exception) { result.error("local_expiry_unavailable", "Local expiry reminder unavailable", null) }
        }
    }
    private fun show(context: Context, test: Boolean) {
        val manager = manager(context)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(channelId, "재료 소비기한 알림", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null); enableVibration(false); vibrationPattern = null
            })
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channelId) else Notification.Builder(context)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) builder.setContentIntent(PendingIntent.getActivity(context, if (test) testId else normalId, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        builder.setSmallIcon(context.applicationInfo.icon).setContentTitle(if (test) "재료 소비기한 알림 (테스트)" else "재료 소비기한을 확인해 주세요")
            .setContentText("마지막으로 동기화한 재료 기준입니다. 앱에서 현재 재료를 확인해 주세요.")
            .setVisibility(Notification.VISIBILITY_PRIVATE).setAutoCancel(true)
        manager.notify(if (test) "${channelId}_test" else channelId, if (test) testId else normalId, builder.build())
    }
    fun receive(context: Context, intent: Intent) = synchronized(lock) {
        try {
            val state = state(context)
            val action = intent.action
            if (action != normalAction && action != testAction) {
                if (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_USER_UNLOCKED, Intent.ACTION_MY_PACKAGE_REPLACED,
                        Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) rearm(context, state)
                return@synchronized
            }
            val active = state.optJSONObject("active") ?: return@synchronized
            if (active.getString("generation") != intent.getStringExtra("generation")) return@synchronized
            val now = ZonedDateTime.now()
            if (!identityMatches(context, active) || !permitted(context)) { rearm(context, state); return@synchronized }
            val dates = parseDates(active.getJSONArray("dates"))
            val day = LocalDate.parse(intent.getStringExtra("day"))
            if (action == testAction) {
                require(context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0)
                val test = state.optJSONObject("test") ?: return@synchronized
                val dueAt = test.getLong("dueAt")
                require(test.getString("generation") == active.getString("generation") && test.getString("day") == day.toString())
                require(dueAt == intent.getLongExtra("dueAt", 0) && System.currentTimeMillis() >= dueAt && System.currentTimeMillis() - dueAt <= 3600000)
                require(day == now.toLocalDate() && LocalExpiryPlanner.eligible(dates, active.getInt("days"), day))
                state.remove("test"); persist(context, state) // At-most-once test, independent daily claim.
                show(context, true)
            } else {
                if (LocalExpiryPlanner.canDeliver(dates, active.getInt("days"), now, day, claimed(state, active))) {
                    val claims = state.getJSONObject("claims")
                    val owner = active.getString("owner")
                    require(claims.has(owner) || claims.length() < 128)
                    claims.put(owner, day.toString()); persist(context, state)
                    try { show(context, false) } finally { rearm(context, state) }
                } else rearm(context, state)
            }
        } catch (_: Exception) { /* Fail closed. Never log inventory, identity, session, or file contents. */ }
    }
}

class LocalExpiryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { LocalExpiryReminders.receive(context, intent) }
}
