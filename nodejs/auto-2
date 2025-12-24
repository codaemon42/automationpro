#!/bin/bash
set -euo pipefail

# -----------------------------
# HTTPS Automation Script
# -----------------------------

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "❌ Usage: $0 <domain-name>"
  exit 1
fi

echo "🔐 Enabling HTTPS for domain: $DOMAIN"

# -----------------------------
# 1. Install Certbot
# -----------------------------
echo "📦 Installing Certbot..."
sudo yum install -y certbot python3-certbot-nginx

# ----------------------------
# 2.a Nginx configuration
# ----------------------------
echo "🌐 Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/conf.d/node-app.conf > /dev/null <<EOF
server {
    listen       80;
    listen       [::]:80;
    server_name  $DOMAIN;
    root         /usr/share/nginx/html;

    # Load configuration files for the default server block.
    include /etc/nginx/default.d/*.conf;

    error_page 404 /404.html;
    location = /404.html {
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }
}
EOF

# -----------------------------------
# 2.b Validate Nginx configuration
# -----------------------------------
echo "🔍 Validating Nginx configuration..."
sudo nginx -t

# -----------------------------
# 3. Obtain SSL certificate
# -----------------------------
echo "📜 Requesting SSL certificate from Let's Encrypt..."
sudo certbot --nginx \
  -d "$DOMAIN" \
  --non-interactive \
  --agree-tos \
  -m admin@"$DOMAIN" \
  --redirect

# -----------------------------
# 4. Enable auto-renewal
# -----------------------------
echo "⏰ Enabling auto-renewal..."
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer

# -----------------------------
# 5. Dry-run renewal test
# -----------------------------
echo "🧪 Testing auto-renewal (dry run)..."
sudo certbot renew --dry-run

# -----------------------------
# 6. Reload Nginx
# -----------------------------
echo "🔄 Reloading Nginx..."
sudo systemctl reload nginx

echo
echo "✅ HTTPS enabled successfully!"
echo "🌍 Secure URL: https://$DOMAIN"
