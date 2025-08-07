#!/bin/bash
# Setup Tinybird Local for Ghost Multi-Tenant Analytics
# Initializes Tinybird schema and generates tokens

set -e

echo "🐦 Setting up Tinybird Local for Ghost analytics..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "   Please copy .env.example to .env and configure your settings"
    exit 1
fi

# Load environment variables
source .env

# Ensure Tinybird Local is running
echo "📦 Starting Tinybird Local..."
docker compose up -d tinybird-local

# Wait for Tinybird to be ready
echo "⏳ Waiting for Tinybird Local to be ready..."
timeout=60
counter=0
while ! curl -s http://localhost:${TINYBIRD_PORT:-7181}/tokens > /dev/null 2>&1; do
    sleep 2
    counter=$((counter + 2))
    if [ $counter -eq $timeout ]; then
        echo "❌ Tinybird Local failed to start within ${timeout} seconds"
        echo "   Check logs with: docker compose logs tinybird-local"
        exit 1
    fi
done

echo "✅ Tinybird Local is ready"

# Get or generate admin token
if [ -z "$TINYBIRD_ADMIN_TOKEN" ] || [ "$TINYBIRD_ADMIN_TOKEN" = "your_tinybird_admin_token_here" ]; then
    echo "🔑 Generating Tinybird admin token..."
    ADMIN_TOKEN=$(curl -s http://localhost:${TINYBIRD_PORT:-7181}/tokens | jq -r ".workspace_admin_token")
    
    # Update .env file
    if grep -q "^TINYBIRD_ADMIN_TOKEN=" .env; then
        sed -i "s/^TINYBIRD_ADMIN_TOKEN=.*/TINYBIRD_ADMIN_TOKEN=$ADMIN_TOKEN/" .env
    else
        echo "TINYBIRD_ADMIN_TOKEN=$ADMIN_TOKEN" >> .env
    fi
    
    export TINYBIRD_ADMIN_TOKEN=$ADMIN_TOKEN
    echo "✅ Admin token generated and saved to .env"
else
    ADMIN_TOKEN=$TINYBIRD_ADMIN_TOKEN
    echo "✅ Using existing admin token from .env"
fi

# Generate tracker token if not exists
if [ -z "$TINYBIRD_TRACKER_TOKEN" ] || [ "$TINYBIRD_TRACKER_TOKEN" = "your_tinybird_tracker_token_here" ]; then
    echo "🔑 Generating tracker token..."
    
    # Create a tracker token with limited permissions
    TRACKER_TOKEN=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -d '{"name":"traffic-analytics","scopes":[{"resource":"events","action":"append"}]}' \
        http://localhost:${TINYBIRD_PORT:-7181}/tokens | jq -r ".token")
    
    # Update .env file
    if grep -q "^TINYBIRD_TRACKER_TOKEN=" .env; then
        sed -i "s/^TINYBIRD_TRACKER_TOKEN=.*/TINYBIRD_TRACKER_TOKEN=$TRACKER_TOKEN/" .env
    else
        echo "TINYBIRD_TRACKER_TOKEN=$TRACKER_TOKEN" >> .env
    fi
    
    export TINYBIRD_TRACKER_TOKEN=$TRACKER_TOKEN
    echo "✅ Tracker token generated and saved to .env"
else
    echo "✅ Using existing tracker token from .env"
fi

# Deploy Ghost's Tinybird schema
echo "📊 Deploying Ghost's Tinybird schema..."
docker compose -f docker-compose.setup.yml run --rm tinybird-sync
docker compose -f docker-compose.setup.yml run --rm tinybird-deploy

echo "📦 Starting Traffic Analytics service..."
docker compose up -d traffic-analytics

echo ""
echo "🎉 Tinybird Local setup complete!"
echo ""
echo "📊 Analytics endpoints:"
echo "   Tinybird Local: http://localhost:${TINYBIRD_PORT:-7181}"
echo "   Traffic Analytics: http://localhost:${TRAFFIC_ANALYTICS_PORT:-3001}"
echo ""
echo "🔧 Ghost sites will automatically use these settings:"
echo "   tinybird__adminToken: $ADMIN_TOKEN"
echo "   tinybird__workspaceId: default"
echo "   tinybird__stats__endpoint: http://tinybird-local:7181"
echo ""
echo "🚀 Your Ghost sites are now ready for analytics!"