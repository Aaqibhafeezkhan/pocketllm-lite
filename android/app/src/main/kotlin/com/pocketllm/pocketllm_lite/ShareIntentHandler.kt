package com.pocketllm.pocketllm_lite

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import java.io.File
import java.util.UUID

/**
 * Turns an ACTION_SEND / ACTION_SEND_MULTIPLE intent into plain data for Dart.
 *
 * Safety rules, all enforced here because Dart cannot see the source app:
 * - only `content://` URIs are read; `file://` is refused because it would let
 *   another app point this one at its own private files;
 * - this app's own FileProvider is refused for the same reason;
 * - at most [MAX_FILES] files, each at most [MAX_FILE_BYTES], counted while
 *   copying (a declared size is not trusted);
 * - copies go to a private cache inbox with sanitised names, and old inbox
 *   folders are purged, so shared material is not silently retained.
 *
 * URI read permission granted by the sender lasts only while this activity is
 * alive, so the copy happens immediately when the intent arrives.
 */
class ShareIntentHandler(private val context: Context) {

    companion object {
        const val INBOX_NAME = "shared_inbox"
        const val MAX_FILES = 5
        const val MAX_FILE_BYTES = 25L * 1024 * 1024
        const val MAX_TEXT_CHARS = 200 * 1024
        private const val MAX_AGE_MS = 24L * 60 * 60 * 1000
    }

    fun inboxDirectory(): File = File(context.cacheDir, INBOX_NAME)

    /** Removes inbox folders older than a day (crash or abandoned shares). */
    fun purgeOld() {
        val inbox = inboxDirectory()
        val now = System.currentTimeMillis()
        inbox.listFiles()?.forEach { entry ->
            if (now - entry.lastModified() > MAX_AGE_MS) entry.deleteRecursively()
        }
    }

    /** Deletes a previously returned path if, and only if, it is inside the inbox. */
    fun discard(paths: List<String>) {
        val root = inboxDirectory().canonicalFile
        for (path in paths) {
            try {
                val file = File(path).canonicalFile
                if (file.path.startsWith(root.path + File.separator)) {
                    file.delete()
                    file.parentFile?.takeIf { it.parentFile == root && it.list().isNullOrEmpty() }
                        ?.delete()
                }
            } catch (_: Exception) {
                // Nothing to clean up.
            }
        }
    }

    /** Returns null when the intent is not a share. */
    fun parse(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null

        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val subject = intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()

        val uris = LinkedHashSet<Uri>()
        if (action == Intent.ACTION_SEND) {
            streamUri(intent)?.let { uris.add(it) }
        } else {
            streamUriList(intent).forEach { uris.add(it) }
        }
        val clip: ClipData? = intent.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let { uris.add(it) }
            }
        }

        val files = uris.take(MAX_FILES + 1).map { copyToInbox(it, intent.type) }
        return mapOf(
            "text" to text,
            "subject" to subject,
            "files" to files,
        )
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }

    @Suppress("DEPRECATION")
    private fun streamUriList(intent: Intent): List<Uri> =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
        }

    private fun failure(name: String, message: String): Map<String, Any?> = mapOf(
        "path" to "",
        "name" to name,
        "mimeType" to null,
        "sizeBytes" to 0,
        "error" to message,
    )

    private fun copyToInbox(uri: Uri, intentType: String?): Map<String, Any?> {
        val fallbackName = "shared-file"
        if (uri.scheme != "content") {
            return failure(fallbackName, "Only content:// shares are accepted.")
        }
        if (uri.authority == "${context.packageName}.fileProvider") {
            return failure(fallbackName, "A share from PocketLLM's own storage was ignored.")
        }
        val resolver = context.contentResolver
        var displayName = fallbackName
        var declaredSize = -1L
        try {
            resolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) cursor.getString(nameIndex)?.let { displayName = it }
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) declaredSize = cursor.getLong(sizeIndex)
                }
            }
        } catch (_: Exception) {
            // Some providers refuse metadata queries; the stream may still work.
        }
        val safeName = sanitize(displayName)
        if (declaredSize > MAX_FILE_BYTES) {
            return failure(safeName, "The file is larger than 25 MB.")
        }
        val mime = (resolver.getType(uri) ?: intentType)?.lowercase()

        val folder = File(inboxDirectory(), UUID.randomUUID().toString())
        val target = File(folder, safeName)
        return try {
            if (!folder.mkdirs()) return failure(safeName, "Could not create the share inbox.")
            var copied = 0L
            val stream = resolver.openInputStream(uri)
                ?: return failure(safeName, "The sending app did not provide the file.")
            stream.use { input ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        copied += read
                        if (copied > MAX_FILE_BYTES) {
                            throw IllegalStateException("size")
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
            mapOf(
                "path" to target.absolutePath,
                "name" to safeName,
                "mimeType" to mime,
                "sizeBytes" to copied,
                "error" to null,
            )
        } catch (error: IllegalStateException) {
            folder.deleteRecursively()
            failure(safeName, "The file is larger than 25 MB.")
        } catch (error: SecurityException) {
            folder.deleteRecursively()
            failure(safeName, "The sending app denied access to the file.")
        } catch (error: java.io.FileNotFoundException) {
            folder.deleteRecursively()
            failure(safeName, "The sending app no longer has this file.")
        } catch (error: Exception) {
            folder.deleteRecursively()
            failure(safeName, "The file could not be read.")
        }
    }

    private fun sanitize(name: String): String {
        val base = name.substringAfterLast('/').substringAfterLast('\\')
        val cleaned = base.replace(Regex("[^A-Za-z0-9._ -]"), "_").trim().trimStart('.')
        return (cleaned.ifEmpty { "shared-file" }).take(80)
    }
}
