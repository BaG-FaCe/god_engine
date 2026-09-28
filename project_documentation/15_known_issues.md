# 15 — Bekannte Probleme & Einschränkungen

> Diese Punkte wurden aus Code-Kommentaren, `versioning.md` und Analyse abgeleitet.
> Sie sind **bewusst nicht behoben** worden (Dokumentationsauftrag).

## Infrastruktur / Betrieb

1. **Windows: keine durable Job-Queue** — Solid Queue benötigt `fork`; unter Windows
   degradiert `JobAdapter` auf `async` (In-Prozess-Threadpool). Jobs gehen bei
   Neustart verloren, der Scheduler (`recurring.yml`) läuft nicht.
2. **Job-Status nur bedingt abfragbar** — `JobStatus` liefert bei `async`
   `status: "unknown"`; die SPA fällt auf Refetch zurück.
3. **Hartkodierte Dev-Secrets** — die Fallback-Werte für `ActiveRecord::Encryption`
   (z. B. `god-engine-development-primary-key`) liegen im `application.rb`; in
   Produktion zwingend per ENV zu überschreiben.

## Lieferrisiko-Provider

4. **Paid-Adapter sind Stubs** — die 19 SCRM-Adapter sind deklarativ angelegt; nur
   `project44` besitzt ein Recording im Contract-Harness. Echte Vertrags-URLs/
   Schemata fehlen (bewusst „vertragsgated“).
5. **`api_secret` nur via ENV** — `risk_provider_configs` speichert nur `api_key`
   (verschlüsselt) + `config` (JSON); das OAuth2-Client-Secret bleibt Umgebungsvariable.
6. **Event-Polling ignoriert Projekt-Config** — `PollDisasterAlertsJob` liest
   `PollSchedule`, reicht aber die freie `config`-JSON (Endpoint-/Pfad-Overrides)
   noch nicht an die Provider durch (Events sind global).
7. **Optionale Free-Quellen ohne Key inaktiv** — `eu_taric`, `freightos_fbx`,
   `fred_economic`, `openweather_alerts` benötigen Endpoint/Appname/Key; ohne diese
   melden sie sich als „nicht konfiguriert“.

## Funktionalität / UI

8. **Keine UI zum Wiederherstellen** — archivierte Projekte sind nur via API
   `POST /projects/:id/restore` wiederherstellbar; es gibt keine eigene Liste
   „Archivierte Projekte“.
9. **Kein Echtzeit-Push** — Benachrichtigungen werden per Intervall-Polling (30 s)
   geholt; ActionCable/WebSocket ist bewusst nicht umgesetzt.
10. **Weitere Module sind Platzhalter** — Materialmanager, Produktionsplaner,
    Lagerverwaltung, Reporting, Lieferrisiko-Monitor sind „Coming Soon“.

## Dokumentation

11. **Verwaiste Doc-Referenzen** — die README verweist auf `docs/07-risk-data-providers.md`
    und `docs/15-deployment.md`, die im Repository nicht existieren.
12. **`original_app_structure.md` ist leer** — die eigentliche Referenz liegt in
    `orignal_app_structure_ref.md` (Tippfehler im Dateinamen); `versioning.md`
    referenziert `original_app_structure.md`.

## Technische Schulden (Code-Kommentare)

13. **`json`-Gem gepinnt auf 2.x** — wegen Rails-8.1-/json-3.0-Inkompatibilität
    (`JSON.parse(str, options)`).
14. **`PricingCalculator#call` ist lang** (mehrere Hundert Zeilen) und enthält viel
    inline-Mathematik; keine Extraktion in kleinere Einheiten.
