#!/usr/bin/env bash
set -euo pipefail

JAR="target/minisrv-1.0-SNAPSHOT.jar"
URL="http://127.0.0.1:8080/io"
REQ=3000
CONC=200
SAMPLE_INTERVAL=0.5   # sekundi

# Izvuci p95 iz ApacheBench outputa
p95() {
  awk '/95%/{print $2}' "$1" | tr -d '\r'
}

# Vrati RSS memoriju (MB) za dati PID, fallback 0
rss_mb() {
  powershell.exe -NoProfile -Command \
    "try {
       \$p = Get-Process -Id $1;
       [int](\$p.WorkingSet64 / 1MB)
     } catch {
       Write-Output 0
     }" | tr -d '\r'
}

# Dohvati točno jedan PID koji sluša na portu 8080 (LISTEN)
server_pid() {
  powershell.exe -NoProfile -Command \
    "(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction Stop |
      Select-Object -First 1 -ExpandProperty OwningProcess)" | tr -d '\r'
}

# Pokreni benchmark za zadani MODE
run() {
  local MODE=$1
  local FLAG=$2
  echo -e "\n▶ $MODE"

  # 1) start server
  java $FLAG -jar "$JAR" > /dev/null 2>&1 &
  sleep 3

  # 2) dohvati PID
  PID=$(server_pid)
  if [[ -z "$PID" ]]; then
    echo "❌ Ne mogu naći proces na portu 8080"
    exit 1
  fi

  # 3) mjerenje baseline (prije opterećenja)
  BASE=$(rss_mb "$PID")

  # 4) počni sampling loop u pozadini
  PEAK=$BASE
  (
    while kill -0 $PID 2>/dev/null; do
      m=$(rss_mb "$PID")
      (( m > PEAK )) && PEAK=$m
      sleep $SAMPLE_INTERVAL
    done
    # kad server stane, echo-aj peak u datoteku
    echo $PEAK > peak-"$MODE".txt
  ) &

  # 5) pokreni load test
  ab -n $REQ -c $CONC "$URL" > "ab-$MODE.out"
  LAT=$(p95 "ab-$MODE.out")

  # 6) kill server
  taskkill /PID $PID /F > /dev/null 2>&1 || true

  # 7) pričekaj da sampling loop završi i pročitaj peak
  wait
  PEAK=$(<peak-"$MODE".txt)

  # 8) spremi rezultate
  echo "$MODE,baseline=$BASE,peak=$PEAK,latency=$LAT" >> results.csv
  echo "  p95=$LAT ms, RSS baseline=${BASE} MB, peak=${PEAK} MB"
}

# --- glavni tok ---
if [[ ! -f $JAR ]]; then
  echo "❌ JAR nije pronađen – pokreni: mvn clean package"
  exit 1
fi

rm -f results.csv peak-*.txt

run classic ""
run virtual "-Dvt=true"

echo -e "\n📊 results.csv:"
column -s, -t < results.csv
