#!/bin/bash
# Ghost Multi-Tenant Deployment Script
# Brings up infrastructure and all Ghost sites

set -e

echo "🚀 Ghost Multi-Tenant Deployment"
echo "================================"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "   Please copy .env.example to .env and configure your settings"
    exit 1
fi

# Load environment variables
source .env

echo "✅ Environment loaded"

# Check if Docker and Docker Compose are available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found! Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose not found! Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose available"

# Start infrastructure services
echo ""
echo "📦 Starting infrastructure services..."
docker compose up -d

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
timeout=60
counter=0
while ! docker compose exec mysql mysqladmin ping -h localhost --silent 2>/dev/null; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -eq $timeout ]; then
        echo "❌ MySQL failed to start within ${timeout} seconds"
        exit 1
    fi
done

echo "✅ MySQL is ready"

# Setup Tinybird Local if not already configured
if [ -z "$TINYBIRD_ADMIN_TOKEN" ] || [ "$TINYBIRD_ADMIN_TOKEN" = "your_tinybird_admin_token_here" ]; then
    echo ""
    echo "🐦 Setting up Tinybird Local for analytics..."
    ./scripts/setup-tinybird.sh
    
    # Reload environment after Tinybird setup
    source .env
else
    echo "✅ Tinybird already configured, starting services..."
    docker compose up -d tinybird-local traffic-analytics
fi

# Find all Ghost site compose files
SITE_FILES=$(find . -name "docker-compose.*.yml" -not -name "docker-compose.yml" -not -name "docker-compose.override.yml" 2>/dev/null || true)

if [ -z "$SITE_FILES" ]; then
    echo ""
    echo "⚠️  No Ghost site files found!"
    echo "   Create Ghost site files like: docker-compose.yoursite.yml"
    echo "   Use the template: templates/docker-compose.site.template.yml"
    echo ""
    echo "🏗️  Infrastructure is ready. Add your sites and run this script again."
    exit 0
fi

# Count sites
SITE_COUNT=$(echo "$SITE_FILES" | wc -l)
echo ""
echo "🏠 Found $SITE_COUNT Ghost site(s):"
echo "$SITE_FILES" | sed 's|./docker-compose.||' | sed 's|.yml||' | sed 's/^/   - /'

# Start Ghost sites
echo ""
echo "🚀 Starting Ghost sites..."

# Build compose command with all site files
COMPOSE_CMD="docker compose -f docker-compose.yml"
for file in $SITE_FILES; do
    COMPOSE_CMD="$COMPOSE_CMD -f $file"
done

# Execute the compose command
eval "$COMPOSE_CMD up -d"

echo ""
echo "⏳ Waiting for Ghost sites to be ready..."
sleep 10

# Check site health
echo ""
echo "🏥 Checking site health..."

for file in $SITE_FILES; do
    site_name=$(basename "$file" .yml | sed 's/docker-compose\.//')
    service_name="ghost_$(echo "$site_name" | sed 's/\./_/g' | sed 's/-/_/g')"
    
    if docker compose ps "$service_name" | grep -q "Up"; then
        echo "   ✅ $site_name is running"
    else
        echo "   ❌ $site_name failed to start"
    fi
done

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 Service status:"
docker compose ps

echo ""
echo "🌐 Next steps:"
echo "   1. ⚠️  IMPORTANT: Configure DNS records for each domain:"
for file in $SITE_FILES; do
    # Extract domain from filename
    domain=$(basename "$file" .yml | sed 's/docker-compose\.//' | sed 's/_/\./g' | sed 's/-/\./g')
    if [[ "$domain" != *"."* ]]; then
        domain=$(basename "$file" .yml | sed 's/docker-compose\.//')
        # Try to extract domain from compose file
        domain=$(grep -E "^\s*url:\s*https://" "$file" | head -1 | sed 's/.*https:\/\///' | tr -d '"' || echo "$domain")
    fi
    echo "      $domain IN A YOUR.SERVER.IP.ADDRESS"
done
echo ""
echo "   2. Wait for DNS propagation (may take 5-60 minutes)"
echo "   3. Access your Ghost admin at: https://yourdomain.com/ghost/"
echo "   4. View logs with: docker compose logs -f [service_name]"
echo "   5. Monitor with: docker compose ps"
echo ""
echo "📖 View the full documentation in README.md"