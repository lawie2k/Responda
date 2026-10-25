package com.responda.gateway

import java.net.URI

object GatewayPolicy {
    private val envelope = Regex("RSP1\\.[0-9a-f]{32}\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]{43}")
    fun accepts(body: String): Boolean = body.length <= 2048 && envelope.matches(body)
    fun phone(raw: String): String? {
        val clean = raw.replace(Regex("[\\s()\\-]"), "")
        val normalized = when {
            clean.startsWith("09") -> "+63" + clean.drop(1)
            clean.startsWith("639") -> "+$clean"
            else -> clean
        }
        return normalized.takeIf { Regex("\\+639[0-9]{9}").matches(it) }
    }
    fun backend(raw: String, debug: Boolean): String {
        val uri = URI(raw.trim().trimEnd('/'))
        require(uri.scheme == "https" || (debug && uri.scheme == "http")) { "Use an HTTPS backend URL." }
        require(!uri.host.isNullOrBlank() && uri.userInfo == null && uri.query == null &&
            uri.fragment == null && uri.rawPath.isNullOrEmpty()) { "Enter only the backend origin, including its port if needed." }
        require(uri.port == -1 || uri.port in 1..65535) { "Enter a valid backend port." }
        return uri.toASCIIString()
    }
    enum class Delivery { ACCEPTED, DUPLICATE, REJECTED, RETRY, AUTH, BLOCKED }
    fun delivery(code: Int, status: String?, reportId: String?): Delivery {
        if (code == 401 || code == 403) return Delivery.AUTH
        if (code == 429 || code >= 500) return Delivery.RETRY
        if (code in 300..499) return Delivery.BLOCKED
        if (code != 200) return Delivery.RETRY
        if (status == "rejected") return Delivery.REJECTED
        if (!Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(reportId ?: "")) return Delivery.RETRY
        return when (status) {
            "accepted" -> Delivery.ACCEPTED
            "duplicate" -> Delivery.DUPLICATE
            else -> Delivery.RETRY
        }
    }
}
