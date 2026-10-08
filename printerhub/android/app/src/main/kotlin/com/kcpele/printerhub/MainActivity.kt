package com.kcpele.printerhub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

/**
 * Passes files that another app shared to PrinterHub, or opened with it, to
 * the Flutter side, over the `printerhub/incoming_files` channel.
 *
 * A file can arrive before Flutter is listening, when it is what started the
 * app. Those wait here until Flutter asks with `listen`.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val waiting = mutableListOf<String>()
    private var listening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "printerhub/incoming_files",
        ).also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "listen") {
                    listening = true
                    result.success(waiting.toList())
                    waiting.clear()
                } else {
                    result.notImplemented()
                }
            }
        }
        clearOldCopies()
        take(intent)
    }

    /**
     * A copy from more than a day ago has been printed or forgotten, and
     * goes.
     */
    private fun clearOldCopies() {
        val dayAgo = System.currentTimeMillis() - 24 * 60 * 60 * 1000
        thread {
            File(cacheDir, "incoming").listFiles()
                ?.filter { it.lastModified() < dayAgo }
                ?.forEach { it.delete() }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        take(intent)
    }

    private fun take(intent: Intent?) {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            Intent.ACTION_VIEW -> intent.data
            else -> null
        } ?: return
        // Handled once: turning the phone must not hand it over again.
        intent?.action = null

        // The file belongs to the other app and may be large: it is copied
        // in off the main thread, and only its own copy is passed on.
        thread {
            val path = copyIn(uri) ?: return@thread
            runOnUiThread {
                if (listening) {
                    channel?.invokeMethod("opened", path)
                } else {
                    waiting.add(path)
                }
            }
        }
    }

    /** Copies what [uri] names into the app's cache, under its own name. */
    private fun copyIn(uri: Uri): String? {
        return try {
            val folder = File(cacheDir, "incoming").apply { mkdirs() }
            val target = File(folder, nameOf(uri))
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            target.path
        } catch (_: Exception) {
            null
        }
    }

    private fun nameOf(uri: Uri): String {
        var name: String? = null
        if (uri.scheme == "content") {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) name = cursor.getString(0)
                }
        }
        val known = name ?: uri.lastPathSegment ?: "Document"
        // A name without an ending gets one from what the file is, so the
        // app knows how to print it.
        if (known.contains('.')) return known.replace('/', '-')
        val ending = when (contentResolver.getType(uri)) {
            "application/pdf" -> ".pdf"
            "image/jpeg" -> ".jpg"
            "image/png" -> ".png"
            else -> ""
        }
        return known.replace('/', '-') + ending
    }
}
