package com.the356company.sendsnap

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.the356company.sendsnap/file_utils"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "copyFromContentUri" -> {
                    val contentUri = call.argument<String>("uri")
                    val destPath = call.argument<String>("destPath")
                    if (contentUri == null || destPath == null) {
                        result.error("INVALID_ARGS", "uri and destPath are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(contentUri)
                        val inputStream = contentResolver.openInputStream(uri)
                        if (inputStream == null) {
                            result.error("STREAM_ERROR", "Could not open input stream for URI: $contentUri", null)
                            return@setMethodCallHandler
                        }
                        val destFile = File(destPath)
                        destFile.parentFile?.mkdirs()
                        val outputStream = FileOutputStream(destFile)
                        inputStream.use { input ->
                            outputStream.use { output ->
                                input.copyTo(output)
                            }
                        }
                        result.success(destFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("COPY_ERROR", "Failed to copy from content URI: ${e.message}", null)
                    }
                }
                "openFileManager" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGS", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        // Try to open the system file manager at the specific directory
                        val intent = Intent(Intent.ACTION_VIEW)
                        val uri = Uri.parse(path)
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            // Use DocumentsUI for Android O+
                            val docsIntent = Intent(Intent.ACTION_VIEW)
                            docsIntent.setDataAndType(uri, "resource/folder")
                            docsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            
                            // Try the Documents UI intent first
                            try {
                                startActivity(docsIntent)
                                result.success(true)
                                return@setMethodCallHandler
                            } catch (e: Exception) {
                                // Fall through to generic approach
                            }
                        }

                        // Fallback: open the Downloads folder using the Downloads provider
                        val downloadsIntent = Intent(Intent.ACTION_VIEW)
                        downloadsIntent.setDataAndType(
                            Uri.parse("content://com.android.externalstorage.documents/document/primary:Download/SendSnap"),
                            DocumentsContract.Document.MIME_TYPE_DIR
                        )
                        downloadsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(downloadsIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            // Last fallback: just open the file manager
                        }

                        // Last fallback: open any file manager
                        val fallbackIntent = Intent(Intent.ACTION_VIEW)
                        fallbackIntent.setDataAndType(Uri.parse("content://com.android.externalstorage.documents/root/primary"), "vnd.android.document/root")
                        fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(fallbackIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_ERROR", "Could not open file manager: ${e.message}", null)
                    }
                }
                "openFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGS", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        val extension = MimeTypeMap.getFileExtensionFromUrl(file.name)
                        val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
                        
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider", 
                            file
                        )
                        
                        val intent = Intent(Intent.ACTION_VIEW)
                        intent.setDataAndType(uri, mimeType)
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_ERROR", "Could not open file: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
