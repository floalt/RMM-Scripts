#!/bin/bash

# description:
#   This script checks if all Docker containers defined in the specified docker-compose.yml are running.
#
# usage:
#   ./check-docker.sh /path/to/docker-compose.yml
#   
#   To use the script in N-Able Monitoring, simply provide the path to the 'docker-compose.yml' file in the command line:
#   
#     /path/to/docker-compose.yml
# 
# author: flo.alt@fa-netz.de


# Überprüfen, ob der Pfad zu docker-compose.yml als Parameter übergeben wurde
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/docker-compose.yml"
  exit 1001
fi

docker_compose_file="$1"

# Überprüfen, ob die Datei existiert
if [ ! -f "$docker_compose_file" ]; then
  echo "ERROR: File $docker_compose_file does not exist!"
  exit 1001
fi

# Liste der Container aus der docker-compose.yml extrahieren
containers=$(awk '/services:/ {flag=1; next} /^[^ ]/ {flag=0} flag && /^  [a-zA-Z0-9_-]+:/ {print $1}' "$docker_compose_file" | sed 's/://')

if [ -z "$containers" ]; then
  echo "ERROR: No containers found in $docker_compose_file"
  exit 1001
fi

errorcount=0

# Container überprüfen
for container in $containers; do
  container_id=$(docker compose ps -q "$container" 2>/dev/null)    # hier muss noch das compose file angegeben werden!!!

  if [ -z "$container_id" ]; then
    echo "FAIL: Container $container is not running"
    errorcount=$((errorcount + 1))
  else
    state=$(docker inspect "$container_id" --format='{{.State.Status}}' 2>/dev/null)

    if [ "$state" == "running" ]; then
      echo "OK: Container $container is running"
    else
      echo "FAIL: Container $container is $state"
      errorcount=$((errorcount + 1))
    fi
  fi
done

# Ergebnis ausgeben
if [ "$errorcount" -eq 0 ]; then
  echo "Yeah, looks fantastic, everything is running"
  exit 0
else
  echo "Oh what a mess!"
  exit 1001
fi