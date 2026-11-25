package com.tcf.take_care_refrigerator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import android.net.Uri
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MealHistoryChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
        // Account-scoped, app-private storage excluded from backup/transfer.
        var preferenceAccount: String? = null
        var preferenceSession: String? = null
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "refrigerator/curation_preferences")
            .setMethodCallHandler { call, result ->
                try {
                    if (call.method == "activate") {
                        preferenceAccount = call.argument<String>("account")
                        preferenceSession = call.argument<String>("session")
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val account = call.argument<String>("account")
                    val session = call.argument<String>("session")
                    require(!account.isNullOrBlank() && account.length <= 256)
                    require(account == preferenceAccount && session != null && session == preferenceSession)
                    val hash = java.security.MessageDigest.getInstance("SHA-256")
                        .digest(account.toByteArray(Charsets.UTF_8))
                        .joinToString("") { "%02x".format(it.toInt() and 0xff) }
                    val directory = File(noBackupFilesDir, "curation_accounts_v2")
                    require(directory.isDirectory || directory.mkdirs())
                    val file = File(directory, "$hash.json")
                    val atomic = android.util.AtomicFile(file)
                    fun remove(target: File) {
                        android.util.AtomicFile(target).delete()
                        require(!target.exists() && !File(target.path + ".bak").exists() && !File(target.path + ".new").exists())
                    }
                    when (call.method) {
                        "read" -> {
                            // Check every AtomicFile candidate BEFORE opening/allocating.
                            for (candidate in listOf(file, File(file.path + ".bak"), File(file.path + ".new"))) {
                                require(!candidate.exists() || candidate.length() <= 4096)
                            }
                            val value = try {
                                atomic.openRead().use { input ->
                                    require(input.channel.size() <= 4096)
                                    // Bounded read also closes a growth race after the size check.
                                    val bytes = ByteArray(4097)
                                    var count = 0
                                    while (count < bytes.size) {
                                        val read = input.read(bytes, count, bytes.size - count)
                                        if (read < 0) break
                                        count += read
                                    }
                                    require(count <= 4096)
                                    String(bytes, 0, count, Charsets.UTF_8)
                                }
                            } catch (_: java.io.FileNotFoundException) { null }
                            result.success(value)
                        }
                        "write" -> {
                            val value = call.argument<String>("value")
                            require(value != null && value.toByteArray(Charsets.UTF_8).size <= 4096)
                            val data = org.json.JSONObject(value)
                            require(data.getInt("version") == 1 && data.length() == 4)
                            require(data.get("preferred") is String && data.getString("preferred").codePointCount(0, data.getString("preferred").length) <= 120)
                            require(data.get("avoided") is String && data.getString("avoided").codePointCount(0, data.getString("avoided").length) <= 120)
                            require(data.get("prioritizeExpiring") is Boolean)
                            val stream = atomic.startWrite()
                            try {
                                stream.write(value.toByteArray(Charsets.UTF_8))
                                atomic.finishWrite(stream)
                            } catch (error: Exception) {
                                atomic.failWrite(stream)
                                throw error
                            }
                            result.success(null)
                        }
                        "delete" -> { remove(file); result.success(null) }
                        // The unowned v1 file is NEVER read or migrated to an account.
                        // Removal requires the separate explicit legacy-delete UI action.
                        "deleteLegacy" -> {
                            remove(File(noBackupFilesDir, "curation_preferences_v1.json"))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("local_preferences_failed", "Local preference operation failed", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "refrigerator/receipt_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize" && call.method != "recognizeLayout") {
                    result.notImplemented()
                } else {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_image", "No image selected", null)
                        return@setMethodCallHandler
                    }
                    val recognizer = TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
                    // API 24/25: preserve prior recognition, no deletion at all.
                    var owned: OwnedReceiptImage? = null
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= 26) {
                            owned = try { OwnedReceiptImage.create(cacheDir, path) }
                                catch (_: Exception) { null } // Preserve OCR; never delete original.
                        }
                        val image = InputImage.fromFilePath(this, Uri.fromFile(owned?.file ?: File(path)))
                        recognizer.process(image)
                            .addOnSuccessListener { text ->
                                // Local OCR only. Do not log receipt text or store the image.
                                val lines = text.textBlocks.flatMap { it.lines }
                                if (call.method == "recognizeLayout") {
                                    result.success(lines.map { line ->
                                        val box = line.boundingBox
                                        mapOf("text" to line.text, "left" to box?.left,
                                            "top" to box?.top, "right" to box?.right,
                                            "bottom" to box?.bottom)
                                    })
                                } else { result.success(lines.map { it.text }) }
                            }
                            .addOnFailureListener { result.error("ocr_failed", "Could not read image", null) }
                            .addOnCompleteListener {
                                recognizer.close()
                                if (android.os.Build.VERSION.SDK_INT >= 26) owned?.cleanup()
                            }
                    } catch (_: Exception) {
                        recognizer.close()
                        if (android.os.Build.VERSION.SDK_INT >= 26) owned?.cleanup()
                        result.error("invalid_image", "Could not open image", null)
                    }
                }
            }
    }
}
