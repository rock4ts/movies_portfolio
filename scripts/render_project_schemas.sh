#!/bin/sh
set -eu

INPUT_ROOT="/input"
OUTPUT_DIR="/output"
SHARED_INDEX="${INPUT_ROOT}/index.html"
SHARED_README="${INPUT_ROOT}/readme.html"

echo "plantuml-render: scanning ${INPUT_ROOT} for .puml files"

if [ ! -f "${SHARED_INDEX}" ]; then
  echo "plantuml-render: missing shared index at ${SHARED_INDEX}" >&2
  exit 1
fi

if [ ! -f "${SHARED_README}" ]; then
  echo "plantuml-render: missing shared readme viewer at ${SHARED_README}" >&2
  exit 1
fi

echo "plantuml-render: copying non-puml static files"
find "${INPUT_ROOT}" -type f ! -name "*.puml" ! -name "index.html" ! -name "readme.html" | while IFS= read -r src_file; do
  rel_path="${src_file#${INPUT_ROOT}/}"
  dest_file="${OUTPUT_DIR}/${rel_path}"
  dest_dir="$(dirname "${dest_file}")"
  mkdir -p "${dest_dir}"
  cp "${src_file}" "${dest_file}"
  echo "plantuml-render: copied ${rel_path}"
done

echo "plantuml-render: installing shared HTML into stage directories"
find "${INPUT_ROOT}" -mindepth 1 -type d | while IFS= read -r stage_dir; do
  if [ -z "$(find "${stage_dir}" -maxdepth 1 -type f ! -name "index.html" ! -name "readme.html" | head -n 1)" ]; then
    continue
  fi

  rel_dir="${stage_dir#${INPUT_ROOT}/}"
  dest_dir="${OUTPUT_DIR}/${rel_dir}"
  mkdir -p "${dest_dir}"
  cp "${SHARED_INDEX}" "${dest_dir}/index.html"
  cp "${SHARED_README}" "${dest_dir}/readme.html"
  echo "plantuml-render: installed index.html, readme.html -> ${rel_dir}/"
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
