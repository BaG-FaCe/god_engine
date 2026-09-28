# 18 — Microsoft SQL Server

> Die Plattform läuft **out of the box auf SQLite**. Dieses Dokument beschreibt den
> **optionalen** SQL-Server-Betrieb, der über den Ersteinrichtungs-Bildschirm
> aktiviert werden kann. Es enthält **keine** Zugangsdaten; Platzhalter sind als
> `<…>` gekennzeichnet.

## 1. Überblick

| Eigenschaft | Wert |
|---|---|
| Standard-Backend | SQLite (unverändert) |
| Optionales Backend | Microsoft SQL Server (2012+) |
| Adapter | `activerecord-sqlserver-adapter` (Rails 8.1) + `tiny_tds` (FreeTDS) |
| Aktivierung | `DB_ADAPTER=sqlserver` oder Abschluss der Ersteinrichtung |
| Anwendungs-Datenbank | `app_data` |
| Weitere Datenbanken | `log`, `users` |

SQL Server betrifft ausschließlich die **primäre Anwendungsdatenbank**. Solid Cache
und Solid Queue bleiben auf ihren SQLite-Dateien, sodass der Betrieb weiterhin ohne
Redis/PostgreSQL/Docker auskommt.

## 2. Die drei Datenbanken (Verantwortlichkeiten)

Die Initialisierung garantiert die Existenz von genau drei Datenbanken und legt
fehlende automatisch an — **nicht-destruktiv** (es wird nie gedroppt oder neu
erzeugt, wenn sie bereits existieren):

| Datenbank | Verantwortung |
|---|---|
| `app_data` | Primäres Anwendungsschema: Projekte, Materialien, Kalkulation, Risiko-Daten (alle AR-Modelle) |
| `log` | Protokollierung / Audit-Trail |
| `users` | Identitäts-Speicher (Benutzer) |

Die Namen sind über `DatabaseSetup::Configuration` konfigurierbar
(`database`, `log_database`, `users_database`); die Vorgaben lauten
`app_data` / `log` / `users`.

## 3. Ersteinrichtung (First-Run-Setup)

```text
Erster App-Start (DB_ADAPTER=sqlserver, keine Konfiguration)
        |
        v
Setup-Bildschirm (/setup)
        |
        v
Eingabe: Server, Port, Benutzername, Passwort
        |
        v
POST /api/v1/system/setup/test      -> Verbindungstest (read-only)
        |
        +---- Fehler ----> sichere Fehlermeldung (Passwort wird redigiert)
        |
      Erfolg
        |
        v
POST /api/v1/system/setup/complete
        |-- Provisionierung (app_data / log / users anlegen, falls fehlend)
        |-- Schema anlegen (Migrationen aus db/migrate)
        |-- Legacy-Daten migrieren (SQLite -> SQL Server)
        |-- Initialen Eintrag anlegen (Seed: Admin-User + Demo-Projekt)
        |-- Konfiguration sicher speichern
        v
Anwendung läuft auf SQL Server (inkl. initialem Eintrag)
```

**API-Endpunkte** (`app/controllers/api/v1/system_setup_controller.rb`):

| Endpunkt | Zweck |
|---|---|
| `GET  /api/v1/system/setup/status` | Backend/Adapter, ob konfiguriert, ob Einrichtung nötig |
| `POST /api/v1/system/setup/test` | Verbindungs-/Authentifizierungstest + welche DBs fehlen |
| `POST /api/v1/system/setup/complete` | Provisionierung + Schema + Migration + Speichern |

Die Setup-Endpunkte sind **gesperrt**, sobald eine Konfiguration gespeichert ist
(HTTP 409 `already_configured`), damit eine laufende Instanz nicht erneut
eingerichtet oder ausgeforscht werden kann.

**CLI-Äquivalente** (`lib/tasks/sqlserver.rake`):

```bash
bin/rails sqlserver:status     # Konfigurationsstatus (redigiert)
bin/rails sqlserver:test       # Verbindung testen (read-only)
bin/rails sqlserver:provision  # Datenbanken anlegen (nur fehlende)
bin/rails sqlserver:migrate    # Schema + Legacy-Daten
bin/rails sqlserver:setup      # kompletter Bootstrap
```

## 4. Initialisierungs-Logik

`DatabaseSetup::Provisioner` verbindet sich mit `master` und legt fehlende
Datenbanken per `CREATE DATABASE` an. Die Identifizierer werden streng validiert
(`[a-zA-Z0-9_]+`), da DDL-Namen nicht parametrisierbar sind.

`DatabaseSetup::SchemaLoader` führt die **Anwendungs-Migrationen**
(`db/migrate`) gegen `app_data` aus — die Migrationen sind die einzige
Schema-Quelle, es wird kein eigenes SQL-Schema „erfunden“.

## 5. Legacy-Migration (SQLite → SQL Server)

`DatabaseSetup::LegacyMigration` liest und schreibt **über die echten
ActiveRecord-Modelle** (keine erfundenen Tabellenkopien):

1. **Snapshot**: jede Tabelle wird in Fremdschlüssel-Reihenfolge
   (Eltern vor Kindern) über `Model#find_each` gelesen.
2. **Schreiben**: `Model#insert_all` — UUID-Primärschlüssel, Beziehungen und
   Werte bleiben erhalten; verschlüsselte Spalten (`RiskProviderConfig#api_key`)
   werden beim Lesen entschlüsselt und beim Schreiben neu verschlüsselt.
3. **Idempotenz**: Datensätze, deren Primärschlüssel bereits existiert, werden
   übersprungen → ein erneuter Lauf dupliziert nichts.

Reihenfolge (Fremdschlüssel-Abhängigkeiten): `users` → `projects` → `suppliers`
→ `materials` → … → `audit_logs`.

### 5.1 Initialer Eintrag (Seed)

Nach der Migration führt `DatabaseSetup::Seeder` die Anwendungs-Seeds
(`db/seeds.rb`, idempotent via `find_or_create_by!`) gegen die neue Verbindung
aus. Dadurch ist der **initiale Eintrag garantiert** — der Admin-Benutzer
(`admin@god-engine.local`) und das Demo-Projekt — auch bei einer frischen
Installation ohne vorhandene SQLite-Daten. Ohne diesen Schritt wäre eine neue
SQL-Server-Instanz leer und nicht nutzbar (kein Admin-Login).



## 6. Credential-Verwaltung (ohne Dokumentation echter Zugangsdaten)

- **Umgebungsvariablen** (Vorrang, empfohlen für Produktion):
  `SQL_SERVER`, `SQL_PORT`, `SQL_USER`, `SQL_PASSWORD`, `SQL_DATABASE`,
  `SQL_LOG_DATABASE`, `SQL_USERS_DATABASE`, `SQL_ENCRYPT`, `SQL_TIMEOUT`.
- **Lokale, gitignorierte Datei** `api/config/sqlserver.local.yml`
  (geschrieben vom Setup-Bildschirm, POSIX-Rechte 0600). Sie ist über
  `.gitignore` von der Versionskontrolle ausgeschlossen.
- Platzhalter-Konfiguration:
  `SQL_SERVER=<development-server>`, `SQL_USER=<development-user>`,
  `SQL_PASSWORD=<stored-secret>`.

Das Passwort wird **nie** geloggt, nie in Antworten zurückgegeben und aus
Fehlermeldungen redigiert (`Configuration#redacted`, `Connection#sanitize`).
`filter_parameter_logging.rb` filtert den Parameter `password` zusätzlich.

## 7. Aktivierung beim Neustart

`config/initializers/sqlserver.rb` prüft nach der Initialisierung, ob SQL Server
konfiguriert ist, und stellt die primäre Verbindung per
`ActiveRecord::Base.establish_connection` um. Schlug die Verbindung fehl, fällt
der Boot **auf SQLite zurück** (kein Absturz); der Fehler wird redigiert geloggt
und die Ersteinrichtung bleibt erreichbar.

## 8. Fehler- und Wiederherstellungsverhalten

| Situation | Verhalten |
|---|---|
| Verbindung/Auth schlägt fehl | 502 `sql_server_connection_error`, Meldung ohne Passwort |
| Bereits konfiguriert, erneuter Setup | 409 `already_configured` |
| Ungültiger Datenbankname | 422 `invalid_configuration` |
| Boot kann SQL Server nicht erreichen | Fallback auf SQLite, redigierter Log-Eintrag |
| Neustart nach Einrichtung | erkennt vorhandene DBs, legt sie nicht erneut an, dupliziert keine Daten |

## 9. Verifikationsstand

- **Unit-/Request-Specs grün** (`spec/database_setup`, `spec/requests/system_setup_spec.rb`):
  Configuration, Store (Roundtrip/Save/Load/Clear), Connection (Redaktion),
  Provisioner (nur fehlende anlegen, Idempotenz, Namensvalidierung),
  LegacyMigration (Extract + Import-Roundtrip + Idempotenz), Setup-API.
- **Migration-Roundtrip** (SQLite→SQLite über die echten Modelle) verifiziert
  UUID-PKs, Beziehungen und Idempotenz.
- **Kein Live-Test gegen einen SQL Server** durchgeführt: der Entwicklungs-Server
  war aus dieser Umgebung nicht erreichbar (Link-Local-Adresse, Port 1433/1443
  nicht verbindbar). Die Adapter-Gems wurden erfolgreich installiert und der
  Code gegen die dokumentierten Schnittstellen verifiziert; ein echter
  End-to-End-Lauf gegen einen SQL Server steht noch aus.
