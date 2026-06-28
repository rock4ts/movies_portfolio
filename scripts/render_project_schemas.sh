#!/bin/sh
set -eu

INPUT_ROOT="/input"
OUTPUT_DIR="/output"

echo "plantuml-render: scanning ${INPUT_ROOT} for .puml files"

echo "plantuml-render: copying non-puml static files"
find "${INPUT_ROOT}" -type f ! -name "*.puml" | while IFS= read -r src_file; do
  rel_path="${src_file#${INPUT_ROOT}/}"
  dest_file="${OUTPUT_DIR}/${rel_path}"
  dest_dir="$(dirname "${dest_file}")"
  mkdir -p "${dest_dir}"
  cp "${src_file}" "${dest_file}"
  echo "plantuml-render: copied ${rel_path}"
done

FILES="$(find "${INPUT_ROOT}" -type f -name "*.puml")"

if [ -z "${FILES}" ]; then
  echo "plantuml-render: no .puml files found under ${INPUT_ROOT}"
  echo "plantuml-render: done"
  exit 0
fi

echo "${FILES}" | while IFS= read -r puml_file; do
  rel_path="${puml_file#${INPUT_ROOT}/}"
  rel_dir="$(dirname "${rel_path}")"

  target_dir="${OUTPUT_DIR}"
  if [ "${rel_dir}" != "." ]; then
    target_dir="${OUTPUT_DIR}/${rel_dir}"
    mkdir -p "${target_dir}"
  fi

  echo "plantuml-render: rendering ${rel_path} -> ${target_dir}"
  java -jar /opt/plantuml.jar -tsvg -o "${target_dir}" "${puml_file}"
done

echo "plantuml-render: done"
