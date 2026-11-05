package com.the356company.sendsnap

import android.app.DownloadManager
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.the356company.sendsnap/file_utils"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var sharedFilePaths: ArrayList<String> = ArrayList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleSendIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSendIntent(intent)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onFilesShared", sharedFilePaths)
        }
    }

    private fun handleSendIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (Intent.ACTION_SEND == action) {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            } ?: intent.data

            uri?.let {
                val path = resolveUriToFilePath(it)
                if (path != null) {
                    sharedFilePaths = arrayListOf(path)
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uris = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }

            val paths = ArrayList<String>()
            uris?.forEach { uri ->
                resolveUriToFilePath(uri)?.let { paths.add(it) }
            }
            sharedFilePaths = paths
        } else if (Intent.ACTION_VIEW == action) {
            val uri = intent.data
            uri?.let {
                val path = resolveUriToFilePath(it)
                if (path != null) {
                    sharedFilePaths = arrayListOf(path)
                }
            }
        }
    }

    private fun resolveUriToFilePath(uri: Uri): String? {
        if (uri.scheme == "file") {
            return uri.path
        }
        // If content URI, try resolving the direct file path from MediaStore first (zero-copy)
        if (uri.scheme == "content") {
            try {
                val proj = arrayOf(MediaStore.MediaColumns.DATA)
                contentResolver.query(uri, proj, null, null, null)?.use { cursor ->
                    val dataCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    if (dataCol != -1 && cursor.moveToFirst()) {
                        val realPath = cursor.getString(dataCol)
                        if (!realPath.isNullOrBlank()) {
                            val f = File(realPath)
                            if (f.exists() && f.canRead()) {
                                return f.absolutePath
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }
        try {
            var displayName = "shared_${System.currentTimeMillis()}"
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1 && cursor.moveToFirst()) {
                    val name = cursor.getString(nameIndex)
                    if (!name.isNullOrBlank()) {
                        displayName = name
                    }
                }
            }

            val cacheDir = File(cacheDir, "shared_incoming")
            if (!cacheDir.exists()) cacheDir.mkdirs()
            val destFile = File(cacheDir, displayName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            return destFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun queryMediaStoreFiles(type: String): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val isRecent = type.lowercase() == "recents" || type.lowercase() == "recent"
        val uri = when (type.lowercase()) {
            "videos", "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            "photos", "images", "photo", "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            "recents", "recent" -> MediaStore.Files.getContentUri("external")
            else -> null
        } ?: return list

        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DATA,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_MODIFIED
        )

        val selection = if (isRecent) "${MediaStore.MediaColumns.SIZE} > 0" else null
        val sortOrder = "${MediaStore.MediaColumns.DATE_MODIFIED} DESC LIMIT 150"
        try {
            contentResolver.query(uri, projection, selection, null, sortOrder)?.use { cursor ->
                val idCol = cursor.getColumnIndex(MediaStore.MediaColumns._ID)
                val dataCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                val nameCol = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
                val modCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_MODIFIED)

                while (cursor.moveToNext()) {
                    val id = if (idCol != -1) cursor.getLong(idCol) else 0L
                    val path = if (dataCol != -1) cursor.getString(dataCol) else null
                    val name = if (nameCol != -1) cursor.getString(nameCol) else null
                    val size = if (sizeCol != -1) cursor.getLong(sizeCol) else 0L
                    val mod = if (modCol != -1) cursor.getLong(modCol) * 1000L else System.currentTimeMillis()

                    val finalName = if (!name.isNullOrBlank()) name else (if (path != null) File(path).name else "file_$id")
                    val finalPath = if (!path.isNullOrBlank() && File(path).exists()) {
                        path
                    } else {
                        ContentUris.withAppendedId(uri, id).toString()
                    }

                    list.add(
                        mapOf(
                            "path" to finalPath,
                            "name" to finalName,
                            "size" to size,
                            "modified" to mod
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }

    private fun openFileManagerAtFolder(folderPath: String, filePath: String?): Boolean {
        val folder = File(folderPath)
        if (!folder.exists()) {
            try {
                folder.mkdirs()
            } catch (_: Exception) {}
        }

        // 1. Try DocumentsContract direct Document URI pointing to SendSnap folder in Downloads
        try {
            val externalStoragePath = Environment.getExternalStorageDirectory().absolutePath
            val relativePath = if (folderPath.startsWith(externalStoragePath)) {
                folderPath.removePrefix(externalStoragePath).trimStart('/')
            } else {
                "Download/SendSnap"
            }
            val docId = "primary:$relativePath"
            val uri = DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", docId)

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        } catch (_: Exception) {}

        // 2. Try FileProvider URI with directory / folder mime types
        try {
            val contentUri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                folder
            )
            val mimeTypes = arrayOf(
                "resource/folder",
                DocumentsContract.Document.MIME_TYPE_DIR,
                "vnd.android.document/directory",
                "*/*"
            )
            for (mime in mimeTypes) {
                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(contentUri, mime)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        return true
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}

        // 3. Try standard DownloadManager ACTION_VIEW_DOWNLOADS
        try {
            val dmIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (dmIntent.resolveActivity(packageManager) != null) {
                startActivity(dmIntent)
                return true
            }
        } catch (_: Exception) {}

        // 4. Try OEM File Managers (Google Files, Samsung My Files, Xiaomi, OnePlus, Oppo, etc.)
        val knownPackages = arrayOf(
            "com.google.android.apps.nfiles",      // Files by Google
            "com.sec.android.app.myfiles",         // Samsung My Files
            "com.mi.android.globalFileexplorer",   // Xiaomi File Manager
            "com.oneplus.filemanager",             // OnePlus File Manager
            "com.coloros.filemanager",             // Oppo / Realme
            "com.huawei.hidisk",                   // Huawei Files
            "com.android.documentsui"              // AOSP Files
        )
        for (pkg in knownPackages) {
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launchIntent)
                    return true
                }
            } catch (_: Exception) {}
        }

        // 5. Generic ACTION_VIEW fallback to external storage documents root
        try {
            val genericIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(
                    Uri.parse("content://com.android.externalstorage.documents/root/primary"),
                    "vnd.android.document/root"
                )
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (genericIntent.resolveActivity(packageManager) != null) {
                startActivity(genericIntent)
                return true
            }
        } catch (_: Exception) {}

        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedFiles" -> {
                    val list = ArrayList(sharedFilePaths)
                    sharedFilePaths.clear()
                    result.success(list)
                }
                "queryMediaFiles" -> {
                    val mediaType = call.argument<String>("type") ?: "videos"
                    Thread {
                        val items = queryMediaStoreFiles(mediaType)
                        runOnUiThread {
                            result.success(items)
                        }
                    }.start()
                }
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
                        ?: (Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath + "/SendSnap")
                    val filePath = call.argument<String>("filePath")
                    try {
                        val opened = openFileManagerAtFolder(path, filePath)
                        result.success(opened)
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
                "acquireMulticastLock" -> {
                    try {
                        if (multicastLock == null) {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifiManager.createMulticastLock("SendSnapMulticastLock").apply {
                                setReferenceCounted(true)
                            }
                        }
                        if (multicastLock?.isHeld != true) {
                            multicastLock?.acquire()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", "Failed to acquire multicast lock: ${e.message}", null)
                    }
                }
                "releaseMulticastLock" -> {
                    try {
                        if (multicastLock?.isHeld == true) {
                            multicastLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", "Failed to release multicast lock: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
