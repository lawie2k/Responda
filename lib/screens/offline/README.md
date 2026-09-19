# Offline screens

Offline-only home, reports, and shell screens live here. The report form itself
is shared from `lib/screens/shared/reporting`; offline mode removes the map and
photo step, captures phone coordinates, and stores completed reports locally.
Every offline report entry first opens the SMS backup gateway so the user knows
the report will use cellular SMS and keep a local copy.
