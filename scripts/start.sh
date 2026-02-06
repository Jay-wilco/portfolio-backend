#!/usr/bin/env bash
set -e

if [ -z "${DATABASE_URL}" ]; then
  echo "ERROR: DATABASE_URL env var is not set."
  exit 1
fi

# Normalize DB URL scheme for Drupal/Drush
DB_URL="${DATABASE_URL}"
DB_URL="${DB_URL/postgresql:\/\//pgsql:\/\/}"
DB_URL="${DB_URL/postgres:\/\//pgsql:\/\/}"

SCHEMA="${PGSCHEMA:-drupal}"
DB_URL_WITH_SCHEMA="${DB_URL}?options=--search_path%3D${SCHEMA}"

mkdir -p web/sites/default/files
chmod -R 777 web/sites/default

# Always ensure settings.php exists (Render filesystem is ephemeral)
if [ ! -f "web/sites/default/settings.php" ]; then
  echo "Creating settings.php..."
  cp web/sites/default/default.settings.php web/sites/default/settings.php

  # Append DB config + trusted host (basic)
  cat >> web/sites/default/settings.php <<EOF

\$databases['default']['default'] = [
  'driver' => 'pgsql',
  'prefix' => '',
  'host' => '',
  'port' => '',
  'namespace' => 'Drupal\\\\pgsql\\\\Driver\\\\Database\\\\pgsql',
];

EOF
fi

# Ensure Drush exists (safe if already installed)
composer require drush/drush --no-interaction || true

# Check whether Drupal tables exist (this is the key!)
TABLE_COUNT=$(vendor/bin/drush sql:query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${SCHEMA}' AND table_name='node_field_data';" --db-url="${DB_URL}" | tail -n 1 || echo "0")

if [ "${TABLE_COUNT}" = "0" ]; then
  echo "No Drupal tables found in schema '${SCHEMA}'. Installing Drupal..."
  # Need psql client for schema creation
  vendor/bin/drush sql:query "CREATE SCHEMA IF NOT EXISTS ${SCHEMA};" --db-url="${DB_URL}"

  vendor/bin/drush si standard -y \
    --db-url="${DB_URL_WITH_SCHEMA}" \
    --site-name="${DRUPAL_SITE_NAME:-Portfolio CMS}" \
    --account-name="${DRUPAL_ADMIN_USER:-admin}" \
    --account-pass="${DRUPAL_ADMIN_PASS:-ChangeMe123!}"
else
  echo "Drupal tables detected in schema '${SCHEMA}'. Skipping install."
fi

vendor/bin/drush en jsonapi -y --db-url="${DB_URL_WITH_SCHEMA}" || true
vendor/bin/drush cr -y --db-url="${DB_URL_WITH_SCHEMA}" || true

apache2-foreground
