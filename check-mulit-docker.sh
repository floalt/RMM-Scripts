#!/bin/bash

# description:
#   This script checks if all Docker containers defined in the specified projects are running.
#
# usage:
#   1. Place a configuration file on the server, ideally in the docker-compose folder.
#   2. Name the file 'monitoring.conf'.
#   3. List the paths to your docker-compose projects in the file.
#   4. If you want to exclude a container from the check, append ':container_name' to the project path.
#   
#   Example for 'monitoring.conf':
#   
#     /path/to/docker-compose/project_wordpress
#     /path/to/docker-compose/project_proxy:certbot
#     /path/to/docker-compose/project_development:db1,db2
#   
#   To use the script in N-Able Monitoring, simply provide the path to the 'monitoring.conf' file in the command line:
#   
#     /path/to/monitoring.conf
# 
# author: flo.alt@fa-netz.de


#!/bin/bash

# Check if the file containing the paths is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/paths.txt"
  exit 1001
fi

paths_file="$1"

# Check if the file exists
if [ ! -f "$paths_file" ]; then
  echo "ERROR: File $paths_file does not exist!"
  exit 1001
fi

errorcount=0

# Iterate through the paths in the file
while IFS= read -r line; do
  # Skip empty lines and comments (#)
  if [[ -z "$line" || "$line" == \#* ]]; then
    continue
  fi

  # Extract the folder path and excluded containers
  folder_path=$(echo "$line" | cut -d':' -f1)
  excluded_containers=$(echo "$line" | cut -d':' -f2 | tr ',' ' ')

  docker_compose_file="$folder_path/docker-compose.yml"

  # Check if docker-compose.yml exists in the folder
  if [ ! -f "$docker_compose_file" ]; then
    echo "ERROR: File $docker_compose_file does not exist in $folder_path!"
    errorcount=$((errorcount + 1))
    echo ""
    continue
  fi

  # Extract the project name (last part of the folder path)
  project_name=$(basename "$folder_path")

  echo "Checking Project /$project_name"

  # Extract the list of containers from docker-compose.yml
  containers=$(awk '/services:/ {flag=1; next} /^[^ ]/ {flag=0} flag && /^  [a-zA-Z0-9_-]+:/ {print $1}' "$docker_compose_file" | sed 's/://')

  if [ -z "$containers" ]; then
    echo "ERROR: No containers found in $docker_compose_file"
    errorcount=$((errorcount + 1))
    echo ""
    continue
  fi

  # Check each container
  for container in $containers; do
    # Skip excluded containers
    if [[ " $excluded_containers " == *" $container "* ]]; then
      echo "SKIP: Container $container is excluded from the check"
      continue
    fi

    container_id=$(docker compose -f "$docker_compose_file" ps -q "$container" 2>/dev/null)

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

  # Add an empty line after each project
  echo ""

done < "$paths_file"

# Print the final result
if [ "$errorcount" -eq 0 ]; then
  echo "Yeah, looks fantastic, everything is running!"
  exit 0
else
  echo "Oh what a mess! Total errors: $errorcount"
  exit 1001
fi