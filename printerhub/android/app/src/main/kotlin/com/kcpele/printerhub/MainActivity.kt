package com.kcpele.printerhub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
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
 *
 * It also reads the words in scanned pages, over `printerhub/scan_text`, and
 * opens the phone's document camera, over `printerhub/page_camera`.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CAMERA_REQUEST = 4162
    }

    private var channel: MethodChannel? = null
    private val waiting = mutableListOf<String>()
    private var listening = false

    /** The answer the Flutter side is waiting for while the camera is open. */
    private var cameraAnswer: MethodChannel.Result? = null

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "printerhub/page_camera",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // It is fetched by Play services the first time it is used.
                "available" -> result.success(true)
                "capture" -> openCamera(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "printerhub/scan_text",
        ).setMethodCallHandler { call, result ->
            val paths = call.arguments as? List<*>
            if (call.method == "read" && paths != null) {
                readText(paths.filterIsInstance<String>(), result)
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Opens the document camera that comes with Google Play services. It
     * takes as many pages as the person likes; they come back in
     * [onActivityResult].
     */
    private fun openCamera(result: MethodChannel.Result) {
        if (cameraAnswer != null) {
            result.error("page_camera.unavailable", null, null)
            return
        }
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        cameraAnswer = result
        GmsDocumentScanning.getClient(options).getStartScanIntent(this)
            .addOnSuccessListener { sender ->
                try {
                    startIntentSenderForResult(sender, CAMERA_REQUEST, null, 0, 0, 0)
                } catch (error: Exception) {
                    answerCamera { it.error("page_camera.failed", error.message, null) }
                }
            }
            .addOnFailureListener { error ->
                answerCamera { it.error("page_camera.failed", error.message, null) }
            }
    }

    private fun answerCamera(with: (MethodChannel.Result) -> Unit) {
        val answer = cameraAnswer ?: return
        cameraAnswer = null
        with(answer)
    }

    @Deprecated("FlutterActivity has no newer way to be told of a result.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CAMERA_REQUEST) return
        val pages = if (resultCode == RESULT_OK) {
            GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages
        } else {
            null
        }
        if (pages == null) {
            // Left without taking a page.
            answerCamera { it.success(emptyList<String>()) }
            return
        }
        // The pictures belong to Play services: the app takes its own copies.
        thread {
            val folder = File(cacheDir, "camera").apply { mkdirs() }
            val stamp = System.currentTimeMillis()
            val paths = try {
                pages.mapIndexed { index, page ->
                    val target = File(folder, "camera-$stamp-${index + 1}.jpg")
                    contentResolver.openInputStream(page.imageUri)!!.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    }
                    target.path
                }
            } catch (_: Exception) {
                null
            }
            runOnUiThread {
                answerCamera {
                    if (paths == null) {
                        it.error("page_camera.storage", null, null)
                    } else {
                        it.success(paths)
                    }
                }
            }
        }
    }

    /**
     * Reads the words in scanned pages with ML Kit's bundled model, a page
     * after another. The pages never leave the phone.
     */
    private fun readText(paths: List<String>, result: MethodChannel.Result) {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val pages = mutableListOf<String>()

        fun next(index: Int) {
            if (index == paths.size) {
                recognizer.close()
                result.success(pages.filter { it.isNotEmpty() }.joinToString("\n\n"))
                return
            }
            try {
                val image = InputImage.fromFilePath(this, Uri.fromFile(File(paths[index])))
                recognizer.process(image)
                    .addOnSuccessListener { read ->
                        pages.add(read.text)
                        next(index + 1)
                    }
                    .addOnFailureListener { error ->
                        recognizer.close()
                        result.error("scan_text.unreadable", error.message, null)
                    }
            } catch (error: Exception) {
                recognizer.close()
                result.error("scan_text.unreadable", error.message, null)
            }
        }
        next(0)
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
