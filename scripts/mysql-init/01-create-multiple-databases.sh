#!/bin/bash
# MySQL Database Creation Script for Ghost Multi-Tenant Setup
# Automatically creates databases and users for running Ghost sites

set -e

echo "Starting database initialization..."

# Function to create database and user
create_database_and_user() {
    local db_name="$1"
    local user_name="$2"
    local user_password="${3:-$MYSQL_PASSWORD}"
    
    echo "Creating database: $db_name with user: $user_name"
    
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`$db_name\` 
        CHARACTER SET utf8mb4 
        COLLATE utf8mb4_unicode_ci;
        
        CREATE USER IF NOT EXISTS '$user_name'@'%' IDENTIFIED BY '$user_password';
        GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$user_name'@'%';
        FLUSH PRIVILEGES;
EOSQL
}

# Create ActivityPub database (always needed for federation)
echo "Creating ActivityPub database..."
create_database_and_user "activitypub_db" "root"

# Discover Ghost sites from running containers and create databases
echo "Discovering Ghost sites from Docker containers..."

# Check if Docker socket is available
if [ -S /var/run/docker.sock ]; then
    # Get list of Ghost containers with labels
    GHOST_CONTAINERS=$(docker ps --format "{{.Names}}" --filter "label=ghost.service" 2>/dev/null || true)
    
    for container in $GHOST_CONTAINERS; do
        # Extract database info from container labels
        SERVICE_NAME=$(docker inspect "$container" --format '{{index .Config.Labels "ghost.service"}}' 2>/dev/null || echo "")
        
        if [ -n "$SERVICE_NAME" ]; then
            DB_NAME="${SERVICE_NAME}_db"
            USER_NAME="$SERVICE_NAME"
            
            echo "Found Ghost container: $container (service: $SERVICE_NAME)"
            create_database_and_user "$DB_NAME" "$USER_NAME"
        fi
    done
    
    if [ -z "$GHOST_CONTAINERS" ]; then
        echo "No Ghost containers found. Databases will be created when Ghost sites start."
    fi
else
    echo "Docker socket not available. Creating example database."
    create_database_and_user "example_com_db" "example_com"
fi

echo "Database initialization completed!"

# List created databases
echo "Available databases:"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -E "(activitypub|_db)" || echo "No Ghost databases found yet."