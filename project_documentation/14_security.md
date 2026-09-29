# 14 — Sicherheit

## Authentifizierung (globaler Gate)

Die Plattform ist **privat by default**. Jeder Endpunkt — mit Ausnahme der
explizit erlaubten Pre-Authentifizierungs-Oberfläche — verlangt eine gültige,
nicht abgelaufene, nicht widerrufene Session eines aktiven Benutzers. Der Gate
ist global in `ApplicationController` verdrahtet
(`before_action :authenticate_user!`) und wirkt damit auf **alle** Controller;
er hängt nicht davon ab, dass ein einzelner Controller `authenticate_user!`
erinnert.

### Öffentliche Oberfläche (Pre-Authentifizierung)

| Endpunkt | Zweck |
|---|---|
| `GET /api/v1/health` | Liveness-Probe (auch vor SQL-Setup erreichbar) |
| `GET/POST /api/v1/system/setup/*` | Ersteinrichtung (nur solange kein SQL-Backend konfiguriert ist) |
| `POST /api/v1/auth/login` | Anmeldung |

Alles andere (`projects`, `materials`, `users`, `sessions`, `risk_events`,
`risk_notifications`, `system/status`, `security_events`, `jobs`, …) verlangt
eine valide Session.

### Session-Token (SQL-gestützt)

- Login `POST /api/v1/auth/login` → persistentes Session-Token. `Session.issue!`
  liefert das Raw-Secret (32-Byte-Hex) genau einmal aus; die DB speichert nur den
  SHA-256-Hash (`token_hash`).
- Validierung in `ApplicationController#current_user` über `Session.authenticate`:
  Token-Hash → aktive, nicht abgelaufene, nicht widerrufene Session → aktiver User.
- Es gibt **keinen** zweiten Authentifizierungsweg (kein JWT-Fallback): eine vom
  Session-Store abgelehnte/ungültige Session erhält keine zweite Chance.

### Token-Transport und -Speicherung

- Das Session-Token wird **ausschließlich** über den `Authorization: Bearer
  <token>`-Header übertragen. `?token=`-Query-Parameter werden ignoriert, da
  Tokens in URLs in Access-Logs, Browser-Verlauf und Referrer leaken.
- **Frontend-Speicherung:** Das Token liegt in `localStorage`
  (`god-engine.auth.token`). Das ist für dieses Deployment-Modell bewusst so
  gewählt: eine statische React-SPA spricht eine zustandslose Rails-API über
  den Authorization-Header an — es gibt keine serverseitige Session-Cookie.
  Ein Wechsel auf HttpOnly-Cookies wäre ein Architektur-Redesign (Cookie-Session
  + CSRF-Schutz) und ist hier nicht vorgesehen.
- **Kompromiss & Begrenzung:** localStorage ist für Scripts lesbar (XSS-Risiko).
  Die Auswirkung ist begrenzt, weil das Token bei jedem Start serverseitig
  re-validiert wird (`/auth/me`) und serverseitig jederzeit widerrufen werden
  kann. Ein zusätzlicher Härtungsschritt (separat, außerhalb dieses Umfangs)
  wäre eine Content-Security-Policy.

### Startup-Fluss (Fail-closed)

```
SQL-Konfiguration vorhanden?  Nein → Ersteinrichtung
           Ja
Gespeichertes Token vorhanden?  Nein → Login
           Ja
Token validieren (/auth/me): ungültig/abgelaufen/widerrufen → Login
           Ja
Benutzer laden: fehlt / inaktiv → Login
           Ja
Plattform / Dashboard
```

Kein Pfad führt ohne Session-Validierung ins Dashboard. Das Frontend re-validiert
das gemerkte Token bei **jedem** Start (`stores.ts#bootstrap` → `GET /auth/me`)
und rendert die App-Shell nur bei bestätigter Session (`App.tsx`).

### Fail-closed

- Kein Token, unbekanntes/manipuliertes Token, abgelaufene/widerrufene Session,
  deaktivierter Benutzer → **401** (`NotAuthorized`).
- Validierungsfehler (DB nicht erreichbar, inkonsistente Daten, Exception) →
  ebenfalls **401** — niemals „als angemeldet annehmen“.

Das Frontend ist nur UX-Grenze; die **Sicherheitsgrenze ist das Backend**: jede
geschützte Operation prüft die Session serverseitig unabhängig von der UI.

## Autorisierung (rollenbasiert)

| Rolle | Schreiben | Admin |
|---|---|---|
| `admin` | ja | ja |
| `manager` | ja | nein |
| `viewer` | nein | nein |

- `authenticate_user!` (global) — gültige Session.
- `require_write!` — Schreibzugriff (`admin`/`manager`).
- `require_admin!` — nur `admin` (User-/Session-Verwaltung, Security-Events,
  Systemstatus). Authentifizierung ersetzt **keine** Autorisierung.

## Schutzmaßnahmen

| Maßnahme | Ort |
|---|---|
| Rate-Limiting (eingehend) | `config/initializers/rack_attack.rb` (Login 10/60 s, API 600/300 s, Blocklist `BLOCKED_IPS`) |
| Rate-Limiting (ausgehend) | `Shared::Infrastructure::Http::RateLimiter` (je Provider/Minute) |
| Brute-Force-Schutz | Rack::Attack (Login je IP **und** E-Mail) |
| Passwort-Hashing | bcrypt (`has_secure_password`, min. 12 Zeichen) |
| Parameter-Filter | `filter_parameter_logging.rb` (password, token, api_key, secret, …) |
| CORS | `cors.rb` (Whitelist `CORS_ORIGINS`) |
| Verschlüsselte API-Keys | `RiskProviderConfig#encrypts :api_key` (ActiveRecord::Encryption) |
| Credential-Redaktion in Logs | `JsonClient#redact` (Query-Params `api_key/token/…`) |
| Audit-Trail | `Audit::Recorder` (Create/Update/Delete/Export/Import/Login/Config/Refresh) |
| Kein Secret-Leck | `RiskProviderConfig#api_key_hint` maskiert; Endpunkte geben nie den Key zurück |

## SQL-Server-Zugangsdaten

Die Zugangsdaten für das optionale SQL-Server-Backend werden **nie im Code oder
im Repository** abgelegt:

- Vorrangig über Umgebungsvariablen (`SQL_SERVER`, `SQL_USER`, `SQL_PASSWORD`, …),
  in Produktion über einen Secret-Manager.
- Alternativ über die lokale, **gitignorierte** Datei
  `api/config/sqlserver.local.yml` (vom Ersteinrichtungs-Bildschirm geschrieben,
  POSIX-Rechte 0600).
- Das Passwort wird nie geloggt, nie in API-Antworten zurückgegeben und aus
  Fehlermeldungen redigiert (`Configuration#redacted`, `Connection#sanitize`).
- Die Ersteinrichtungs-Endpunkte sind gesperrt, sobald konfiguriert
  (HTTP 409), um Ausforschung/Neueinrichtung einer laufenden Instanz zu verhindern.

Details → [18_sql_server.md](18_sql_server.md).

## Verschlüsselung at Rest

- `ActiveRecord::Encryption` mit `AR_ENCRYPTION_PRIMARY_KEY`,
  `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT`.
- In Entwicklung werden Default-Keys verwendet (`support_unencrypted_data` außer
  Produktion); in Produktion sind die Keys **Pflicht**.

## Bekannte sicherheitsrelevante Hinweise

- Der Produktions-Default der Verschlüsselungs-Keys ist hartkodiert im
  `application.rb`-Fallback (`god-engine-development-…`) — in Produktion müssen die
  ENV-Variablen zwingend gesetzt sein (siehe `15_known_issues.md`).
- `api_secret` (OAuth2-Client-Secret) wird weiterhin nur über ENV gepflegt, nicht
  verschlüsselt in der DB (siehe `16_improvement_opportunities.md`).
- Es gibt keinen ActionCable/WebSocket-Push; Benachrichtigungen nutzen Polling.
