#!/bin/bash
# Generate Ghost sites from GHOST_SITES environment variable
# Usage: ./scripts/generate-sites.sh

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
fi

if [ -z "$GHOST_SITES" ]; then
    echo "ERROR: GHOST_SITES environment variable not set"
    echo "Example: GHOST_SITES='site1.example.com,site2.example.com,site3.example.com'"
    exit 1
fi

echo "Generating Ghost sites from: $GHOST_SITES"

# Create sites compose file
cat > docker-compose.sites.yml << 'EOF'
version: '3.8'

# Auto-generated Ghost sites
# Generated from GHOST_SITES environment variable

services:
EOF

# Convert comma-separated sites to array
IFS=',' read -ra SITES <<< "$GHOST_SITES"

for site in "${SITES[@]}"; do
    # Clean whitespace
    site=$(echo "$site" | xargs)
    
    if [ -n "$site" ]; then
        # Extract domain name as service name (remove dots, dashes become underscores)
        service_name=$(echo "$site" | sed 's/\./_/g' | sed 's/-/_/g')
        db_name="${service_name}_db"
        
        echo "  # Ghost site: $site"
        
        cat >> docker-compose.sites.yml << EOF

  ghost_${service_name}:
    image: ghost:6-alpine
    restart: unless-stopped
    environment:
      NODE_ENV: production
      url: https://${site}
      
      # Database configuration
      database__client: mysql
      database__connection__host: mysql
      database__connection__user: ${service_name}
      database__connection__password: \${MYSQL_PASSWORD}
      database__connection__database: ${db_name}
      
      # ActivityPub integration
      activitypub__enabled: true
      activitypub__endpoint: http://activitypub:3000
      
      # Tinybird analytics
      analytics__enabled: true
      analytics__tinybird__endpoint: http://tinybird:8123
      analytics__tinybird__token: \${TINYBIRD_TOKEN}
      analytics__tinybird__site: ${service_name}
      
      # Email configuration (if provided)
      mail__transport: \${MAIL_TRANSPORT:-}
      mail__options__host: \${MAIL_HOST:-}
      mail__options__port: \${MAIL_PORT:-}
      mail__options__secure: \${MAIL_SECURE:-}
      mail__options__auth__user: \${MAIL_USER:-}
      mail__options__auth__pass: \${MAIL_PASSWORD:-}
      
    volumes:
      - ghost_${service_name}_content:/var/lib/ghost/content
    networks:
      - ghost_network
    depends_on:
      mysql:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:2368/ghost/api/admin/site/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    labels:
      - "ghost.site=${site}"
      - "ghost.service=${service_name}"
EOF
    fi
done

# Add volumes section
echo "" >> docker-compose.sites.yml
echo "volumes:" >> docker-compose.sites.yml

for site in "${SITES[@]}"; do
    site=$(echo "$site" | xargs)
    if [ -n "$site" ]; then
        service_name=$(echo "$site" | sed 's/\./_/g' | sed 's/-/_/g')
        echo "  ghost_${service_name}_content:" >> docker-compose.sites.yml
    fi
done

# Add networks section
cat >> docker-compose.sites.yml << 'EOF'

networks:
  ghost_network:
    external: true
    name: ghost-docker-multitenancy_ghost_network
EOF

echo "Generated docker-compose.sites.yml with $(echo "$GHOST_SITES" | tr ',' '\n' | wc -l) sites"
echo ""
echo "Sites configured:"
for site in "${SITES[@]}"; do
    site=$(echo "$site" | xargs)
    if [ -n "$site" ]; then
        echo "  - $site"
    fi
done
echo ""
echo "Next steps:"
echo "1. Start infrastructure: docker compose up -d"
echo "2. Start Ghost sites: docker compose -f docker-compose.yml -f docker-compose.sites.yml up -d"