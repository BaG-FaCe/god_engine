# Verkaufspreis-Kalkulationsplattform mit modularem Aufbau

## Rolle

Du bist ein erfahrener Software-Architekt, Senior Ruby-Entwickler, UX/UI-Designer und Full-Stack Engineer.

Entwickle eine moderne, skalierbare Desktop- oder Webanwendung zur Produkt- und Verkaufspreiskalkulation — inklusive eines integrierten **Lieferrisiko-Frühwarnsystems (Supply Chain Risk Intelligence)**, das potenzielle Lieferprobleme bei Materialien frühzeitig erkennt.

### Technologiestack

#### Backend

Verwende:

- Ruby 3.x
- Ruby on Rails 8 (API-Only)
- SQLite (dateibasiert, läuft ohne separaten Datenbankserver und ohne Docker)
- Solid Queue (Rails-8-eigene, DB-basierte Job-Queue) für Hintergrundjobs statt Sidekiq/Redis
- Solid Cache (Rails-8-eigenes, DB-basiertes Caching) für Zwischenspeicherung externer API-Antworten statt Redis
- JSON als primäres Datenaustauschformat

> **Wichtig:** Die Anwendung soll **ohne Docker, ohne separaten Datenbankserver (kein PostgreSQL) und ohne separaten Redis-Prozess** lauffähig sein. Rails 8 bringt mit SQLite sowie den DB-gestützten Adaptern Solid Queue (Hintergrundjobs) und Solid Cache (Caching) alles mit, was vorher PostgreSQL, Sidekiq und Redis übernommen haben. Das reduziert die Installation auf `bundle install` + `rails db:setup` + `rails server` — ideal für lokale Nutzung, einfache Deployments (z. B. auf einem einzelnen Server/VM per Kamal-freiem Deployment oder als gepacktes Binary) und geringen Ressourcenverbrauch.

#### Frontend

Verwende:

- React 19
- TypeScript
- Vite
- Material UI (MUI)
- TanStack Query
- Zustand für State Management
- Recharts für Visualisierungen

Die Anwendung soll als moderne Single-Page-Application umgesetzt werden.

---

# Grundkonzept

Die Anwendung soll nicht als eine große Software entwickelt werden, sondern als modulare Plattform.

Jeder Anwendungsbereich wird als eigenständiges Modul umgesetzt.

Dadurch sollen:

- Codebasen sauber getrennt werden
- Verantwortlichkeiten klar definiert werden
- Wartbarkeit verbessert werden
- Ressourcenverbrauch minimiert werden
- Erweiterungen einfacher integriert werden können

Module werden nur geladen, wenn sie tatsächlich benötigt werden.

---

# Startseite (Dashboard)

Nach dem Start der Anwendung gelangt der Benutzer auf eine moderne Startseite.

Diese besteht aus Kacheln (Tiles).

Jede Kachel repräsentiert ein eigenständiges Modul.

---

## Beispiel

```text
+------------------+
| Produktkalkulator|
+------------------+

+------------------+
| Materialmanager  |
| (Coming Soon)    |
+------------------+

+------------------+
| Produktionsplaner|
| (Coming Soon)    |
+------------------+

+------------------+
| Lagerverwaltung  |
| (Coming Soon)    |
+------------------+

+------------------+
| Reporting        |
| (Coming Soon)    |
+------------------+

+------------------+
| Lieferrisiko-    |
| Monitor          |
| (Coming Soon)    |
+------------------+
```

---

## Aktives Modul

### Produktkalkulator

Nur dieses Modul muss vollständig umgesetzt werden — **inklusive** der Lieferrisiko-Datenfelder je Material und der Anbindung an externe Risikodatenquellen.

Alle anderen Module (inkl. eines späteren eigenständigen "Lieferrisiko-Monitor"-Moduls) dienen zunächst als Platzhalter.

---

# Architektur

## Modulare Struktur

```text
apps/
│
├── calculator/
│
├── material-management/
│
├── production-planner/
│
├── inventory/
│
├── reporting/
│
├── supply-chain-risk/      # neu: Risiko-Intelligence als eigener Service/Modul
│
└── shared/
```

Jedes Modul besitzt:

- eigenes Frontend
- eigene API-Endpunkte
- eigene Komponenten
- eigene Geschäftslogik
- eigene Tests

Gemeinsame Funktionen befinden sich ausschließlich im Shared-Bereich (z. B. gemeinsame HTTP-Client-Wrapper für externe APIs, Rate-Limiting, Caching-Layer).

`supply-chain-risk` ist als **eigener Bounded Context** angelegt, wird aber im aktiven Modul "Produktkalkulator" über eine klar definierte interne API (Service-Objekte / Ports & Adapters) genutzt, damit später eine Auslagerung als Microservice möglich ist, ohne den Kalkulator umzubauen.

---

# Modul: Produktkalkulator

## Ziel

Ermittlung eines realistischen und profitablen Verkaufspreises.

Dabei sollen sämtliche Kosten berücksichtigt werden:

- Materialkosten
- Monatliche Kosten
- Arbeitskosten
- Fixkosten
- Gemeinkosten
- Gewinnspanne
- Steuern

Zusätzlich soll das System **Lieferrisiken pro Material** erfassen, bewerten und visualisieren, um Kalkulationen mit Blick auf Terminsicherheit und Preisvolatilität abzusichern.

---

# Projektverwaltung

Der Benutzer kann:

- Projekt erstellen
- Projekt laden
- Projekt speichern
- Projekt duplizieren
- Projekt archivieren
- Projekt exportieren
- Projekt importieren

---

## Speicherformat

Alle Daten werden als strukturierte JSON-Dateien gespeichert.

Beispiel (erweitert um `supplyChainRisk`):

```json
{
  "projectName": "Produkt A",
  "taxRate": 19,
  "materials": [
    {
      "id": "mat_001",
      "name": "Aluminium Profil 2020",
      "supplier": "Muster GmbH",
      "supplyChainRisk": {
        "originCountry": "DE",
        "shippingRoute": "Rotterdam-Duisburg",
        "riskScore": 23,
        "riskLevel": "low",
        "leadTimeVarianceDays": 2,
        "lastCheckedAt": "2026-09-15T08:00:00Z",
        "dataSources": ["manual", "customs_hs_lookup", "port_congestion_index"]
      }
    }
  ],
  "monthlyCosts": [],
  "fixedCosts": [],
  "pricing": {}
}
```

---

# Tab 1: Materialkosten

Hier werden alle Materialien und Bauteile verwaltet.

Für jedes Material:

- Materialname
- Materialtyp
- Lieferant
- Artikelnummer
- Beschreibung
- Produktbild
- Preis pro Einheit
- Netto / Brutto
- Anzahl
- Lieferzeit
- Lagerort

## Neu: Lieferrisiko-Felder je Material

Zusätzlich zu den Basisfeldern kann pro Material hinterlegt werden:

```text
Herkunftsland / Produktionsland
Zolltarifnummer (HS-Code)
Versandroute / Haupttransportweg (See, Luft, Straße, Schiene)
Alternative Lieferanten (Liste, mit Priorität)
Lieferantenbewertung (intern, 1–5 Sterne)
Single-Source-Kennzeichnung (ja/nein)
Historische Lieferverzögerungen (Anzahl, Tage)
Letzte bekannte Störung (Datum, Ursache, Freitext)
Sanktionslisten-Status (automatisch geprüft)
Frachtkosten-Trend (steigend/stabil/fallend)
Manuelle Risikoeinschätzung (Notiz + Ampel)
```

Diese Felder sind **optional** und können manuell gepflegt oder – sofern eine externe Datenquelle angebunden ist – automatisch befüllt bzw. aktualisiert werden (siehe Abschnitt „Lieferrisiko-Management").

---

# Lieferzeiten

Jedes Material soll eine Lieferzeit besitzen.

Mögliche Eingaben:

```text
3 Tage
7 Tage
14 Tage
4 Wochen
2 Monate
```

Automatische Berechnungen:

- Durchschnittliche Lieferzeit
- Kritische Lieferzeiten
- Längste Lieferzeit
- **Lieferzeit-Abweichung** (geplant vs. historisch tatsächlich, sofern Daten vorliegen)
- **Risikogewichtete Lieferzeit** (Erwartungswert unter Einbezug des Risikoscores)

---

# Lieferrisiko-Management (Supply Chain Risk Intelligence)

## Zielsetzung

Für jedes Material sollen zusätzliche Informationen hinterlegt werden können, mit denen sich **potenzielle Lieferprobleme frühzeitig erkennen** lassen — sowohl durch manuelle Einschätzung als auch durch Anbindung automatisierter, externer Datenquellen.

Wichtig für die Architektur: Es wird zwischen **frei verfügbaren / Open-Data-Quellen** und **spezialisierten, meist kostenpflichtigen Logistik-/SCRM-APIs** unterschieden. Das System soll so gebaut sein, dass beide Kategorien über einen einheitlichen internen Adapter (Ports & Adapters / Strategy-Pattern) angebunden werden können — je nach Budget und Verfügbarkeit des Nutzers.

### Kategorie A — Kostenlose / Open-Data-Quellen (Basis-Absicherung)

Diese Quellen liefern kontextuelle Risikosignale, aber keine lückenlose End-to-End-Sendungsverfolgung:

| Datenquelle | Art der Information | Nutzen für Frühwarnung |
|---|---|---|
| World Bank Logistics Performance Index (LPI) | Länder-Score für Logistikqualität | Grundrisiko je Herkunftsland |
| UN Comtrade | Außenhandelsstatistiken | Plausibilisierung von Lieferketten/Herkunft |
| GDACS (Global Disaster Alert and Coordination System) | Naturkatastrophen-Warnungen weltweit | Frühwarnung bei Erdbeben, Stürmen, Überschwemmungen in Lieferregionen |
| ReliefWeb / USGS Erdbebendienst | Krisen- und Erdbebendaten | Ergänzende Risikosignale für Produktionsregionen |
| NOAA / Open-Meteo (Wetterdaten) | Wetter- und Sturmwarnungen | Risiko für See-/Luftfracht-Verzögerungen |
| EZB-Wechselkurs-API | Tagesaktuelle Wechselkurse | Preisrisiko bei Importmaterialien |
| EU-Sanktionsliste / OFAC SDN List | Sanktionierte Firmen/Personen | Compliance-Check von Lieferanten |
| Zoll-/HS-Code-Datenbanken (z. B. EU TARIC) | Zolltarifnummern, Einfuhrbestimmungen | Erkennung von Zoll-/Grenzrisiken |
| Öffentliche Hafenauslastungs-Indizes (z. B. Meldungen der Hafenbehörden) | Stauwarnungen an Häfen | Frühwarnung bei Seefracht-Engpässen |
| Freightos Baltic Index (FBX, öffentlicher Teil) | Container-Frachtraten-Trend | Indikator für Frachtkostenvolatilität |

→ Diese Quellen sind gut geeignet für eine **kostengünstige Basisversion** des Frühwarnsystems und liefern **Kontext-/Makrorisiken**, keine sendungsgenauen Echtzeitdaten.

### Kategorie B — Spezialisierte, meist kostenpflichtige Logistik-/SCRM-APIs (erweiterte Absicherung)

Diese Anbieter liefern sendungs- und lieferantenspezifische Echtzeit- bzw. Frühwarndaten:

| Anbieter | Fokus |
|---|---|
| project44, FourKites | Echtzeit-Sendungsverfolgung (Visibility) über Transportträger hinweg |
| Everstream Analytics, Resilinc, riskmethods (Sphera), Interos | Supply-Chain-Risk-Monitoring, Frühwarnung bei Lieferanten-/Regionenrisiken |
| Dun & Bradstreet (D&B), Moody's / S&P Global | Finanzielle Bonitäts- und Ausfallrisiko-Scores von Lieferanten |
| Flexport API, Maersk API, DHL/UPS/FedEx Tracking-APIs | Sendungsgenaues Tracking einzelner Lieferungen |
| Descartes, Overhaul | Grenz-/Zoll- und Sicherheitsrisiko-Monitoring |

→ Diese Anbieter sind für Unternehmen mit höherem Absicherungsbedarf relevant und werden im System als **optionale, pluggable Provider** hinter einer gemeinsamen Schnittstelle (`RiskDataProvider`) integriert.

### Architekturprinzip: Provider-Abstraktion

```text
SupplyChainRiskService
        │
        ▼
 RiskDataProvider (Interface)
   ├── FreeDataProvider (LPI, GDACS, Wetter, Sanktionslisten, Wechselkurse, HS-Codes …)
   ├── PaidProvider::Project44Adapter
   ├── PaidProvider::ResilincAdapter
   ├── PaidProvider::DunAndBradstreetAdapter
   └── ManualRiskAssessment (Nutzereingabe als Fallback, immer verfügbar)
```

- Jeder Provider implementiert dieselbe Schnittstelle (`fetch_risk_for(material)` → normalisiertes `RiskAssessment`-Objekt).
- Nutzer ohne kostenpflichtige API-Zugänge erhalten automatisch den `FreeDataProvider` + manuelle Eingabe.
- API-Keys für kostenpflichtige Provider werden verschlüsselt je Mandant/Projekt hinterlegt (siehe Sicherheit).
- Alle Provider-Antworten werden **normalisiert** in ein einheitliches `RiskAssessment`-Schema überführt (Risikoscore 0–100, Ampel, Quelle, Zeitstempel, Freitext-Begründung).

### Datenmodell-Erweiterung

Neue Tabellen (SQLite, über Rails-Migrationen, `jsonb`-Spalten werden dabei als reguläre `json`/Text-Spalten mit JSON-Serialisierung abgebildet):

```text
materials
  id, project_id, name, type, supplier_id, article_number, …

suppliers
  id, name, country, rating, is_single_source, sanctions_checked_at, …

risk_assessments
  id, material_id, provider, risk_score, risk_level,
  lead_time_variance_days, reason, raw_payload (json),
  fetched_at, expires_at

risk_events
  id, material_id, event_type (weather|disaster|sanction|port_congestion|price_spike|customs),
  severity, description, source, occurred_at

risk_provider_configs
  id, project_id, provider_key, api_key_encrypted, enabled, poll_interval_minutes
```

### API-Design (Erweiterung REST)

```text
GET    /api/v1/materials/:id/risk_assessment
POST   /api/v1/materials/:id/risk_assessment/manual   # manuelle Einschätzung
GET    /api/v1/materials/:id/risk_events
GET    /api/v1/risk_providers                          # verfügbare Provider (frei/kostenpflichtig)
POST   /api/v1/risk_providers/:key/configure           # API-Key hinterlegen
POST   /api/v1/materials/:id/risk_assessment/refresh    # manuelles Neuladen (Sidekiq-Job)
```

### Hintergrundjobs (Sidekiq)

- `RiskDataRefreshJob` — läuft periodisch (konfigurierbares Intervall je Provider) und aktualisiert `risk_assessments` für alle aktiven Materialien.
- `SanctionsListCheckJob` — täglicher Abgleich aller Lieferanten gegen EU-/OFAC-Sanktionslisten.
- `DisasterAlertPollingJob` — pollt GDACS/USGS/NOAA für Herkunftsländer aller Materialien und erzeugt `risk_events` bei Treffern.
- `FreightIndexSyncJob` — synchronisiert Frachtraten-Indizes für Trendanzeige.
- Alle Jobs cachen Rohantworten in **Redis** (TTL je nach Datenquelle, z. B. 24h für LPI, 15 min für Katastrophenwarnungen), um externe Rate-Limits zu schonen und Kosten bei kostenpflichtigen APIs zu minimieren.

### Frühwarn-Ampel auf der Materialkarte

Jede Materialkarte erhält zusätzlich eine **Risiko-Ampel**:

```text
┌─────────────────────────────┐
│ Bild                        │
│                             │
│ Aluminium Profil 2020       │
│ Lieferant: Muster GmbH      │
│ Preis: 4,50 €               │
│ Lieferzeit: 14 Tage         │
│ Bestand: 125                │
│                             │
│ 🟢 Lieferrisiko: Niedrig (23)│
│ Quelle: LPI + manuelle Note │
└─────────────────────────────┘
```

Ampel-Logik (Beispiel):

```text
0–33   → 🟢 Niedrig
34–66  → 🟡 Mittel
67–100 → 🔴 Hoch
```

Bei 🔴 oder neuem `risk_event` (z. B. Naturkatastrophe im Herkunftsland) wird eine **In-App-Benachrichtigung** ausgelöst und im Dashboard unter „Kritische Lieferrisiken" aggregiert.

---

# Materialkarte

Für jedes Material soll automatisch eine Materialkarte erstellt werden.

## Inhalt

### Materialinformationen

```text
Name
Typ
Lieferant
Artikelnummer
```

### Einkauf

```text
Preis Netto
Preis Brutto
Mindestabnahmemenge
```

### Bestand

```text
Lagerbestand
Meldebestand
```

### Logistik

```text
Lieferzeit
Lieferadresse
Lieferantendaten
```

### Lieferrisiko (neu)

```text
Risikoscore & Ampel
Herkunftsland
Sanktionsstatus
Alternative Lieferanten
Letzte Störungsmeldung
Datenquelle(n)
```

### Medien

```text
Produktbild
Dokumente
Datenblätter
CAD-Dateien
```

---

## Materialkartendarstellung

Jedes Material erhält eine visuelle Karte (siehe Beispiel oben inkl. Risiko-Ampel).

---

# Tab 2: Monatliche Kosten

Erfassung wiederkehrender Kosten.

Beispiele:

- Miete
- Strom
- Marketing
- Versicherungen
- Hosting
- Leasing
- Wartung

---

## Prognose

Erfassung von:

```text
Prognostizierte Verkäufe pro Monat
```

und

```text
Tatsächliche Verkäufe pro Monat
```

---

## Berechnungen

```text
Monatliche Kosten pro Einheit
```

```text
Monatliche Kosten / Prognose
```

Zusätzlich:

```text
Gewinn- oder Verlustabweichung
```

zwischen Prognose und Realität.

---

# Monatliche Kosten Templates

Kostenblöcke sollen als Vorlagen gespeichert werden können.

Beispiele:

- Online-Shop
- Kleinserie
- Produktion
- Dienstleistung

Funktionen:

- Speichern
- Laden
- Exportieren
- Importieren
- Bearbeiten
- Löschen

---

# Tab 3: Fixkosten & Gemeinkosten

Enthält:

- Arbeitskosten
- Entwicklungskosten
- Konstruktion
- Qualitätskontrolle
- Verpackung
- Vertriebsaufschläge
- Gewinnaufschläge

---

## Arbeitskosten

Felder:

```text
Mitarbeiter
Stunden
Stundensatz
```

Berechnung:

```text
Stunden × Stundensatz
```

---

## Prozentuale Zuschläge

Beispiele:

```text
Risikoaufschlag (kann optional an den Lieferrisiko-Score gekoppelt werden,
z. B. automatischer Vorschlag: +2% bei mittlerem, +5% bei hohem Gesamtrisiko)
Gewinnaufschlag
Vertriebsmarge
```

---

# Tab 4: Preiskalkulation

Zusammenführung aller Kosten.

---

## Formel

```text
Materialkosten
+ Monatliche Kosten / Anzahl Einheiten
+ Arbeitskosten / Anzahl Einheiten
+ Fixkosten / Anzahl Einheiten
+ Gemeinkosten
+ optionaler Risikoaufschlag (aus Lieferrisiko-Score abgeleitet)
=
Gesamtkosten
```

---

## Ausgabe

Anzeigen:

- Gesamtkosten Netto
- Gesamtkosten Brutto
- Kosten pro Einheit Netto
- Kosten pro Einheit Brutto
- Aggregiertes Lieferrisiko des Produkts (gewichtet über alle enthaltenen Materialien)

---

# Manuelle Preisoptimierung

Der Nutzer soll Preise anpassen können, bzw. einen gewünschten Zielpreis (brutto und/oder netto) vorgeben können.

Beispiel:

Berechnet:

```text
29,37 €
```

Gewünschter Preis:

```text
29,99 €
```

Die Anwendung berechnet anschließend automatisch:

- Gewinn pro Stück Brutto und Netto
- Gewinnmarge
- Deckungsbeitrag
- Umsatz
- Monatsgewinn

---

# Tab 5: Dashboard

Visualisierung aller Kennzahlen.

---

## Kennzahlen

- Materialkosten
- Monatliche Kosten
- Fixkosten
- Arbeitskosten
- Gewinn
- Umsatz
- Break-Even-Punkt
- **Kritische Lieferrisiken** (Anzahl Materialien mit 🔴-Status)
- **Durchschnittlicher Lieferrisiko-Score** über alle Materialien

---

## Diagramme

### Kostenverteilung

Kreisdiagramm

---

### Gewinnentwicklung

Liniendiagramm

---

### Prognose vs. Realität

Balkendiagramm

---

### Lieferrisiko-Verteilung (neu)

Kreis- oder Balkendiagramm über die Ampel-Kategorien (niedrig/mittel/hoch) aller Materialien.

---

### Risiko-Timeline (neu)

Liniendiagramm des aggregierten Risikoscores über die Zeit, inkl. Markierung eingetretener `risk_events` (z. B. Naturkatastrophe, Sanktionstreffer, Frachtkostenspitze).

---

# Steuerverwaltung

Zentraler Einstellungsbereich.

Felder:

```text
MwSt.-Satz
Steuerprofil
Land
```

Standard:

```text
19 %
```

---

# Performance-Anforderungen

Die Anwendung soll extrem ressourcenschonend sein.

---

## Lazy Loading

Module werden erst geladen, wenn der Benutzer sie öffnet.

Beispiel:

```text
Produktkalkulator öffnen
→ Modul laden

Reporting nicht geöffnet
→ Kein Laden
```

Das Lieferrisiko-Modul lädt externe Providerdaten **on demand pro Material** (nicht global beim Öffnen des Kalkulators) und nutzt Redis-Caching, um wiederholte externe Abfragen zu vermeiden.

---

## Trennung der Codebasis

Jedes Modul besitzt:

```text
Eigene API
Eigene Komponenten
Eigene Stateverwaltung
Eigene Tests
```

Gemeinsame Komponenten liegen ausschließlich in:

```text
shared/
```

Der `supply-chain-risk`-Adapter-Layer liegt aus Wiederverwendungsgründen in `shared/risk-intelligence/`, damit auch spätere Module (Materialmanager, Produktionsplaner) darauf zugreifen können.

---

# Sicherheit

- Rollen- und Benutzerkonzept vorbereiten
- API-Authentifizierung
- Input-Validierung
- Audit-Logs
- Fehlerprotokollierung
- **Verschlüsselte Speicherung von API-Keys** externer Risiko-/Logistikanbieter (z. B. Rails `ActiveRecord::Encryption`)
- **Rate-Limiting** für ausgehende Aufrufe an externe APIs, um Kostenkontrolle bei kostenpflichtigen Providern sicherzustellen
- Klare Kennzeichnung, welche Risikodaten **automatisiert** vs. **manuell** erfasst wurden (Nachvollziehbarkeit/Haftungsfragen)

---

# Exportfunktionen

Unterstützte Formate:

- JSON
- CSV
- XLSX
- PDF

Der Export soll optional die Lieferrisiko-Bewertung je Material inkl. Quelle und Zeitstempel enthalten.

---

# Qualitätssicherung

Implementiere:

- Unit-Tests
- Integrationstests
- API-Tests
- Frontend-Tests
- End-to-End-Tests
- **Contract-Tests** für jeden `RiskDataProvider`-Adapter (inkl. Mocking externer APIs, da diese teils kostenpflichtig/rate-limitiert sind)

---

# Zu erstellende Ergebnisse

Erstelle vollständig:

1. Software-Architektur
2. Datenmodell (inkl. Lieferrisiko-Entitäten)
3. JSON-Schema (inkl. `supplyChainRisk`)
4. Datenbankmodell
5. API-Design (REST, inkl. Risk-Provider-Endpunkte)
6. Frontend-Konzept
7. Navigationskonzept
8. Dashboard-Design (inkl. Risiko-Diagramme)
9. Materialkarten-System (inkl. Risiko-Ampel)
10. Lieferzeiten-Management
11. Lieferrisiko-Management (Provider-Abstraktion frei vs. kostenpflichtig)
12. Preisberechnungslogik (inkl. optionalem Risikoaufschlag)
13. Projektstruktur
14. Testkonzept
15. Deployment-Konzept
16. Vollständigen produktionsreifen Quellcode

Verwende Clean Architecture, Domain-Driven Design (DDD), SOLID-Prinzipien und eine modulare Monolith-Architektur, die später problemlos in Microservices aufgeteilt werden kann — insbesondere der `supply-chain-risk`-Bounded-Context soll von Anfang an so entkoppelt sein, dass er als eigener Service extrahierbar ist. please continue where it left of