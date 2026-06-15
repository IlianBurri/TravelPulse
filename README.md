# 🌍 TravelPulse

> Ein Bash-Skript, das alle wichtigen Reise-Infos zu einer Stadt auf Knopfdruck liefert – Zeit, Wetter, Wechselkurs, Krypto-Kurse und optional ein lokaler KI-Reiseassistent.

[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📖 Inhaltsverzeichnis

- [Über das Projekt](#-über-das-projekt)
- [Features](#-features)
- [Voraussetzungen](#-voraussetzungen)
- [Installation](#-installation)
- [Verwendung](#-verwendung)
- [Beispiel-Ausgabe](#-beispiel-ausgabe)
- [KI-Assistent (Ollama)](#-ki-assistent-ollama)
- [Verwendete APIs](#-verwendete-apis)
- [Programmablauf](#-programmablauf)
- [Fehlerbehandlung](#-fehlerbehandlung)
- [Projektkontext](#-projektkontext)

---

## 🎯 Über das Projekt

Wer ins Ausland reist, muss normalerweise mehrere Apps konsultieren: eine für die Ortszeit, eine fürs Wetter, eine für den Wechselkurs und eine für Krypto-Kurse. **TravelPulse** bündelt all diese Informationen in einem einzigen Terminal-Befehl.

Zusätzlich kann ein lokales KI-Modell über [Ollama](https://ollama.com) befragt werden, um konkrete Reisefragen zur gewählten Stadt zu beantworten – vollständig offline und kostenlos.

---

## ✨ Features

| Feature | Beschreibung |
|---|---|
| 🕐 **Lokale Zeit** | Aktuelle Uhrzeit der Zielstadt via Zeitzonen-API |
| 🌤️ **Wetter** | Temperatur, Wind & Wetterzustand in Echtzeit |
| 💱 **Wechselkurs** | Heimwährung in Zielwährung umgerechnet |
| ₿ **Krypto-Kurse** | Aktuelle BTC- & ETH-Preise in USD |
| 🤖 **KI-Assistent** | Optionaler lokaler Chat via Ollama für Reisefragen |

---

## 🔧 Voraussetzungen

- **Bash** (Linux, macOS oder Windows mit WSL2)
- [`curl`](https://curl.se/) – für API-Anfragen
- [`jq`](https://jqlang.github.io/jq/) – für JSON-Verarbeitung
- *(optional)* [Ollama](https://ollama.com) – für den lokalen KI-Assistenten

### Installation der Abhängigkeiten

```bash
# Ubuntu / Debian / WSL2
sudo apt update && sudo apt install curl jq

# macOS (mit Homebrew)
brew install curl jq
```

---

## 📥 Installation

```bash
git clone https://github.com/IlianBurri/TravelPulse.git
cd TravelPulse
chmod +x travelpulse.sh
```

---

## ▶️ Verwendung

```bash
./travelpulse.sh
```

Das Skript fragt dich nacheinander nach:

1. **Stadt** – z. B. `Tokyo` (Standard: `Zürich`)
2. **Heimwährung** – z. B. `CHF` (Standard: `CHF`)

Bei leerer Eingabe wirst du erneut gefragt – das Skript bricht nicht einfach ab.

---

## 📋 Beispiel-Ausgabe

```
==========================================
             TravelPulse
==========================================
Reise-Infos: Wetter, Zeit, Wechselkurs & Krypto

In welche Stadt reist du? [Zürich]: Tokyo
Deine Heimwährung (z. B. CHF, EUR, USD) [CHF]: CHF

Suche Informationen zu "Tokyo" ...

==========================================
 TravelPulse: Tokyo, Japan (JP)
==========================================

[Zeit]
  Zeitzone:    Asia/Tokyo
  Lokale Zeit: 14.06.2026 22:15

[Standort]
  Koordinaten: 35.6895, 139.6917

[Wetter]
  Zustand:     Klarer Himmel
  Temperatur:  24.3 °C
  Wind:        8.2 km/h

[Wechselkurs]
  1 CHF = 168.42 JPY

[Krypto]
  BTC: 67890.12 USD
  ETH: 3456.78 USD
```

---

## 🤖 KI-Assistent (Ollama)

Am Ende fragt dich das Skript, ob du den lokalen KI-Assistenten nutzen willst:

```
KI-Assistent für Fragen zu Tokyo benutzen? (j/N) [N]: j
```

**Voraussetzung:** Ollama muss lokal laufen.

```bash
# Ollama installieren: https://ollama.com/download
ollama serve

# Modell herunterladen (z. B. llama3.2)
ollama pull llama3.2
```

Das Skript erkennt automatisch installierte Modelle und du kannst direkt im Terminal Fragen stellen:

```
Frage an KI: Was sollte ich in Tokyo unbedingt sehen?

KI-Antwort:
In Tokyo solltest du den Senso-ji Tempel in Asakusa, den Shibuya
Crossing und den Meiji-Schrein besuchen...
```

Mit `exit` oder `beenden` verlässt du den Chat.

> 💡 Falls Ollama nicht erreichbar ist, gibt das Skript einen Hinweis aus und fährt ohne KI fort.

---

## 🌐 Verwendete APIs

| API | Zweck | Kosten |
|---|---|---|
| [Open-Meteo Geocoding](https://open-meteo.com/) | Stadt → Land, Zeitzone, Koordinaten | Kostenlos |
| [WorldTimeAPI](http://worldtimeapi.org/) | Lokale Uhrzeit der Zielstadt | Kostenlos |
| [Open-Meteo Forecast](https://open-meteo.com/) | Temperatur, Wind, Wetterzustand | Kostenlos |
| [Frankfurter API](https://www.frankfurter.app/) | Wechselkurs Heim- → Zielwährung | Kostenlos |
| [CoinPaprika](https://coinpaprika.com/api/) | Aktuelle BTC- / ETH-Kurse | Kostenlos |
| [Ollama](https://ollama.com/) (lokal) | Optionaler KI-Reiseassistent | Kostenlos |

Alle APIs sind **kostenlos** nutzbar und benötigen **keinen API-Key**.

---

## 🔄 Programmablauf

```
1. Eingabe: Stadt & Heimwährung (mit Validierung)
2. Geocoding API → Stadt suchen
3. Stadt gefunden?
   ├─ Nein → Fehlermeldung & Abbruch
   └─ Ja   → Land, Zeitzone, Koordinaten extrahieren
4. Zielwährung anhand des Landes bestimmen
5. Parallel: 4 Datenquellen abfragen
   ├─ Lokale Uhrzeit (WorldTimeAPI)
   ├─ Wetterdaten (Open-Meteo)
   ├─ Wechselkurs (Frankfurter API)
   └─ Krypto-Kurse (CoinPaprika)
6. Daten formatieren & im Terminal ausgeben
7. Optional: KI-Assistent via Ollama starten
```

Ein detailliertes Flowchart findest du in [`docs/flowchart.drawio`](docs/flowchart.drawio).

---

## 🛡️ Fehlerbehandlung

- **Leere Eingabe** → erneute Abfrage statt Programmabbruch
- **Stadt nicht gefunden** → klare Fehlermeldung & saubere Beendigung
- **API nicht erreichbar** → automatische Wiederholung (bis zu 3 Versuche mit Backoff)
- **Ollama nicht erreichbar** → Hinweis zum Starten, Programm läuft trotzdem normal weiter
- `set -euo pipefail` sorgt für robustes Fehlerverhalten im gesamten Skript
- 
---

## 📄 Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE).
