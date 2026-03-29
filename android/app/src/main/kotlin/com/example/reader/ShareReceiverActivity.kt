package com.example.reader

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.View
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView

/**
 * Lightweight native Activity that handles all external share/open intents:
 *   • text/plain ACTION_SEND  — URL shared from browser → queues as pending_share_url
 *   • RSS/XML file ACTION_SEND or ACTION_VIEW — queues file content as pending_rss_content
 *
 * Uses a translucent window theme (no Flutter engine) so the calling app is
 * visible behind the bottom-sheet card. Flutter processes queued items on
 * the next foreground resume.
 */
class ShareReceiverActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private var isRssImport = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.share_receiver_layout)

        // Tap backdrop to dismiss immediately
        findViewById<View>(R.id.backdrop).setOnClickListener { finish() }

        // Slide card up from bottom
        val card = findViewById<View>(R.id.card)
        card.post {
            card.translationY = card.height.toFloat()
            card.animate().translationY(0f).setDuration(280).start()
        }

        // Route: RSS file first, then URL text
        val rssUri = extractRssFileUri()
        if (rssUri != null) {
            isRssImport = true
            val fileName = getDisplayNameForUri(rssUri)
            if (fileName.isNotEmpty()) {
                findViewById<TextView>(R.id.source_text).text = fileName
            }
            val ok = queueRssFile(rssUri, fileName)
            handler.postDelayed({ if (!isFinishing && !isDestroyed) onSaveComplete(ok) }, 600)
            return
        }

        val url = extractUrl()
        if (url == null) {
            finish()
            return
        }

        // Show domain label
        try {
            val host = Uri.parse(url).host?.removePrefix("www.") ?: url
            findViewById<TextView>(R.id.source_text).text = host
        } catch (_: Exception) {
            findViewById<TextView>(R.id.source_text).text = url
        }

        val ok = queueUrl(url)
        handler.postDelayed({ if (!isFinishing && !isDestroyed) onSaveComplete(ok) }, 600)
    }

    // ── RSS file handling ─────────────────────────────────────────────────────

    private fun extractRssFileUri(): Uri? {
        val action = intent?.action ?: return null
        return when (action) {
            Intent.ACTION_VIEW -> intent.data?.takeIf { looksLikeRss(it) }
            Intent.ACTION_SEND -> {
                val uri = intent.data ?: intent.clipData?.getItemAt(0)?.uri
                uri?.takeIf { looksLikeRss(it) }
            }
            else -> null
        }
    }

    private fun looksLikeRss(uri: Uri): Boolean {
        val type = try { contentResolver.getType(uri) ?: "" } catch (_: Exception) { "" }
        if (type.contains("xml") || type.contains("rss") || type.contains("atom")) return true
        val path = uri.path?.lowercase() ?: return false
        return path.endsWith(".rss") || path.endsWith(".xml") || path.endsWith(".atom")
    }

    private fun getDisplayNameForUri(uri: Uri): String {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val col = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (col >= 0) return cursor.getString(col) ?: ""
                    }
                }
            } catch (_: Exception) {}
        }
        return uri.lastPathSegment ?: ""
    }

    private fun queueRssFile(uri: Uri, fileName: String): Boolean {
        return try {
            val content = contentResolver.openInputStream(uri)
                ?.use { it.readBytes().toString(Charsets.UTF_8) }
                ?: return false
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.pending_rss_content", content)
                .putString("flutter.pending_rss_filename", fileName)
                .commit()
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // ── URL handling ──────────────────────────────────────────────────────────

    private fun extractUrl(): String? {
        if (intent?.action != Intent.ACTION_SEND &&
            intent?.action != Intent.ACTION_SEND_MULTIPLE) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        return Regex("""https?://\S+""").find(text)?.value?.trimEnd('.')
            ?: if (text.trim().startsWith("http")) text.trim() else null
    }

    private fun queueUrl(url: String): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val existing = prefs.getString("flutter.pending_share_url", null)
            val updated = if (existing.isNullOrEmpty()) url else "$existing\n$url"
            prefs.edit().putString("flutter.pending_share_url", updated).commit()
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // ── Result UI ─────────────────────────────────────────────────────────────

    private fun onSaveComplete(ok: Boolean) {
        findViewById<ProgressBar>(R.id.progress).visibility = View.GONE
        val icon = findViewById<ImageView>(R.id.status_icon)
        icon.visibility = View.VISIBLE
        icon.setImageResource(
            if (ok) R.drawable.ic_check_circle else R.drawable.ic_error_circle
        )
        findViewById<TextView>(R.id.status_text).text = when {
            ok && isRssImport  -> "Feed Queued"
            ok                 -> "Saved to Reading List"
            isRssImport        -> "Failed to add feed"
            else               -> "Failed to save"
        }

        val bar = findViewById<View>(R.id.countdown_bar)
        bar.pivotX = 0f
        val start = System.currentTimeMillis()
        val duration = 3000L
        val tick = object : Runnable {
            override fun run() {
                if (isFinishing || isDestroyed) return
                val f = 1f - ((System.currentTimeMillis() - start).toFloat() / duration)
                    .coerceIn(0f, 1f)
                bar.scaleX = f
                if (f > 0f) handler.postDelayed(this, 16L) else finish()
            }
        }
        handler.post(tick)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}

