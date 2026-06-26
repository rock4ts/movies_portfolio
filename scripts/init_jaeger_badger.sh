#!/bin/sh
set -eu

BADGER_ROOT="/badger"
KEY_DIR="${BADGER_ROOT}/key"
DATA_DIR="${BADGER_ROOT}/data"

echo "jaeger-init: preparing Badger storage at ${BADGER_ROOT}"

created_any=0

for dir in "${KEY_DIR}" "${DATA_DIR}"; do
  if [ -d "${dir}" ]; then
    echo "jaeger-init: '${dir}' already exists, skipping"
  else
    mkdir -p "${dir}"
    echo "jaeger-init: created '${dir}'"
    created_any=1
  fi
done

chmod -R 777 "${BADGER_ROOT}"
echo "jaeger-init: permissions ensured on ${BADGER_ROOT}"

if [ "${created_any}" -eq 1 ]; then
  echo "jaeger-init: final layout:"
  ls -laR "${BADGER_ROOT}"
fi

echo "jaeger-init: done"
