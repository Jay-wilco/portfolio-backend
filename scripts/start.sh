#!/usr/bin/env bash
set -e

if [ -z "${DATABASE_URL}" ]; then
  echo "ERROR: DATABASE_URL env var is not set."
  exit 1
fi

mkdir -p web/sites/default/files
chmod -R 777 web/sites/default

# Install Drupal if not installed yet
if [ ! -f "web/sites/default/settings.php" ]; then
  echo "Installing Drupal (fresh)..."

  # Ensure Drush exists
  composer require drush/drush --no-interaction

  vendor/bin/drush si standard -y \
    --db-url="${DATABASE_URL}" \
    --site-name="${DRUPAL_SITE_NAME:-Portfolio CMS}" \
    --account-name="${DRUPAL_ADMIN_USER:-admin}" \
    --account-pass="${DRUPAL_ADMIN_PASS:-ChangeMe123!}"
else
  echo "Drupal already installed."
fi

# Ensure JSON:API is enabled
vendor/bin/drush en jsonapi -y || true

apache2-foreground
