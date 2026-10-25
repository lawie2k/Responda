package com.responda.gateway

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.time.Instant
import java.util.concurrent.Executors

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return
        val sender = GatewayPolicy.phone(messages[0].originatingAddress ?: "") ?: return
        if (messages.any { GatewayPolicy.phone(it.originatingAddress ?: "") != sender }) return
        val body = messages.joinToString("") { it.messageBody ?: "" }
        if (!GatewayPolicy.accepts(body)) return
        val received = Instant.now().toString()
        val pending = goAsync()
        executor.execute {
            val store = GatewayStore(context.applicationContext)
            try {
                if (store.enabled() && store.config() != null) {
                    val id = store.enqueue(sender, body, received)
                    Forwarding.enqueue(context.applicationContext, id)
                }
            } catch (_: Exception) {
                context.getSharedPreferences("gateway", Context.MODE_PRIVATE).edit()
                    .putBoolean("receive_error", true).commit()
            } finally { store.close(); pending.finish() }
        }
    }
    companion object { private val executor = Executors.newSingleThreadExecutor() }
}
