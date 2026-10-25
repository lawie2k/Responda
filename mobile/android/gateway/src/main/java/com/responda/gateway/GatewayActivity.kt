package com.responda.gateway

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.view.WindowManager
import android.widget.*
import androidx.work.WorkManager

class GatewayActivity : Activity() {
    private lateinit var backend: EditText
    private lateinit var token: EditText
    private lateinit var status: TextView
    private var pendingUrl: String? = null
    private var pendingToken: String? = null
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        val content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(28, 44, 28, 28) }
        fun text(value: String, size: Float = 16f) = TextView(this).apply {
            text = value; textSize = size; setPadding(0, 12, 0, 12); content.addView(this)
        }
        text("Responda Gateway", 26f)
        text("Dedicated MDRRMO phone. Only signed Responda envelopes are queued. Ordinary texts are ignored. Keep this phone powered, connected and SMS permission enabled.")
        text("Backend origin")
        backend = EditText(this).apply { hint = "https://your-backend"; inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI; content.addView(this) }
        text("Gateway token issued by Super Admin")
        token = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            isSaveEnabled = false
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
            hint = "Paste a new token, or leave blank to keep the current one"
            content.addView(this)
        }
        val save = Button(this).apply { text = "Enable / update gateway"; content.addView(this) }
        val pause = Button(this).apply { text = "Pause receiving and forwarding"; content.addView(this) }
        val refresh = Button(this).apply { text = "Refresh status / retry queue"; content.addView(this) }
        status = text("")
        setContentView(ScrollView(this).apply { addView(content) })
        try { GatewayStore(this).use { backend.setText(it.config()?.backend ?: "") } }
        catch (_: Exception) { status.text = "Secure configuration unavailable. Do not clear app storage while reports are queued." }
        save.setOnClickListener {
            try {
                val url = GatewayPolicy.backend(backend.text.toString(), BuildConfig.DEBUG)
                val existing = GatewayStore(this).use { it.config() }
                val secret = token.text.toString().trim().ifEmpty {
                    require(existing?.backend == url) { "Changing backend requires a new gateway token." }
                    existing!!.token
                }
                require(Regex("gateway_[A-Za-z0-9_-]{43}").matches(secret)) { "Enter a valid gateway token." }
                pendingUrl = url; pendingToken = secret
                if (checkSelfPermission(Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), 10)
                } else configure()
            } catch (error: IllegalArgumentException) { status.text = error.message }
            catch (_: Exception) { status.text = "Could not save secure configuration." }
        }
        pause.setOnClickListener {
            GatewayStore(this).use { it.pause() }
            WorkManager.getInstance(this).cancelAllWorkByTag("sms-forward")
            showStatus()
        }
        refresh.setOnClickListener {
            try { Forwarding.start(this); showStatus() }
            catch (_: Exception) { status.text = "Queue storage is unavailable. Existing messages have not been discarded." }
        }
    }
    private fun configure() {
        try {
            GatewayStore(this).use { it.save(pendingUrl!!, pendingToken!!) }
            token.text.clear()
            Forwarding.start(this)
            showStatus()
        } catch (error: IllegalArgumentException) { status.text = error.message }
        catch (_: Exception) { status.text = "Could not save secure configuration. Existing messages have not been discarded." }
        finally { pendingUrl = null; pendingToken = null }
    }
    override fun onRequestPermissionsResult(request: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(request, permissions, results)
        if (request != 10) return
        if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) configure()
        else { pendingUrl = null; pendingToken = null; token.text.clear(); status.text = "SMS permission denied. Gateway not enabled." }
    }
    override fun onResume() {
        super.onResume()
        if (::status.isInitialized) {
            try { Forwarding.start(this) } catch (_: Exception) { /* Status reports storage failures. */ }
            showStatus()
        }
    }
    private fun showStatus() {
        try {
            GatewayStore(this).use { store ->
                val configured = store.config() != null
                val allowed = checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                val mode = when { !configured -> "Gateway setup required"; !store.enabled() -> "Paused"; !allowed -> "SMS permission is disabled"
                    store.authPaused() -> "Authentication paused — update the gateway token"; else -> "Enabled — waiting for signed SMS" }
                val receptionError = getSharedPreferences("gateway", MODE_PRIVATE).getBoolean("receive_error", false)
                status.text = "$mode\n${store.summary()}" + if (receptionError) "\nA message could not be queued. Check device storage before continuing." else ""
            }
        } catch (_: Exception) { status.text = "Queue storage is unavailable. Do not clear app storage while reports are queued." }
    }
}
