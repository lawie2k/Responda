package com.responda.gateway

import org.junit.Assert.*
import org.junit.Test

class GatewayPolicyTest {
    @Test fun ignoresOrdinaryTextsAndPartialEnvelopes() {
        val valid = "RSP1." + "a".repeat(32) + ".YWJj." + "b".repeat(43)
        assertTrue(GatewayPolicy.accepts(valid))
        for (body in listOf("ordinary private text", valid.dropLast(1), valid + "\n", "x".repeat(2049))) {
            assertFalse(GatewayPolicy.accepts(body))
        }
        assertEquals("+639000000001", GatewayPolicy.phone("0900 000 0001"))
        assertNull(GatewayPolicy.phone("ADVERTISER"))
    }
    @Test fun requiresHttpsInReleaseAndRejectsEmbeddedCredentials() {
        assertEquals("https://example.invalid", GatewayPolicy.backend("https://example.invalid/", false))
        for (url in listOf("http://example.invalid", "https://token@example.invalid", "https://example.invalid/path")) {
            assertThrows(IllegalArgumentException::class.java) { GatewayPolicy.backend(url, false) }
        }
        assertEquals("http://10.0.2.2:8000", GatewayPolicy.backend("http://10.0.2.2:8000", true))
    }
    @Test fun onlyAcknowledgedTerminalResultsRemoveQueuedBodies() {
        val id = "00000000-0000-4000-8000-000000000001"
        assertEquals(GatewayPolicy.Delivery.ACCEPTED, GatewayPolicy.delivery(200, "accepted", id))
        assertEquals(GatewayPolicy.Delivery.DUPLICATE, GatewayPolicy.delivery(200, "duplicate", id))
        assertEquals(GatewayPolicy.Delivery.REJECTED, GatewayPolicy.delivery(200, "rejected", null))
        for (code in listOf(429, 500, 503)) assertEquals(GatewayPolicy.Delivery.RETRY, GatewayPolicy.delivery(code, null, null))
        assertEquals(GatewayPolicy.Delivery.RETRY, GatewayPolicy.delivery(200, "accepted", null))
        assertEquals(GatewayPolicy.Delivery.RETRY, GatewayPolicy.delivery(200, "unexpected", id))
        assertEquals(GatewayPolicy.Delivery.AUTH, GatewayPolicy.delivery(401, null, null))
        assertEquals(GatewayPolicy.Delivery.BLOCKED, GatewayPolicy.delivery(422, null, null))
        assertEquals(GatewayPolicy.Delivery.BLOCKED, GatewayPolicy.delivery(302, null, null))
    }
}
