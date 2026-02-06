#!/usr/bin/env bash
set -e

if [ -z "${DATABASE_URL}" ]; then
  echo "ERROR: DATABASE_URL env var is not set."
  exit 1
fi

mkdir -p web/sites/default/files
chmod -R 777 web/sites/default

# Normalize DB URL scheme for Drupal/Drush
DB_URL="${DATABASE_URL}"
DB_URL="${DB_URL/postgresql:\/\//pgsql:\/\/}"
DB_URL="${DB_URL/postgres:\/\//pgsql:\/\/}"

# Use a dedicated schema inside the shared database to avoid table collisions
SCHEMA="${PGSCHEMA:-drupal}"
DB_URL_WITH_SCHEMA="${DB_URL}?options=--search_path%3D${SCHEMA}"

# Install Drupal if not installed yet
if [ ! -f "web/sites/default/settings.php" ] || ! vendor/bin/drush status --field=bootstrap --db-url="${DB_URL_WITH_SCHEMA}" 2>/dev/null | grep -q "Successful"; then

  echo "Installing Drupal (fresh) into schema '${SCHEMA}'..."

  # Ensure Drush exists
  composer require drush/drush --no-interaction

  # Create schema if it doesn't exist
  vendor/bin/drush sql:query "CREATE SCHEMA IF NOT EXISTS ${SCHEMA};" --db-url="${DB_URL}"

  vendor/bin/drush si standard -y \
    --db-url="${DB_URL_WITH_SCHEMA}" \
    --site-name="${DRUPAL_SITE_NAME:-Portfolio CMS}" \
    --account-name="${DRUPAL_ADMIN_USER:-admin}" \
    --account-pass="${DRUPAL_ADMIN_PASS:-ChangeMe123!}"
else
  echo "Drupal already installed."
fi

# Ensure JSON:API is enabled
vendor/bin/drush en jsonapi -y || true

apache2-foreground
