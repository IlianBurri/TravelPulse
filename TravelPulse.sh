#!/usr/bin/env bash

# Minimal und lesbar: TravelPulse
# - Abhängigkeiten: curl, jq
# - einfache, robuste KI-Anfragen (OpenAI-kompatibel / lokale LM mit OpenAI-API-Endpunkt)

set -euo pipefail

check_deps() {
  for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Fehler: $cmd ist nicht installiert. Bitte installieren." >&2
      exit 1
    fi
  done
}

# Fragt wiederholt nach, bis eine nicht-leere Antwort kommt (ausser ein Default existiert)
prompt_required() {
  local varname="$1" prompt_text="$2" default="${3:-}"
  local answer
  while true; do
    if [ -n "$default" ]; then
      read -r -p "$prompt_text [$default]: " answer
      answer="${answer:-$default}"
    else
      read -r -p "$prompt_text: " answer
    fi
    if [ -n "$answer" ]; then
      printf -v "$varname" '%s' "$answer"
      return 0
    fi
    echo "  -> Bitte etwas eingeben."
  done
}

prompt_optional() {
  local varname="$1" prompt_text="$2" default="${3:-}"
  local answer
  read -r -p "$prompt_text [$default]: " answer
  answer="${answer:-$default}"
  printf -v "$varname" '%s' "$answer"
}

urlencode() { jq -nr --arg v "$1" '$v|@uri'; }

# Helper: robuster JSON-Fetch mit Retries
fetch_json() {
  local url="$1" try=0 max=3 resp rc
  while [ $try -lt $max ]; do
    resp=$(curl -sS --max-time 15 "$url" 2>/dev/null) || rc=$?
    if [ -n "${resp:-}" ] && printf '%s' "$resp" | jq -e . >/dev/null 2>&1; then
      printf '%s' "$resp"
      return 0
    fi
    try=$((try + 1))
    sleep "$try"
  done
  return 1
}

main() {
  check_deps

  echo "=========================================="
  echo "             TravelPulse"
  echo "=========================================="
  echo "Reise-Infos: Wetter, Zeit, Wechselkurs & Krypto"
  echo

  # 1. Reiseziel zuerst - das ist der Kern der Abfrage
  prompt_required CITY "In welche Stadt reist du?" "Zürich"

  # 2. Heimwährung danach - logisch, weil sie sich auf das Ziel bezieht
  prompt_required BASE_CURRENCY "Deine Heimwährung (z. B. CHF, EUR, USD)" "CHF"
  BASE_CURRENCY=$(echo "$BASE_CURRENCY" | tr '[:lower:]' '[:upper:]')

  echo
  echo "Suche Informationen zu \"$CITY\" ..."
  echo

  CITY_ENC=$(urlencode "$CITY")

  # Geocoding
  GEO_API="https://geocoding-api.open-meteo.com/v1/search?name=${CITY_ENC}&count=1&language=de&format=json"
  GEO_JSON=$(fetch_json "$GEO_API") || GEO_JSON=""
  LOCATION_NAME=$(echo "$GEO_JSON" | jq -r '.results[0].name // empty')
  COUNTRY=$(echo "$GEO_JSON" | jq -r '.results[0].country // empty')
  COUNTRY_CODE=$(echo "$GEO_JSON" | jq -r '.results[0].country_code // empty')
  TIMEZONE=$(echo "$GEO_JSON" | jq -r '.results[0].timezone // empty')
  LATITUDE=$(echo "$GEO_JSON" | jq -r '.results[0].latitude // empty')
  LONGITUDE=$(echo "$GEO_JSON" | jq -r '.results[0].longitude // empty')

  if [ -z "$LOCATION_NAME" ] || [ -z "$TIMEZONE" ]; then
    echo "Stadt nicht gefunden oder ungültige API-Antwort." >&2
    echo "$GEO_JSON" >&2
    exit 1
  fi

  # Zeitzone / lokale Zeit
  TIME_JSON=$(fetch_json "http://worldtimeapi.org/api/timezone/$TIMEZONE") || TIME_JSON=""
  LOCAL_TIME=$(echo "$TIME_JSON" | jq -r '.datetime // empty' 2>/dev/null || echo "")
  if [ -n "$LOCAL_TIME" ]; then
    LOCAL_TIME=$(date -d "$LOCAL_TIME" +"%d.%m.%Y %H:%M" 2>/dev/null || echo "$LOCAL_TIME")
  else
    LOCAL_TIME="Nicht verfügbar"
  fi

  # Wetter
  WEATHER_JSON=$(fetch_json "https://api.open-meteo.com/v1/forecast?latitude=$LATITUDE&longitude=$LONGITUDE&current_weather=true&timezone=$TIMEZONE") || WEATHER_JSON=""
  TEMPERATURE=$(echo "$WEATHER_JSON" | jq -r '.current_weather.temperature // empty' 2>/dev/null || echo "")
  WINDSPEED=$(echo "$WEATHER_JSON" | jq -r '.current_weather.windspeed // empty' 2>/dev/null || echo "")
  WEATHERCODE=$(echo "$WEATHER_JSON" | jq -r '.current_weather.weathercode // empty' 2>/dev/null || echo "")

  case "$WEATHERCODE" in
    0) WEATHER_TEXT="Klarer Himmel" ;;
    1) WEATHER_TEXT="Überwiegend klar" ;;
    2) WEATHER_TEXT="Teilweise bewölkt" ;;
    3) WEATHER_TEXT="Bedeckt" ;;
    *) WEATHER_TEXT="Unbekannt" ;;
  esac

  # Zielwährung grob nach Land
  case "$COUNTRY_CODE" in
    CH) TARGET_CURRENCY="CHF" ;;
    GB) TARGET_CURRENCY="GBP" ;;
    US) TARGET_CURRENCY="USD" ;;
    JP) TARGET_CURRENCY="JPY" ;;
    CA) TARGET_CURRENCY="CAD" ;;
    AU) TARGET_CURRENCY="AUD" ;;
    *) TARGET_CURRENCY="EUR" ;;
  esac

  # Wechselkurs
  FX_JSON=$(fetch_json "https://api.frankfurter.app/latest?from=$BASE_CURRENCY&to=$TARGET_CURRENCY") || FX_JSON=""
  EXCHANGE_RATE=$(echo "$FX_JSON" | jq -r ".rates.$TARGET_CURRENCY // empty" 2>/dev/null || echo "")
  EXCHANGE_RATE=${EXCHANGE_RATE:-"Nicht verfügbar"}

  # Krypto
  BTC_JSON=$(fetch_json "https://api.coinpaprika.com/v1/tickers/btc-bitcoin") || BTC_JSON=""
  BTC_PRICE=$(echo "$BTC_JSON" | jq -r '.quotes.USD.price // empty' 2>/dev/null || echo "")
  BTC_PRICE=${BTC_PRICE:-"Nicht verfügbar"}

  ETH_JSON=$(fetch_json "https://api.coinpaprika.com/v1/tickers/eth-ethereum") || ETH_JSON=""
  ETH_PRICE=$(echo "$ETH_JSON" | jq -r '.quotes.USD.price // empty' 2>/dev/null || echo "")
  ETH_PRICE=${ETH_PRICE:-"Nicht verfügbar"}

  # Ausgabe zusammenfassen
  cat <<EOF

==========================================
 TravelPulse: $LOCATION_NAME, $COUNTRY ($COUNTRY_CODE)
==========================================

[Zeit]
  Zeitzone:    $TIMEZONE
  Lokale Zeit: $LOCAL_TIME

[Standort]
  Koordinaten: $LATITUDE, $LONGITUDE

[Wetter]
  Zustand:     $WEATHER_TEXT
  Temperatur:  ${TEMPERATURE:-"-"} °C
  Wind:        ${WINDSPEED:-"-"} km/h

[Wechselkurs]
  1 $BASE_CURRENCY = $EXCHANGE_RATE $TARGET_CURRENCY

[Krypto]
  BTC: $BTC_PRICE USD
  ETH: $ETH_PRICE USD

EOF

  # KI-Assistent (optional, am Ende) - nutzt lokales Ollama
  prompt_optional USE_AI "KI-Assistent für Fragen zu $LOCATION_NAME benutzen? (j/N)" "N"
  if [[ "$USE_AI" =~ ^[jJyY]$ ]]; then
    echo
    echo "--- KI-Assistent (Ollama) ---"

    OLLAMA_URL="http://localhost:11434"

    # Prüfen ob Ollama läuft
    if ! curl -sS --max-time 3 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
      echo "Ollama ist nicht erreichbar unter $OLLAMA_URL."
      echo "Starte Ollama mit 'ollama serve' und stelle sicher, dass ein Modell installiert ist."
    else
      # Verfügbare Modelle anzeigen
      MODELS=$(curl -sS "$OLLAMA_URL/api/tags" | jq -r '.models[].name' 2>/dev/null || echo "")
      if [ -n "$MODELS" ]; then
        echo "Verfügbare Modelle:"
        echo "$MODELS" | sed 's/^/  - /'
      fi

      prompt_optional AI_MODEL "Welches Modell verwenden?" "llama3.2"

      AI_CONTEXT="Du bist ein hilfreicher Reiseassistent. Der Nutzer fragt über: $LOCATION_NAME, $COUNTRY. Antworte auf Deutsch, kurz und präzise."

      echo
      echo "Bereit. Tippe 'exit' oder 'beenden' um zu stoppen."
      echo
      while true; do
        read -r -p "Frage an KI: " USER_QUESTION
        [ -z "$USER_QUESTION" ] && continue
        if [[ "$USER_QUESTION" =~ ^(exit|beenden|quit|q)$ ]]; then
          echo "Assistent beendet."
          break
        fi

        PAYLOAD=$(jq -n --arg model "$AI_MODEL" --arg system "$AI_CONTEXT" --arg user "$USER_QUESTION" \
          '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $user}], stream: false}')

        RESP=$(curl -sS -X POST "$OLLAMA_URL/api/chat" -H "Content-Type: application/json" -d "$PAYLOAD" 2>/dev/null || true)
        TEXT=$(echo "$RESP" | jq -r '.message.content // .error // empty')

        if [ -z "$TEXT" ]; then
          echo "Keine parsebare Antwort von Ollama. Rohantwort:"
          printf '%s\n' "$RESP"
        else
          echo
          echo "KI-Antwort:"
          echo "$TEXT"
          echo
        fi
      done
    fi
  else
    echo "KI übersprungen."
  fi

  echo
  echo "Fertig. Gute Reise nach $LOCATION_NAME!"
}

main "$@"