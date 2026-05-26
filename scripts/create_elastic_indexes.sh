#!/bin/sh
set -eu

INDEX_DIR="/data/indexes"
ELASTIC_URL="http://elastic-db:9200"

found_any=0

for file in "${INDEX_DIR}"/*.json; do
  if [ ! -e "${file}" ]; then
    continue
  fi

  found_any=1
  index_name="$(basename "${file}" .json)"

  echo "Processing index '${index_name}'"

  # --- 1. Check if index exists (explicit HTTP status)
  status=$(curl -s -o /dev/null -w "%{http_code}" "${ELASTIC_URL}/${index_name}")

  if [ "$status" = "200" ]; then
    echo "Index '${index_name}' already exists, skipping"
    continue
  elif [ "$status" != "404" ]; then
    echo "Error checking index '${index_name}', HTTP status: $status"
    exit 1
  fi

  # --- 2. Create index
  echo "Creating index '${index_name}' from ${file}"

  response=$(curl -s -X PUT "${ELASTIC_URL}/${index_name}" \
    -H "Content-Type: application/json" \
    --data-binary @"${file}")

  # --- 3. Validate creation response
  echo "$response" | grep -q '"acknowledged":true' || {
    echo "Failed to create index '${index_name}'"
    echo "Response: $response"
    exit 1
  }

  # --- 4. Double-check existence after creation
  status=$(curl -s -o /dev/null -w "%{http_code}" "${ELASTIC_URL}/${index_name}")

  if [ "$status" != "200" ]; then
    echo "Index '${index_name}' still does not exist after creation"
    exit 1
  fi

  echo "Index '${index_name}' created successfully"
done

if [ "${found_any}" -eq 0 ]; then
  echo "No index json files found in ${INDEX_DIR}"
  exit 1
fi

echo "All indexes are ready"