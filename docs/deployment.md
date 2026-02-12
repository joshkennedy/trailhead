# Deployment Guide

Complete guide to deploying Trailhead to production using Kamal and Hetzner.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Hetzner Server Setup](#hetzner-server-setup)
- [Kamal Configuration](#kamal-configuration)
- [Database Setup](#database-setup)
- [Environment Variables](#environment-variables)
- [First Deployment](#first-deployment)
- [Post-Deployment](#post-deployment)
- [Ongoing Operations](#ongoing-operations)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Install locally:

```bash
# Kamal (deployment tool)
gem install kamal

# Docker (for building images)
# Install from https://www.docker.com/products/docker-desktop

# Verify installations:
kamal version
docker --version
```

### Required Accounts

1. **Docker Hub** - Free account for image hosting
   - Sign up: https://hub.docker.com
   - Create repository: `yourname/trailhead`

2. **Hetzner Cloud** - VPS hosting
   - Sign up: https://www.hetzner.com/cloud
   - Add payment method
   - Generate API token (Project → Security → API tokens)

3. **Email Provider** - Choose one:
   - **Postmark**: https://postmarkapp.com (free tier: 100 emails/month)
   - **AWS SES**: https://aws.amazon.com/ses (pay-as-you-go)

4. **Honeybadger** (optional) - Error tracking
   - Sign up: https://www.honeybadger.io
   - Create project, copy API key

5. **Stripe** - Payment processing
   - Sign up: https://stripe.com
   - Get API keys from Dashboard → Developers → API keys

---

## Hetzner Server Setup

### Create Server via Web Console

1. **Log in to Hetzner Cloud Console**

2. **Create new project** (e.g., "Trailhead Production")

3. **Add server:**
   - **Location**: Choose closest to your users (US, EU, Asia)
   - **Image**: Ubuntu 24.04
   - **Type**: CPX11 to start ($5/month, upgradeable)
   - **Networking**: Enable IPv4 and IPv6
   - **SSH Keys**: Add your public key (`~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`)
   - **Firewall**: Create firewall rules:
     - Allow TCP 22 (SSH) from your IP
     - Allow TCP 80 (HTTP) from anywhere
     - Allow TCP 443 (HTTPS) from anywhere
   - **Name**: `trailhead-web-1`

4. **Note the server IP address** (shown after creation)

### Or Create via CLI (faster)

```bash
# Install Hetzner CLI
brew install hcloud  # macOS
# or: curl -L https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar xz

# Login
hcloud context create trailhead-production
# Paste your API token when prompted

# Create server
hcloud server create \
  --name trailhead-web-1 \
  --type cpx11 \
  --image ubuntu-24.04 \
  --ssh-key YOUR_KEY_NAME \
  --location nbg1

# Get IP
hcloud server ip trailhead-web-1
```

### Initial Server Configuration

SSH into server and secure it:

```bash
ssh root@YOUR_SERVER_IP

# Update packages
apt update && apt upgrade -y

# Install Docker (Kamal will handle this, but good to verify)
curl -fsSL https://get.docker.com | sh

# Create deploy user (optional, for non-root deploys)
adduser deploy
usermod -aG docker deploy
mkdir -p /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh

# Exit
exit
```

---

## Kamal Configuration

### Update deploy.yml

Edit `config/deploy.yml`:

```yaml
service: trailhead
image: yourname/trailhead

servers:
  web:
    hosts:
      - YOUR_SERVER_IP
    labels:
      traefik.http.routers.trailhead.rule: Host(`yourapp.com`)
      traefik.http.routers.trailhead-secure.entrypoints: websecure
      traefik.http.routers.trailhead-secure.rule: Host(`yourapp.com`)
      traefik.http.routers.trailhead-secure.tls: true
      traefik.http.routers.trailhead-secure.tls.certresolver: letsencrypt

registry:
  username: yourname
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL
  clear:
    - RAILS_ENV=production

traefik:
  options:
    publish:
      - "443:443"
    volume:
      - "/letsencrypt:/letsencrypt"
  args:
    entryPoints.web.address: ":80"
    entryPoints.websecure.address: ":443"
    certificatesResolvers.letsencrypt.acme.email: "you@example.com"
    certificatesResolvers.letsencrypt.acme.storage: "/letsencrypt/acme.json"
    certificatesResolvers.letsencrypt.acme.httpchallenge: true
    certificatesResolvers.letsencrypt.acme.httpchallenge.entrypoint: web

accessories:
  db:
    image: postgres:16
    host: YOUR_SERVER_IP
    port: 5432
    env:
      secret:
        - POSTGRES_PASSWORD
      clear:
        - POSTGRES_USER=trailhead
        - POSTGRES_DB=trailhead_production
    directories:
      - data:/var/lib/postgresql/data

  redis:
    image: redis:7
    host: YOUR_SERVER_IP
    port: 6379
    directories:
      - data:/data
```

### Configure Secrets

Create `.kamal/secrets` (already in .gitignore):

```bash
#!/usr/bin/env bash

# Docker Hub
export KAMAL_REGISTRY_PASSWORD="your-dockerhub-token"

# Rails
export RAILS_MASTER_KEY="$(cat config/master.key)"

# Database
export POSTGRES_PASSWORD="$(openssl rand -hex 32)"
export DATABASE_URL="postgres://trailhead:$POSTGRES_PASSWORD@trailhead-db:5432/trailhead_production"

# Redis
export REDIS_URL="redis://trailhead-redis:6379/0"

# Email (choose one)
export POSTMARK_API_TOKEN="your-postmark-token"
# or
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export AWS_REGION="us-east-1"

# Stripe
export STRIPE_PUBLISHABLE_KEY="pk_live_..."
export STRIPE_SECRET_KEY="sk_live_..."
export STRIPE_WEBHOOK_SECRET="whsec_..."

# Honeybadger
export HONEYBADGER_API_KEY="your-honeybadger-key"
```

Make executable:

```bash
chmod +x .kamal/secrets
```

---

## Database Setup

### Option 1: Docker Postgres (Included)

The `deploy.yml` already configures a Postgres container. On first deploy:

```bash
# Kamal will start it automatically
kamal setup

# Verify database is running
kamal accessory details db

# Create and migrate
kamal app exec 'bin/rails db:create db:migrate'
```

### Option 2: Managed Database (Recommended for Production)

Use Hetzner's managed database or another provider:

**Hetzner Managed Database:**

1. Create via console: Database → Create → PostgreSQL 16
2. Choose plan (starts at ~$15/month)
3. Copy connection string
4. Update `.kamal/secrets`:

```bash
export DATABASE_URL="postgres://user:password@host:port/dbname?sslmode=require"
```

5. Remove `accessories.db` section from `deploy.yml`

**Benefits:**
- Automatic backups
- Point-in-time recovery
- Automated updates
- Better performance

---

## Environment Variables

### Configure Credentials

Edit production credentials:

```bash
EDITOR=vim rails credentials:edit --environment production
```

Add:

```yaml
secret_key_base: <%= SecureRandom.hex(64) %>

postmark:
  api_token: your-postmark-token

stripe:
  publishable_key: pk_live_...
  secret_key: sk_live_...
  webhook_secret: whsec_...

honeybadger:
  api_key: your-key
```

### Update Production Config

Edit `config/environments/production.rb`:

```ruby
# Email
config.action_mailer.delivery_method = :postmark
config.action_mailer.postmark_settings = {
  api_token: Rails.application.credentials.dig(:postmark, :api_token)
}
config.action_mailer.default_url_options = { host: ENV["APP_HOST"] }

# Asset host (if using CDN)
config.asset_host = ENV["ASSET_HOST"] if ENV["ASSET_HOST"].present?

# Force SSL
config.force_ssl = true
```

---

## First Deployment

### Pre-flight Checklist

- [ ] Docker Hub credentials in `.kamal/secrets`
- [ ] Server IP in `deploy.yml`
- [ ] Domain DNS pointed to server IP
- [ ] Rails master key in `.kamal/secrets`
- [ ] Database password generated
- [ ] All env vars set in `.kamal/secrets`

### Deploy Steps

```bash
# 1. Setup infrastructure (first time only)
kamal setup

# This will:
# - Install Docker on server (if needed)
# - Start Traefik (reverse proxy)
# - Start database and Redis containers
# - Start Rails app container

# 2. Verify services
kamal traefik details
kamal accessory details db
kamal accessory details redis

# 3. Create database
kamal app exec 'bin/rails db:create'

# 4. Run migrations
kamal app exec 'bin/rails db:migrate'

# 5. Seed data (if you have seeds)
kamal app exec 'bin/rails db:seed'

# 6. Verify app is running
kamal app logs
curl https://yourapp.com
```

### Check Status

```bash
# See all running containers
kamal app details

# Check logs
kamal app logs --tail 50

# SSH into server to debug
kamal app exec -i bash
```

---

## Post-Deployment

### Set Up SSL Certificate

Traefik will automatically get a Let's Encrypt cert, but verify:

```bash
# Check Traefik logs
kamal traefik logs

# Look for:
# "Obtained certificate for yourapp.com"

# Test HTTPS
curl -I https://yourapp.com
```

### Create Admin User

```bash
kamal app exec -i 'bin/rails console'

# In console:
user = User.create!(
  email: "admin@yourapp.com",
  password: "temporary-password",
  confirmed_at: Time.current
)

account = Account.create!(name: "Admin Account")
account.memberships.create!(user: user, role: :owner)

exit
```

### Configure Backups

**Database backups with Hetzner:**

If using managed DB, enable automated backups in console.

**DIY backups with Docker Postgres:**

Create backup script on server:

```bash
#!/bin/bash
# /root/backup-db.sh

BACKUP_DIR="/backups/postgres"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="trailhead_${TIMESTAMP}.sql.gz"

mkdir -p $BACKUP_DIR

docker exec trailhead-db pg_dump -U trailhead trailhead_production | gzip > "$BACKUP_DIR/$FILENAME"

# Keep only last 30 days
find $BACKUP_DIR -type f -mtime +30 -delete

# Upload to S3 (optional)
# aws s3 cp "$BACKUP_DIR/$FILENAME" s3://your-bucket/backups/
```

Add to crontab:

```bash
crontab -e

# Daily at 2 AM
0 2 * * * /root/backup-db.sh
```

### Set Up Monitoring

**Honeybadger** will auto-report errors if configured.

**Uptime monitoring** - Use UptimeRobot (free) or similar:
- Monitor: https://yourapp.com/up
- Alert if down > 2 minutes

**Server monitoring** - Install basic metrics:

```bash
ssh root@YOUR_SERVER_IP

# Install Netdata (free, lightweight)
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh

# Access via: http://YOUR_SERVER_IP:19999
```

---

## Ongoing Operations

### Regular Deployments

After making changes:

```bash
# Deploy new version
kamal deploy

# Kamal will:
# 1. Build new image
# 2. Push to Docker Hub
# 3. Pull on server
# 4. Start new container
# 5. Run migrations (if any)
# 6. Switch traffic to new container
# 7. Stop old container

# Deploy with specific commands
kamal deploy --skip-push  # Use existing image
kamal deploy --version v1.2.3  # Deploy specific tag
```

### Run Migrations

```bash
# Standalone migration (already happens on deploy)
kamal app exec 'bin/rails db:migrate'
```

### Console Access

```bash
# Rails console
kamal app exec -i 'bin/rails console'

# Bash shell
kamal app exec -i bash
```

### View Logs

```bash
# App logs
kamal app logs --tail 100

# Follow logs
kamal app logs --follow

# Database logs
kamal accessory logs db

# Traefik logs
kamal traefik logs
```

### Rollback

```bash
# Roll back to previous version
kamal rollback
```

### Scale Up

Add more servers to `deploy.yml`:

```yaml
servers:
  web:
    hosts:
      - 1.2.3.4
      - 5.6.7.8
```

Then redeploy:

```bash
kamal setup  # Configure new server
kamal deploy  # Deploy to all servers
```

---

## Troubleshooting

### App Won't Start

```bash
# Check app logs
kamal app logs

# Common issues:
# - Missing env var → check .kamal/secrets
# - Database connection → verify DATABASE_URL
# - Redis connection → verify REDIS_URL
```

### Database Connection Failed

```bash
# Verify database is running
kamal accessory details db

# Restart database
kamal accessory restart db

# Check credentials
kamal app exec 'bin/rails runner "puts ENV[\"DATABASE_URL\"]"'
```

### SSL Certificate Issues

```bash
# Check Traefik logs
kamal traefik logs | grep letsencrypt

# Verify DNS is pointing to server
dig yourapp.com

# Restart Traefik
kamal traefik restart
```

### Out of Disk Space

```bash
# SSH into server
ssh root@YOUR_SERVER_IP

# Check disk usage
df -h

# Clean up Docker images/containers
docker system prune -a

# Clean old logs
journalctl --vacuum-time=7d
```

### Memory Issues

Upgrade server type in Hetzner console, then:

```bash
# Rebuild with new server
kamal setup
```

---

## Production Checklist

Before going live:

- [ ] SSL certificate active (HTTPS works)
- [ ] Database backups configured
- [ ] Error tracking configured (Honeybadger)
- [ ] Uptime monitoring configured
- [ ] Email sending tested
- [ ] Stripe webhooks configured
- [ ] Admin account created
- [ ] Security headers configured
- [ ] Rate limiting configured (optional)
- [ ] CDN for assets (optional)

---

## Additional Resources

- [Kamal Docs](https://kamal-deploy.org)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [Docker Docs](https://docs.docker.com)
- [Traefik Docs](https://doc.traefik.io/traefik/)

For questions, see [setup.md](setup.md) or [README](../README.md).
