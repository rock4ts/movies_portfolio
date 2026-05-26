#!/usr/bin/env bash

if [ ! -f /usr/share/elasticsearch/initialized ]; then
  echo 'Repository creation started'
  curl -X PUT 'http://elastic-db:9200/_snapshot/my_backup' -H 'Content-Type: application/json' -d'
  {
    "type": "fs",
    "settings": {
      "location": "/usr/share/elasticsearch/snapshots"
    }
  }'
  echo 'Repository creation completed'

  echo 'Index restoring started'
  curl -X POST 'http://elastic-db:9200/_snapshot/my_backup/snapshot/_restore' -H 'Content-Type: application/json' -d'
  {
    "indices": "movies,genres,persons",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
  echo 'Index restoring completed'
  touch /usr/share/elasticsearch/initialized
else
  echo 'Initialization already done. Starting Elasticsearch...'
fi
