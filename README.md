# Ghost Docker Multi-Tenancy

A simplified Docker-based multi-tenant Ghost setup that maximizes resource efficiency by sharing infrastructure services (MySQL, ActivityPub, Tinybird) while keeping each Ghost site isolated.

**Based on the official [TryGhost/ghost-docker](https://github.com/tryghost/ghost-docker) repository by the Ghost Foundation team, extended with multi-tenancy capabilities.**

## Architecture

- **One shared infrastructure definition**: MySQL, Caddy, ActivityPub, Tinybird Local
- **One compose file per Ghost site**: `docker-compose.yoursite.yml`  
- **Automatic SSL**: Caddy handles Let's Encrypt certificates
- **Docker-native**: No filesystem dependencies, pure container approach

## Quick Start

1. **Clone and configure**:
   ```bash
   git clone https://github.com/magicpages/ghost-docker-multi-tenancy.git
   cd ghost-docker-multi-tenancy
   cp .env.example .env
   # Edit .env with your settings
   ```

2. **Set up DNS records**:
   Point your domains to your server's IP address:
   ```bash
   # For each domain you want to use:
   # Create an A record pointing to your server IP
   myblog.com      IN  A   YOUR.SERVER.IP.ADDRESS
   anotherblog.com IN  A   YOUR.SERVER.IP.ADDRESS
   
   # Optional: Add www subdomain (if you want www support)
   www.myblog.com      IN  A   YOUR.SERVER.IP.ADDRESS
   www.anotherblog.com IN  A   YOUR.SERVER.IP.ADDRESS
   # OR use CNAME: www.myblog.com IN CNAME myblog.com
   ```

3. **Create your first site**:
   ```bash
   ./scripts/new-site.sh myblog.com
   ```

4. **Deploy everything**:
   ```bash
   ./scripts/deploy.sh
   ```

5. **Access your site**:
   - Site: `https://myblog.com`
   - Admin: `https://myblog.com/ghost/`

## Adding More Sites

1. **Set up DNS for the new domain**:
   ```bash
   # Add A record for the new domain
   anotherblog.com      IN  A   YOUR.SERVER.IP.ADDRESS
   # Optional: Add www subdomain
   www.anotherblog.com  IN  A   YOUR.SERVER.IP.ADDRESS
   ```

2. **Create and deploy the new site**:
   ```bash
   ./scripts/new-site.sh anotherblog.com
   ./scripts/new-site.sh yetanother.org
   ./scripts/deploy.sh
   ```

Each site gets:
- ✅ Automatic SSL certificate
- ✅ Dedicated MySQL database  
- ✅ ActivityPub federation
- ✅ Tinybird Local analytics
- ✅ Isolated content storage


## Manual Site Creation

If you prefer to create sites manually:

1. **Copy the template**:
   ```bash
   cp templates/docker-compose.site.template.yml docker-compose.yoursite.yml
   ```

2. **Edit the file**: Replace `DOMAIN` and `SITENAME` placeholders

3. **Add to Caddyfile**: Add your domain configuration

4. **Deploy**:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.yoursite.yml up -d
   ```

## Environment Configuration

Configure these in `.env`:

```bash
# Database
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_PASSWORD=your_ghost_password

# Tinybird Local Analytics (auto-generated during setup)
TINYBIRD_ADMIN_TOKEN=your_tinybird_admin_token
TINYBIRD_TRACKER_TOKEN=your_tinybird_tracker_token
TINYBIRD_PORT=7181
TRAFFIC_ANALYTICS_PORT=3001

# Email (optional)
MAIL_TRANSPORT=SMTP
MAIL_HOST=smtp.mailgun.org
MAIL_USER=postmaster@mg.yourdomain.com
MAIL_PASSWORD=your_password
```

## Management Commands

```bash
# Deploy infrastructure and all sites (creates databases automatically)
./scripts/deploy.sh

# Setup Tinybird Local (called automatically by deploy.sh)
./scripts/setup-tinybird.sh

# Create new site configuration
./scripts/new-site.sh newdomain.com

# View all services
docker compose ps

# View logs for specific site
docker compose logs ghost_myblog_com

# View analytics logs
docker compose logs traffic-analytics
docker compose logs tinybird-local

# Restart specific site  
docker compose restart ghost_myblog_com

# Remove site (stop container, keep data)
docker compose stop ghost_myblog_com
```

## Backup Strategy

All data is stored in Docker volumes:

```bash
# Backup MySQL data
docker run --rm -v ghost-docker-multitenancy_mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql-backup.tar.gz /data

# Backup specific site content  
docker run --rm -v ghost_myblog_com_content:/data -v $(pwd):/backup alpine tar czf /backup/myblog-content.tar.gz /data

# Backup Caddy certificates
docker run --rm -v ghost-docker-multitenancy_caddy_data:/data -v $(pwd):/backup alpine tar czf /backup/caddy-certs.tar.gz /data
```

## Scaling and Performance

- **Resource limits**: Each Ghost site limited to 512MB RAM
- **Shared MySQL**: Single instance handles all sites efficiently  
- **Caddy caching**: Automatic static asset caching
- **Health checks**: Automatic container recovery
- **Multi-tenant services**: ActivityPub and Tinybird Local serve all sites

## Security Features

- **Automatic HTTPS**: Let's Encrypt SSL for all domains
- **Security headers**: HSTS, anti-clickjacking, XSS protection
- **Database isolation**: Each site has separate database and user
- **Container isolation**: Sites can't access each other's data
- **Regular updates**: Use official Ghost and MySQL images

## Troubleshooting

**Site won't start?**
```bash
docker compose logs ghost_yoursite_com
```

**Database issues?**
```bash
docker compose exec mysql mysql -u root -p -e "SHOW DATABASES;"
```

**SSL certificate issues?**
```bash
docker compose logs caddy
```

**Check site health**:
```bash
docker compose ps
curl -I https://yoursite.com
```

## Advanced Configuration

### Custom Ghost Configuration

Add environment variables to your site compose file:

```yaml
environment:
  # Custom Ghost settings
  privacy__useUpdateCheck: false
  privacy__useGravatar: false
  privacy__useRpcPing: false
  
  # Custom paths
  paths__contentPath: /var/lib/ghost/content
```

### www Subdomain Handling

Each site automatically gets www redirect options added to the Caddyfile (commented out by default). To enable www redirects:

1. **Choose your preferred redirect direction:**
   ```caddyfile
   # Option 1: www -> non-www redirect (recommended)
   www.yourdomain.com {
       redir https://yourdomain.com{uri} permanent
   }
   
   # Option 2: non-www -> www redirect  
   yourdomain.com {
       redir https://www.yourdomain.com{uri} permanent
   }
   ```

2. **Set up DNS for both domains:**
   ```bash
   yourdomain.com     IN  A   YOUR.SERVER.IP.ADDRESS
   www.yourdomain.com IN  A   YOUR.SERVER.IP.ADDRESS
   # OR use CNAME: www.yourdomain.com IN CNAME yourdomain.com
   ```

3. **Restart Caddy to apply changes:**
   ```bash
   docker compose restart caddy
   ```

### Wildcard Domains

For wildcard subdomain routing, update Caddyfile:

```caddyfile
*.yourdomain.com {
    @subdomain {
        host_regexp ^([^.]+)\.yourdomain\.com$
    }
    reverse_proxy @subdomain ghost_{re.subdomain.1}:2368
}
```

### Development Mode

Create `docker-compose.override.yml`:

```yaml
version: '3.8'
services:
  ghost_yoursite_com:
    environment:
      NODE_ENV: development
      url: http://localhost:2368
    ports:
      - "2368:2368"
```

## Migration from Single Ghost

1. Export your existing Ghost content
2. Create new site with `./scripts/new-site.sh yourdomain.com`
3. Access Ghost admin and import your content
4. Update DNS to point to new server

---

## Tinybird Local Analytics

This setup uses **Tinybird Local** for privacy-focused analytics:

### Features
- ✅ **Self-hosted**: All analytics data stays on your server
- ✅ **Privacy-preserving**: Salted user signatures, no external tracking
- ✅ **Multi-tenant**: Single instance serves all Ghost sites
- ✅ **Ghost-native**: Uses Ghost's official traffic-analytics service
- ✅ **Automatic setup**: Schema and tokens generated automatically

### Setup Process
The first time you run `./scripts/deploy.sh`, it will:

1. **Start Tinybird Local** on port 7181
2. **Generate admin and tracker tokens** automatically  
3. **Extract Ghost's Tinybird schema** from official Ghost image
4. **Deploy datasources and endpoints** to Tinybird Local
5. **Start Traffic Analytics service** on port 3001
6. **Configure all Ghost sites** to use the local instance

### Analytics Access
- **Tinybird API**: `http://localhost:7181` (internal)
- **Traffic Analytics**: `http://localhost:3001` (internal)  
- **Ghost Admin**: Analytics appear in each Ghost site's admin panel

### Manual Setup
If you need to run Tinybird setup separately:

```bash
./scripts/setup-tinybird.sh
```

This is useful for:
- Regenerating tokens
- Redeploying schema after Ghost updates
- Troubleshooting analytics issues

---

## Credits

This setup is built upon the excellent foundation provided by the **[official Ghost Docker configuration](https://github.com/tryghost/ghost-docker)** by the Ghost Foundation

## License

This project extends the MIT-licensed TryGhost/ghost-docker repository. See individual component licenses for full details.