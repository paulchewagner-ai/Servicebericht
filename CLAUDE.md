# Projekt: Sprachgeführter Servicebericht (iPad)

> Stand: 05.11.2026 – ersetzt die erste (formularbasierte) Beschreibung vollständig.
> Fiktives Projekt (Übungs-/Demo-App), keine echten Kundendaten.
> Aktuell: Etappe 1 umgesetzt, wartet auf Test im Simulator und OK.

## Ziel
Eine iPad-App für Servicetechniker, die gewerbliche Spülmaschinen betreuen. Nach dem Einsatz
(typischerweise im Auto) startet der Techniker mit einem großen Knopf einen **Sprachdialog**.
Die App stellt **7 Standardfragen** per Sprachausgabe, der Techniker antwortet frei.
Die Antworten werden in **4 Freitextfeldern** gespeichert. Claude (Cloud) stellt Rückfragen,
wenn etwas unklar oder unvollständig ist, und formuliert den Bericht aus. Ergebnis:
PDF-Bericht und eine fortlaufend gepflegte Excel-Datei.

## Arbeitsweise für Claude
- In Etappen arbeiten, nach jeder Etappe zusammenfassen und auf OK warten.
- Gebaut und im Simulator getestet wird auf dem Mac des Auftraggebers (Xcode); die Cloud-Umgebung
  hat kein Xcode.
- Vor jeder externen Bibliothek nachfragen und begründen.
- Oberfläche und Sprachausgabe auf Deutsch, Du-Form gegenüber dem Techniker; PDF in Sie-Form.
- Keine erfundenen Beispieldaten im Produkt; Testdaten nur in Previews / Debug-Modus.
- Bei Unklarheiten nachfragen. Diese Datei aktuell halten.

## Technik
- Swift, SwiftUI, iPadOS 17+, Hoch- und Querformat. Speicherung lokal mit SwiftData.
- Sprachausgabe: `AVSpeechSynthesizer` (Deutsch, offline).
- Spracherkennung: `SFSpeechRecognizer` (de-DE), bevorzugt auf dem Gerät (offline).
- KI: Claude über die Anthropic Messages API, **nicht direkt aus der App**, sondern über einen
  kleinen eigenen Proxy-Dienst, der den API-Schlüssel hält (Schlüssel gehört nicht in die App).
  KI-Zugriff hinter einem Protokoll (`ReportAssistant`), damit Anbieter/Weg austauschbar bleibt.
- Ohne Netz: Fragen und Antworten funktionieren offline; Rückfragen und Ausformulierung werden
  nachgeholt, sobald Netz da ist (Warteschlange, Status je Bericht).
- PDF mit Bordmitteln (`UIGraphicsPDFRenderer`). Teilen über das iOS-Teilen-Menü.

## Claude-Anbindung (Vorschlag)
```
iPad-App ──HTTPS──▶ Proxy (Cloudflare Worker) ──HTTPS──▶ api.anthropic.com/v1/messages
          App-Token                hält API-Schlüssel, Modell fest,
                                   max_tokens-Grenze, Ratenlimit
```
- Proxy: Cloudflare Worker (ca. 50 Zeilen JavaScript, kostenloser Tarif reicht, Schlüssel als
  verschlüsseltes Secret). Der Proxy legt Modell und Obergrenzen fest, damit ein ausgelesenes
  App-Token nicht beliebig für andere Zwecke nutzbar ist.
- Für Entwicklung und Tests: Debug-Modus ruft die API direkt auf, Schlüssel in
  `Secrets.xcconfig` (per `.gitignore` ausgeschlossen, nie im Release-Build).
- Modelle: kurze Rückfragen im Dialog mit einem schnellen Modell (Haiku), Ausformulierung des
  Berichts mit einem stärkeren Modell (Sonnet). Konfigurierbar.

## Sprachdialog
- Bedienung vollständig per Sprache. Ein Tipp auf „Sprachbericht starten“ beginnt den Dialog.
- Sprachbefehle: „Wiederholen“, „Zurück“, „Weiter“ / „Nichts“ (Frage überspringen), „Abbrechen“.
- Rückfragen: Claude prüft jede Antwort und fragt höchstens 2-mal pro Frage nach, wenn etwas
  unverständlich oder unvollständig ist. Ohne Netz: nur „Ich habe dich nicht verstanden, bitte
  wiederhole“ bei leerer Erkennung.
- Am Ende liest die App eine kurze Zusammenfassung vor und fragt „Soll ich den Bericht speichern?“.
- Sicherheit: Nutzung nur im stehenden Fahrzeug (Hinweis beim Start).

## Fragen (freigegeben am 05.11.2026)
| # | Frage (Sprachausgabe) | Freitextfeld |
|---|---|---|
| 1 | Bei welchem Kunden warst du, und wo steht die Maschine? | Einsatz und Maschine |
| 2 | Um welche Maschine ging es? Nenne Hersteller, Bauart, Modell und, wenn zur Hand, die Seriennummer. | Einsatz und Maschine |
| 3 | Was war der Anlass des Einsatzes? Zum Beispiel Störung, Wartung oder Inbetriebnahme – und welcher Fehler wurde gemeldet? | Befund |
| 4 | Was hast du festgestellt? Nenne die Ursache und auffällige Messwerte, etwa Temperaturen oder Wasserhärte. | Befund |
| 5 | Welche Arbeiten hast du durchgeführt? | Arbeiten und Material |
| 6 | Welche Ersatzteile hast du verbaut? Bitte mit Bezeichnung, Artikelnummer und Menge. | Arbeiten und Material |
| 7 | In welchem Zustand hast du die Maschine übergeben, und ist ein Folgeeinsatz nötig? | Ergebnis und nächste Schritte |

Automatisch erfasst (nicht gefragt): Einsatzdatum (heute), Techniker (aus Einstellungen),
Berichtsnummer `SB-JJJJMMTT-XXXX`, Erfassungszeitpunkt, Rohtranskript jeder Antwort.

## Bericht
- Gespeichert werden: Rohtranskripte (unverändert) und die 4 von Claude ausformulierten Felder.
- Claude darf nur verwenden, was gesagt wurde – nichts ergänzen oder erfinden.
- Status je Bericht: Entwurf · wartet auf Netz · fertig · Fehler.

## PDF (A4 hoch)
Kopf in Primärfarbe mit Logo-Platzhalter, Titel, Berichtsnummer, Datum, Techniker; danach die
4 Felder als Abschnitte (leere weglassen). Fußzeile „Seite x von y“.
Dateiname `Servicebericht_<Berichtsnummer>.pdf`.

## Excel
Eine fortlaufende Datei auf dem Gerät, je Bericht eine Zeile: Berichtsnummer, Einsatzdatum,
Erfassungszeitpunkt, Techniker, die 4 Felder, Status. Teilen über das Teilen-Menü.

## Corporate Design
Wie bisher (MEIKO, vorläufige Farben in `Theme.swift`: Dunkelblau `#0A2540`, Cyan `#00B3FF`;
nie Weiß auf Cyan; Logo-Platzhalter; SF Pro; Tippflächen ≥ 44 pt; Dark Mode).

## Etappen (Vorschlag)
1. Projektgerüst, Theme, Startbildschirm mit großem Sprachknopf, Menü, Einstellungen (Techniker-Name).
2. Sprachdialog offline: Fragen vorlesen, Antworten erkennen, Sprachbefehle, Entwurf speichern.
3. Claude-Anbindung über Proxy: Rückfragen im Dialog, Ausformulierung der 4 Felder, Warteschlange ohne Netz.
4. Berichtsliste, Detailansicht, Löschen.
5. PDF.
6. Excel (fortlaufend).
7. Feinschliff, Barrierefreiheit, Tests.
Später: Fotos, zentrale Ablage, Unterschrift (derzeit nicht benötigt).

## Entscheidungen
- 05.11.2026: Neue Beschreibung ersetzt die alte. Sprachdialog statt Formular, 7 Fragen, 4 Freitextfelder.
- KI: Claude in der Cloud. Bericht wird fertiggestellt, wenn Netz verfügbar ist.
- Bedienung vollständig per Sprache. Keine Fotos und keine Unterschrift in der ersten Version.
- Fiktives Projekt: Datenschutzvertrag (AVV) mit Anthropic entfällt.
- Xcode-Projekt im Xcode-16-Format (synchronisierte Ordner): neue Dateien im Ordner
  `Servicebericht/` gehören automatisch zum Ziel. Benötigt Xcode 16 oder neuer.
- Bundle-ID vorläufig `com.example.servicebericht`; Team in Xcode unter „Signing“ wählen.
- Logo: Bild mit dem Namen „Logo“ in `Assets.xcassets` legen, der Platzhalter verschwindet automatisch.
- Menü: Startseite, Vergangene Berichte, Einstellungen (Bedienungsanleitung und Kontakte
  aus der alten Beschreibung entfallen).
- Techniker-Name wird in den Einstellungen gepflegt; ohne Namen startet kein Bericht.

## Offene Punkte
- Freigabe der 7 Fragen und der 4 Felder.
- Proxy-Vorschlag (Cloudflare Worker) bestätigen, oder nur Debug-Direktzugriff für die Demo.
- Excel: Bibliothek oder eigener schlanker Schreiber (siehe Etappe 6).
- Ablage des Codes: Name des GitHub-Repositorys (owner/repo) fehlt noch.
- Offizielle CI-Werte und Logo; Verteilung an Techniker (TestFlight/MDM).
