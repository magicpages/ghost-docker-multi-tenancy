#!/bin/bash
# Create a new Ghost site from template
# Usage: ./scripts/new-site.sh yourdomain.com

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 myblog.com"
    exit 1
fi

DOMAIN="$1"

# Validate domain format (allows subdomains)
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid domain format: $DOMAIN"
    echo "   Please use format: example.com or subdomain.example.com"
    exit 1
fi

# Generate service name (replace dots and dashes with underscores)
SERVICE_NAME=$(echo "$DOMAIN" | sed 's/\./_/g' | sed 's/-/_/g')
COMPOSE_FILE="docker-compose.${DOMAIN}.yml"

echo "🌟 Creating new Ghost site"
echo "=========================="
echo "Domain: $DOMAIN"
echo "Service name: $SERVICE_NAME"
echo "Compose file: $COMPOSE_FILE"

# Check if compose file already exists
if [ -f "$COMPOSE_FILE" ]; then
    echo "❌ Site already exists: $COMPOSE_FILE"
    exit 1
fi

# Check if template exists
TEMPLATE_FILE="templates/docker-compose.site.template.yml"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Create compose file from template
echo "📝 Creating compose file from template..."
cp "$TEMPLATE_FILE" "$COMPOSE_FILE"

# Replace placeholders in the compose file
sed -i "s/DOMAIN/$DOMAIN/g" "$COMPOSE_FILE"
sed -i "s/SITENAME/$SERVICE_NAME/g" "$COMPOSE_FILE"

echo "✅ Created $COMPOSE_FILE"

# Add to Caddyfile if not already present
echo "📝 Updating Caddyfile..."
if ! grep -q "$DOMAIN" Caddyfile; then
    cat >> Caddyfile << EOF

# Auto-generated: $DOMAIN
$DOMAIN {
    reverse_proxy ghost_${SERVICE_NAME}:2368
    
    handle /.well-known/webfinger {
        reverse_proxy activitypub:3000
    }
    
    handle /activitypub/* {
        reverse_proxy activitypub:3000
    }
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# www redirect for $DOMAIN (uncomment and choose ONE option):
# Option 1: www -> non-www redirect (recommended)
# www.$DOMAIN {
#     redir https://$DOMAIN{uri} permanent
# }

# Option 2: non-www -> www redirect
# $DOMAIN {
#     redir https://www.$DOMAIN{uri} permanent
# }
EOF
    echo "✅ Added $DOMAIN to Caddyfile"
    echo "💡 www redirect options added (commented out - uncomment if needed)"
else
    echo "⚠️  $DOMAIN already exists in Caddyfile"
fi

echo ""
echo "🎉 New site created successfully!"
echo ""
echo "⚠️  IMPORTANT: Set up DNS first!"
echo "   Add these DNS records:"
echo "   $DOMAIN IN A YOUR.SERVER.IP.ADDRESS"
echo "   www.$DOMAIN IN A YOUR.SERVER.IP.ADDRESS (optional)"
echo ""
echo "Next steps:"
echo "1. Set up DNS records (required for SSL certificates)"
echo "2. Optional: Enable www redirect by uncommenting in Caddyfile"
echo "3. Deploy the site:"
echo "   docker compose -f docker-compose.yml -f $COMPOSE_FILE up -d"
echo ""
echo "4. Or deploy all sites:"
echo "   ./scripts/deploy.sh"
echo ""
echo "5. Access your site at: https://$DOMAIN"
echo "6. Access Ghost admin at: https://$DOMAIN/ghost/"
echo ""
echo "📖 The site will automatically get:"
echo "   - SSL certificate from Let's Encrypt"
echo "   - MySQL database: ${SERVICE_NAME}_db"
echo "   - ActivityPub federation"
echo "   - Tinybird Local analytics"
echo ""
echo "🔧 Make sure to run the setup first if you haven't:"
echo "   ./scripts/setup-tinybird.sh"