package com.responda.gateway

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class GatewayStore(context: Context) : SQLiteOpenHelper(context, "sms_queue.db", null, 1) {
    private val prefs = context.getSharedPreferences("gateway", Context.MODE_PRIVATE)
    data class Config(val backend: String, val token: String)
    data class Item(val id: String, val payload: String, val nextAt: Long)
    private fun key(): SecretKey = synchronized(lock) {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("responda-gateway-v1", null) as? SecretKey) ?: KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("responda-gateway-v1",
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
        }.generateKey()
    }
    private fun seal(value: String, aad: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(aad.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
    }
    private fun open(value: String, aad: String): String {
        val bytes = Base64.decode(value, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        cipher.updateAAD(aad.toByteArray(Charsets.UTF_8))
        return cipher.doFinal(bytes.copyOfRange(12, bytes.size)).toString(Charsets.UTF_8)
    }
    fun config(): Config? = prefs.getString("config", null)?.let {
        val json = JSONObject(open(it, "config"))
        Config(json.getString("backend"), json.getString("token"))
    }
    fun enabled(): Boolean = prefs.getBoolean("enabled", false)
    fun authPaused(): Boolean = prefs.getBoolean("auth_paused", false)
    fun save(backend: String, token: String) {
        val old = config()
        require(old == null || old.backend == backend || count() == 0) {
            "Pending messages belong to the existing backend. Deliver them before changing its URL."
        }
        require(Regex("gateway_[A-Za-z0-9_-]{43}").matches(token)) { "Enter the gateway token issued by the Super Admin." }
        check(prefs.edit().putString("config", seal(JSONObject().put("backend", backend)
            .put("token", token).toString(), "config")).putBoolean("enabled", true)
            .putBoolean("auth_paused", false).commit()) { "Could not save gateway configuration." }
        writableDatabase.execSQL("UPDATE queue SET state='pending', next_at=0")
    }
    fun pause() { check(prefs.edit().putBoolean("enabled", false).commit()) }
    fun pauseAuth() { check(prefs.edit().putBoolean("auth_paused", true).commit()) }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE queue (id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL UNIQUE, sealed TEXT NOT NULL, state TEXT NOT NULL, next_at INTEGER NOT NULL DEFAULT 0)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    fun enqueue(sender: String, body: String, received: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest((sender + ":" + body).toByteArray(Charsets.UTF_8))
        val fingerprint = Base64.encodeToString(digest, Base64.NO_WRAP)
        val id = UUID.randomUUID().toString()
        val json = JSONObject().put("provider_message_id", id).put("sender_number", sender)
            .put("received_at", received).put("body", body).toString()
        val values = ContentValues().apply {
            put("id", id); put("fingerprint", fingerprint); put("sealed", seal(json, id)); put("state", "pending")
        }
        writableDatabase.insertWithOnConflict("queue", null, values, SQLiteDatabase.CONFLICT_IGNORE)
        readableDatabase.query("queue", arrayOf("id"), "fingerprint=?", arrayOf(fingerprint), null, null, null).use {
            check(it.moveToFirst()) { "Message could not be queued." }
            return it.getString(0)
        }
    }
    fun pending(): List<String> = readableDatabase.rawQuery("SELECT id FROM queue WHERE state='pending'", null).use {
        buildList { while (it.moveToNext()) add(it.getString(0)) }
    }
    fun item(id: String): Item? = readableDatabase.query("queue", arrayOf("sealed", "next_at"),
        "id=? AND state='pending'", arrayOf(id), null, null, null).use {
        if (it.moveToFirst()) Item(id, open(it.getString(0), id), it.getLong(1)) else null
    }
    fun defer(id: String, nextAt: Long) { writableDatabase.update("queue", ContentValues().apply {
        put("next_at", nextAt)
    }, "id=?", arrayOf(id)) }
    fun block(id: String) { writableDatabase.update("queue", ContentValues().apply {
        put("state", "blocked")
    }, "id=?", arrayOf(id)) }
    fun finish(id: String, kind: String) = synchronized(lock) {
        writableDatabase.delete("queue", "id=?", arrayOf(id))
        prefs.edit().putInt(kind, prefs.getInt(kind, 0) + 1).commit()
    }
    fun count(): Int = readableDatabase.rawQuery("SELECT COUNT(*) FROM queue", null).use {
        it.moveToFirst(); it.getInt(0)
    }
    fun summary(): String {
        val blocked = readableDatabase.rawQuery("SELECT COUNT(*) FROM queue WHERE state='blocked'", null).use {
            it.moveToFirst(); it.getInt(0)
        }
        return "Queued: ${count()} · Needs review: $blocked\nAccepted: ${prefs.getInt("ACCEPTED", 0)} · Duplicates: ${prefs.getInt("DUPLICATE", 0)} · Rejected: ${prefs.getInt("REJECTED", 0)}"
    }
    companion object { private val lock = Any() }
}
