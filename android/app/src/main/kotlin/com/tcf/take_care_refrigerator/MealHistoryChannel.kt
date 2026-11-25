package com.tcf.take_care_refrigerator

import android.content.Context
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import org.json.JSONObject

/** Main-thread, account/session scoped writer. Never used by background workers. */
object MealHistoryChannel {
    fun register(context: Context, messenger: BinaryMessenger) {
        var activeAccount: String? = null
        var activeSession: String? = null
        MethodChannel(messenger, "refrigerator/meal_history").setMethodCallHandler { call, result ->
            try {
                if (call.method == "activate") {
                    activeAccount = call.argument<String>("account")
                    activeSession = call.argument<String>("session")
                    result.success(null)
                } else {
                    val account = call.argument<String>("account")
                    require(!account.isNullOrBlank() && account.length <= 256)
                    require(account == activeAccount && call.argument<String>("session") == activeSession)
                    val hash = MessageDigest.getInstance("SHA-256").digest(account.toByteArray(Charsets.UTF_8))
                        .joinToString("") { "%02x".format(it.toInt() and 0xff) }
                    val directory = File(context.noBackupFilesDir.canonicalFile, "meal_history_v1")
                    require(directory.isDirectory || directory.mkdirs())
                    require(directory.canonicalFile == directory.absoluteFile)
                    val file = File(directory, "$hash.json")
                    require(file.canonicalFile == file.absoluteFile)
                    val atomic = AtomicFile(file)
                    fun read(): String? {
                        if (!file.exists() && !File(file.path + ".bak").exists()) return null
                        require(file.length() <= 512000 && File(file.path + ".bak").length() <= 512000)
                        require(File(file.path + ".bak").canonicalFile == File(file.path + ".bak").absoluteFile)
                        return atomic.openRead().use { input ->
                            val output = java.io.ByteArrayOutputStream()
                            val buffer = ByteArray(4096)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                require(output.size() + count <= 512000)
                                output.write(buffer, 0, count)
                            }
                            output.toString("UTF-8")
                        }
                    }
                    when (call.method) {
                        "read" -> result.success(read())
                        "write" -> {
                            val value = call.argument<String>("value") ?: error("Missing history")
                            val bytes = value.toByteArray(Charsets.UTF_8)
                            require(bytes.size <= 512000)
                            val next = JSONObject(value)
                            require(next.getInt("version") == 1 && next.getString("owner") == account)
                            require(next.getJSONArray("records").length() <= 1000)
                            val previous = read()?.let { JSONObject(it) }
                            if (previous != null) require(previous.getString("owner") == account && previous.getInt("version") == 1)
                            val revision = previous?.getLong("revision") ?: 0L
                            require(revision >= 0L && next.getLong("revision") == revision + 1L)
                            val pending = File(file.path + ".new")
                            require(pending.canonicalFile == pending.absoluteFile)
                            val stream = atomic.startWrite()
                            try {
                                stream.write(bytes)
                                atomic.finishWrite(stream)
                            } catch (error: Exception) {
                                atomic.failWrite(stream)
                                throw error
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            } catch (_: Exception) {
                // Never log meal names, accounts or persisted JSON.
                result.error("meal_history_failed", "Meal history unavailable or changed", null)
            }
        }
    }
}
