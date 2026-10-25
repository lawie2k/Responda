# Android SIM gateway — backend contract (RSP1)

Implemented: installation registration, gateway credentials and authenticated
ingestion, plus the Flutter signer and a separate Android gateway utility under
mobile/android/gateway. Physical SIM delivery still needs a device walkthrough.

## Online setup and trust

The citizen installation connects online using an active, phone-verified reporter
account with privacy consent. `POST /api/v1/mobile/sms-devices` takes a fresh random
`device_id` UUID and the existing citizen bearer token. It returns `device_id`,
`signing_key`, `expires_at`, `gateway_number`, and `protocol: RSP1`. Persist the key in platform secure
storage, never SMS, URLs, logs or preferences. A retry for the same owned, valid ID
returns the same key. There may be five active installations per account, expiring
after 180 days. `GET` lists active IDs/expiry only. `DELETE /{device_id}` revokes an
owned installation. Revoked/expired IDs stay reserved; register a new random UUID.

Account suspension revokes all installation keys atomically with sessions; account
restoration does not revive them. Beta accounts without verified phones cannot
register SMS keys. Development OTP can serve local tests only; real production
phone verification still requires an SMS delivery provider.

The server derives each 32-byte installation key using
`HMAC-SHA256(SECRET_KEY, UTF8("responda:sms-device:RSP1:") || UUID bytes)`.
UUID bytes are the 16 network-order bytes. No global secret is embedded in the app
or stored in the devices table. Changing `SECRET_KEY` invalidates signatures;
reprovision installations after rotation. Return keys only to their authenticated
owner over HTTPS.

This proves possession of a registered installation credential. It does not attest
an unmodified official app or prove an emergency is genuine. Exported keys/rooted
devices remain a risk; stronger app provenance requires platform attestation.
Staff verification remains necessary. Base64 is encoding; SMS is not encrypted.

## Wire format

`RSP1.<device-uuid-hex>.<payload>.<tag>`

- Header UUID: 32 lowercase hex characters without hyphens.
- Payload: unpadded base64url of UTF-8 JSON, without compression.
- Tag: full HMAC-SHA256 over the exact ASCII
  `RSP1.<device-uuid-hex>.<payload>` bytes, unpadded base64url (43 characters).
- Decode the issued `signing_key` from base64url before computing HMAC.
- No whitespace or translated text outside the envelope. Verify the tag with
  constant-time comparison before parsing. Unknown versions/fields, duplicate
  JSON keys, malformed encodings and invalid values are rejected.
- Retries must preserve the original complete message. JSON ordering may differ
  across encoders because authentication covers the exact encoded bytes.
- Envelope maximum: 2048 ASCII characters, potentially multiple carrier SMS parts
  and charges. The app must check length and ask to shorten details; never truncate.

| JSON key | Meaning |
| --- | --- |
| `c` | Client report UUID, 32 lowercase hex; shared with an online retry |
| `t` | Report creation/location-capture UTC Unix timestamp, integer seconds |
| `k` | Optional actual GPS capture UTC Unix timestamp; defaults to `t` for older clients |
| `i` | `road_accident`, `flood`, `fire`, `drowning`, or `other` |
| `d` | Description, 10–300 characters, normalized by existing report rules |
| `l` | Optional landmark, at most 100 characters |
| `x`, `y` | Optional latitude/longitude pair, finite numbers in valid ranges |
| `m` | Optional GPS accuracy in meters, 0–100000 |
| `p` | Boolean: people need help |
| `a` | Boolean: additional assistance required |
| `g` | Boolean: immediate danger |

Require paired coordinates or a nonempty landmark. Optional absent fields may be
omitted or null. Boolean fields must be actual JSON booleans. Queue age is limited
to seven days; allow five minutes of clock skew. Reject future timestamps, signed
times before registration, or signed times later than gateway receipt beyond that
skew. Recheck key validity at ingestion. `app/core/sms_protocol.py` is the reference
encoder/decoder. It never translates or silently drops content.

## Gateway provisioning and forwarding

Super Admin uses the staff session and trusted origin to call
`POST /api/v1/admin/sms-gateways` with `name`, E.164 `phone_number`, and a stable
nonsecret `device_identifier`. The response discloses `gateway_id` and a random
`gateway_...` token once; PostgreSQL retains its hash only. Store it securely on the
dedicated gateway phone. `DELETE /{gateway_id}` disables it.
`POST /{gateway_id}/rotate-token` invalidates its prior token, issues a replacement
and reactivates the gateway. All operations recheck actor/session and audit IDs
and action names, never token/contact values.

Android forwarder responsibilities:

1. Receive SMS with explicit device permissions. Ignore non-`RSP1.` messages
   locally so ordinary private messages are never uploaded.
2. Assemble all parts into the complete original body. Do not trim, translate,
   decode/reencode, or forward individual fragments.
3. Persist one queue item: stable random `provider_message_id`, actual sender in
   Philippine E.164 `+639XXXXXXXXX` form, UTC `received_at`, and exact `body`.
   Dual-SIM citizen phones must send from the SIM verified for the account.
4. HTTPS `POST /api/v1/gateway/sms` with gateway bearer auth and those four fields.
5. HTTP 200 gives `accepted`, `duplicate`, or `rejected`, with a report UUID for
   accepted/duplicate messages. These are terminal acknowledgements: remove the
   queued sensitive body after acknowledgement. Opening a composer is not delivery.
6. For network errors, 429 or 5xx: keep the unchanged item across restarts; retry
   with exponential backoff and honor `Retry-After`. On 401, pause until credentials
   are repaired. Invalid request fields (422) require correction, not blind retry.

Backend filtering cannot stop SMS arriving in Android's inbox. Only its local
forwarding filter and server verification control what becomes a dashboard report.

## Acceptance, privacy and replay protection

Only an active, undeleted gateway may deliver. The installation must be current,
unrevoked and owned by an active, undeleted, phone-verified consenting reporter.
Actual sender must match that reporter's verified phone. Neither prefix nor sender
alone authenticates a report; staff/mobile tokens do not authenticate the gateway.

An accepted new message atomically creates an `app_sms`, `pending`/`new` report,
location, creation event, minimal audit and receipt. Existing Live Reports reads
include it automatically. No incoming priority/verification claim is trusted; the
gateway cannot dispatch a team or create a confirmed incident.

Gateway/provider delivery IDs and globally unique client report UUIDs prevent
duplicates across retries, gateways and online/SMS transport. Changed signed bytes
under an already accepted SMS ID are rejected. An existing online report owned by
the same citizen is returned as duplicate without changing contents or source.
Deleted rows stay reserved and cannot be resurrected. Concurrent unique-key
conflicts roll back all staged rows and ask the forwarder to retry.

Receipts retain a body fingerprint, signature, installation ID and delivery
metadata. Rejected bodies are not retained. Accepted `raw_message_body` stays
empty, since report fields already hold the content. Validation/errors never echo
keys, phone numbers, SMS bodies or SQL; request/response body logging must stay off.

Per ten minutes: 10 registrations per account/IP, 300 ingress calls per gateway
token/IP, 10 forwarded items per sender. Existing process-local limiting requires
a shared store before multiple API workers.

References: [Python HMAC](https://docs.python.org/3/library/hmac.html),
[Android SMS intents](https://developer.android.com/reference/android/provider/Telephony.Sms.Intents).
