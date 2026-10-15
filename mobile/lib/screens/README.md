# Screen organization

- `online/` contains screens that assume the device can use the connected
  RESPONDA experience.
- `offline/` is reserved for screens shown when internet delivery is
  unavailable, including local drafts and SMS fallback.
- `outside_pantukan/` is reserved for service-area guidance and report review
  when a detected location is outside Pantukan.
- `shared/reporting/` contains the reporting screens reused by online and
  offline mode. `ReportFlowMode` changes only the steps each mode needs.

Reusable widgets, theme tokens, localization, navigation, and device services
belong in `lib/core`. Reporting domain models stay in
`lib/features/reporting/domain` so every connectivity or service-area flow can
reuse the same report data.
