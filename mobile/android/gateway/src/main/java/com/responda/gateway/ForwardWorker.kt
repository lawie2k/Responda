package com.responda.gateway

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.work.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

class ForwardWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val store = GatewayStore(applicationContext)
        var connection: HttpURLConnection? = null
        try {
            if (!store.enabled() || store.authPaused() || applicationContext.checkSelfPermission(
                    Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) return Result.success()
            val id = inputData.getString("id") ?: return Result.failure()
            val item = store.item(id) ?: return Result.success()
            if (System.currentTimeMillis() < item.nextAt) return Result.retry()
            val config = store.config() ?: return Result.success()
            val origin = GatewayPolicy.backend(config.backend, BuildConfig.DEBUG)
            connection = URL("$origin/api/v1/gateway/sms").openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer ${config.token}")
            val data = item.payload.toByteArray(Charsets.UTF_8)
            connection.setFixedLengthStreamingMode(data.size)
            connection.outputStream.use { it.write(data) }
            val code = connection.responseCode
            var status: String? = null
            var report: String? = null
            if (code == 200) {
                val response = connection.inputStream.use { stream ->
                    val bytes = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(1024)
                    while (true) {
                        val read = stream.read(buffer)
                        if (read < 0) break
                        if (bytes.size() + read > 16_384) throw java.io.IOException("Response too large")
                        bytes.write(buffer, 0, read)
                    }
                    bytes.toString("UTF-8")
                }
                val json = JSONObject(response)
                status = json.optString("status")
                report = json.optString("report_id")
            }
            return when (val decision = GatewayPolicy.delivery(code, status, report)) {
                GatewayPolicy.Delivery.ACCEPTED, GatewayPolicy.Delivery.DUPLICATE,
                GatewayPolicy.Delivery.REJECTED -> {
                    store.finish(id, decision.name); Result.success()
                }
                GatewayPolicy.Delivery.AUTH -> { store.pauseAuth(); Result.success() }
                GatewayPolicy.Delivery.BLOCKED -> { store.block(id); Result.success() }
                GatewayPolicy.Delivery.RETRY -> {
                    val retry = connection.getHeaderField("Retry-After")
                    val seconds = retry?.toLongOrNull()?.coerceIn(0, 604800)
                    val next = if (seconds != null) System.currentTimeMillis() + seconds * 1000
                        else try { ZonedDateTime.parse(retry, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli() }
                        catch (_: Exception) { 0L }
                    store.defer(id, next); Result.retry()
                }
            }
        } catch (_: Exception) {
            // Never log request bodies, sender numbers, tokens or encrypted key failures.
            return Result.retry()
        } finally { connection?.disconnect(); store.close() }
    }
}

object Forwarding {
    private val network = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
    fun enqueue(context: Context, id: String) {
        val request = OneTimeWorkRequestBuilder<ForwardWorker>().setConstraints(network)
            .setInputData(workDataOf("id" to id)).setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .addTag("sms-forward").build()
        WorkManager.getInstance(context).enqueueUniqueWork("sms-$id", ExistingWorkPolicy.KEEP, request)
    }
    fun recover(context: Context) {
        val store = GatewayStore(context)
        try {
            if (!store.enabled() || store.authPaused()) return
            for (id in store.pending()) enqueue(context, id)
        } finally { store.close() }
    }
    fun start(context: Context) {
        GatewayStore(context).use { if (!it.enabled()) return }
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("sms-recovery", ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<RecoveryWorker>(15, TimeUnit.MINUTES).setConstraints(network).build())
        recover(context)
    }
}

class RecoveryReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: android.content.Intent) {
        if (intent.action != android.content.Intent.ACTION_BOOT_COMPLETED) return
        try { Forwarding.start(context.applicationContext) } catch (_: Exception) {
            // Opening the operator app retries recovery without discarding the encrypted queue.
        }
    }
}

class RecoveryWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = try {
        Forwarding.recover(applicationContext); Result.success()
    } catch (_: Exception) { Result.retry() }
}
