CREATE EXTENSION pg_cron;

CREATE SCHEMA IF NOT EXISTS partman;

CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;

SELECT cron.schedule(
  'partman_maintenance',
  '0 3 * * *',
  $$SELECT partman.run_maintenance();$$
);
