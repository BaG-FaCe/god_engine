# 16 — Verbesserungspotenziale

> Optionale, nicht umgesetzte Ideen — teils aus `versioning.md`/Kommentaren
> übernommen, teils aus der Analyse abgeleitet. **Keine davon wurde umgesetzt.**

## Architektur

- **Service-Extraktion** des `supply_chain_risk`-Kontexts (Architektur ist darauf
  ausgelegt: eigene Domain, eigene Registry, keine Kenntnis vom Kalkulator).
- **Event-Bus statt direkter `NotifyRiskAlert`-Aufrufe** — `Audit::Recorder` ist
  bereits so kommentiert, dass er gegen einen Event-Bus austauschbar wäre.
- **`PricingCalculator` aufteilen** — die Methode `#call` und die privaten Block-
  Builder in kleinere, testbare Einheiten zerlegen.

## Risiko-Provider

- **Verschlüsseltes `api_secret`-Feld** in `risk_provider_configs` ergänzen (aktuell
  nur ENV).
- **`PollDisasterAlertsJob` um `config`-Durchreichung erweitern**, damit per-Projekt-
  Endpoint-Overrides auch beim Event-Polling greifen.
- **Echte Vertrags-URLs/Schemata** der Paid-Adapter hinterlegen (sobald Verträge
  vorliegen) und den Contract-Harness auf alle Adapter ausweiten.
- **ActionCable/WebSocket-Push** für Benachrichtigungen als Alternative zum Polling
  (Query-Key-Architektur ist bereits wechselbereit).

## Funktionalität

- **UI-Liste „Archivierte Projekte“** mit Restore-Button (aktuell nur API).
- **Vollständige Implementierung** der Platzhalter-Module (Materialmanager,
  Produktionsplaner, Lagerverwaltung, Reporting, Lieferrisiko-Monitor).
- **Feinere Berechtigungen** — `User`-Rollen sind bewusst grob; feingranulare
  Permissions könnten ohne Änderung der Domain-Module ergänzt werden.

## Betrieb

- **Durable Queue auf Windows** — z. B. über einen separaten Worker-Prozess oder
  alternative Adapter (aktuell `async`).
- **Dokumentation vervollständigen** — die referenzierten, aber fehlenden Dateien
  `docs/07-risk-data-providers.md` und `docs/15-deployment.md` anlegen bzw. die
  README-Verweise korrigieren.
- **`original_app_structure.md` bereinigen** — Tippfehler im Dateinamen
  (`orignal_app_structure_ref.md`) normalisieren und die leere Datei füllen oder
  entfernen.

## Qualität

- **Testabdeckung erhöhen** — insbesondere für die 14 Free-Data-Adapter und die
  Frontend-Tabs (aktuell nur wenige Vitest-Unit-Tests).
- **Property-basierte Tests** für `Money#allocate` und die Rundungslogik
  (kaufmännische Rundung, Größte-Reste-Verfahren).
