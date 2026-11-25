package com.tcf.reminder_bridge
import android.content.Context
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import org.json.JSONObject

/** App-private no-backup, bounded atomic CAS. No names, tokens or raw owner IDs. */
object OneShotReceiptChannel {
    private val lock=Any()
    private const val limit=4096
    private fun file(context:Context): AtomicFile {
        val root=context.noBackupFilesDir.canonicalFile
        val target=File(root,"one_shot_receipt_v1.json")
        for(f in listOf(target,File(target.path+".bak"),File(target.path+".new"))) require(f.canonicalFile==f.absoluteFile)
        return AtomicFile(target)
    }
    private fun read(file:AtomicFile): JSONObject {
        if(!file.baseFile.exists() && !File(file.baseFile.path+".bak").exists()) return JSONObject().put("revision","absent")
        for(f in listOf(file.baseFile,File(file.baseFile.path+".bak"))) require(!f.exists() || f.length()<=limit)
        val bytes=file.openRead().use { input -> val buffer=ByteArray(limit+1);var count=0;while(count<buffer.size){val n=input.read(buffer,count,buffer.size-count);if(n<0)break;count+=n};buffer.copyOf(count) }
        require(bytes.size<=limit)
        val root=JSONObject(String(bytes,Charsets.UTF_8))
        require(root.getString("revision").length in 1..64)
        return root
    }
    private fun write(file:AtomicFile, root:JSONObject) {
        val bytes=root.toString().toByteArray(Charsets.UTF_8);require(bytes.size<=limit)
        val stream=file.startWrite()
        try {stream.write(bytes);file.finishWrite(stream)} catch(e:Exception){file.failWrite(stream);throw e}
    }
    fun revoke(context:Context) = synchronized(lock) {
        // Overwrite corrupted data with a fresh tombstone, never recover old consent.
        write(file(context),JSONObject().put("revision",UUID.randomUUID().toString()))
    }
    fun register(context:Context,messenger:BinaryMessenger) {
        MethodChannel(messenger,"refrigerator/one_shot_receipt_v1").setMethodCallHandler { call,result ->
            try {
                val answer=synchronized(lock) {
                    when(call.method) {
                        "clear" -> {revoke(context);null}
                        "read" -> {
                            val root=read(file(context))
                            mapOf("revision" to root.getString("revision"),"receipt" to root.optString("receipt","").ifEmpty{null})
                        }
                        "write" -> {
                            val f=file(context);val root=read(f)
                            require(root.getString("revision")==call.argument<String>("expected"))
                            val raw=call.argument<String>("receipt")?:throw IllegalArgumentException()
                            require(raw.toByteArray(Charsets.UTF_8).size<=2048)
                            val record=JSONObject(raw)
                            require(record.keys().asSequence().toSet()==setOf("version","salt","owner","stock","days","due","offset","committed"))
                            require(record.getInt("version")==1)
                            for(key in listOf("salt","owner","stock")) require(record.getString(key).matches(Regex("[a-f0-9]{64}")))
                            require(record.getInt("days") in listOf(1,3,7))
                            require(record.getInt("offset") in -840..840)
                            require(record.getLong("due")>0);record.getBoolean("committed")
                            val rev=UUID.randomUUID().toString()
                            write(f,JSONObject().put("revision",rev).put("receipt",raw));rev
                        }
                        else -> throw IllegalArgumentException()
                    }
                };result.success(answer)
            } catch(_:Exception) {result.error("receipt_unavailable","Reservation proof unavailable",null)}
        }
    }
}
