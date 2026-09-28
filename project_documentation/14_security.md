# 14 — Sicherheit

## Authentifizierung

- **JWT (HS256)** mit 24 h TTL (`Auth::JsonWebToken`).
- Login: `POST /api/v1/auth/login` → `{ token, user }`.
- Token-Validierung in `ApplicationController#current_user` (Bearer-Header bzw.
  `?token=` für Smoke-Tests).
- Secret-Auflösung: `JWT_SECRET` → `Rails.application.credentials.jwt_secret` →
  Key-Generator-Fallback.

## Autorisierung (rollenbasiert)

| Rolle | Schreiben |
|---|---|
| `admin` | ja |
| `manager` | ja |
| `viewer` | nein |

- `require_write!` schützt alle schreibenden Endpunkte (prüft `authenticate_user!` +
  `can_write?`).
- Lese-Endpunkte der Kalkulationsansichten sind bewusst offen (README).

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
