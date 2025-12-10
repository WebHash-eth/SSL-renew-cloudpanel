# CloudPanel SSL Auto Renewal Script

## 🔐 CloudPanel Automatic SSL Renewal Script

This script automatically checks and renews Let's Encrypt SSL certificates for all domains managed by **CloudPanel**.  
It scans Nginx vhost configurations, detects certificate expiry, and renews SSL certificates using:

```
clpctl lets-encrypt:install:certificate --domainName=<domain>
```

The script renews certificates **only if 2 days or less are remaining** before expiration.

---

## 🚀 Features

- Automatically discovers domains from **CloudPanel Nginx configs**
- Reads SSL certificate expiry dates
- Issues certificates if missing
- Renews certificates expiring **within 48 hours**
- Handles DNS/validation errors safely
- Reloads Nginx after successful renewal
- No external tools required (uses CloudPanel's built-in ACME)

---

## 📂 Script

Create this file: `/usr/local/bin/renewssl.sh`

```bash
#!/bin/bash

echo "========== CloudPanel SSL Check Started =========="
echo "Date: $(date)"
echo ""

NGINX_CONF="/etc/nginx/sites-enabled"

for file in $NGINX_CONF/*.conf; do

    DOMAIN=$(grep -m1 "server_name" "$file" | awk '{print $2}' | sed 's/;//')

    if [ -z "$DOMAIN" ]; then
        continue
    fi

    SITE_PATH=$(grep -m1 "root " "$file" | awk '{print $2}' | sed 's/;//' | sed 's/\/htdocs//')

    CERT_PATH="$SITE_PATH/etc/ssl/fullchain.pem"

    echo "🔍 Checking $DOMAIN"

    if [ ! -f "$CERT_PATH" ]; then
        echo "❌ No SSL found — requesting from Let's Encrypt..."
        clpctl lets-encrypt:install:certificate --domainName="$DOMAIN" > /tmp/ssl.log 2>&1

        if [ $? -ne 0 ]; then
            echo "❌ SSL issue failed:"
            grep -E 'Error|problem|DNS|Failed' /tmp/ssl.log
        else
            echo "✅ SSL installed for $DOMAIN"
        fi

        echo ""
        continue
    fi

    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    NOW_EPOCH=$(date +%s)

    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

    echo "SSL Expiry: $EXPIRY_DATE ($DAYS_LEFT days remaining)"

    if [ $DAYS_LEFT -gt 2 ]; then
        echo "✔ SSL valid — skipping"
        echo ""
        continue
    fi

    echo "⚠ SSL expiring soon — renewing $DOMAIN ..."
    clpctl lets-encrypt:install:certificate --domainName="$DOMAIN" > /tmp/ssl.log 2>&1

    if [ $? -ne 0 ]; then
        echo "❌ Renewal failed"
        grep -E 'Error|problem|DNS|Failed' /tmp/ssl.log
    else
        echo "✅ SSL renewed for $DOMAIN"
        systemctl reload nginx
    fi

    echo ""
done

echo "========== SSL Check Completed =========="
```

---

## 🧩 Installation

### 1️⃣ Save the script

```bash
sudo nano /usr/local/bin/renewssl.sh
```

Paste → save → exit (`CTRL + X`, then `Y`, then Enter)

---

### 2️⃣ Make it executable

```bash
sudo chmod +x /usr/local/bin/renewssl.sh
```

---

## 🧪 Manual Execution

Run the script manually:

```bash
sudo /usr/local/bin/renewssl.sh
```

---

## ⏱ Cron Automation

To automate the SSL renewal every day at **3:00 AM**, add this cronjob:

```bash
sudo crontab -e
```

Add this line:

```
0 3 * * * /usr/local/bin/renewssl.sh >> /var/log/cloudpanel-ssl.log 2>&1
```

---

## 📌 Log File

All output is written to:

```
/var/log/cloudpanel-ssl.log
```

---

## ✔ Notes

- CloudPanel must be installed and functioning normally.
- DNS A/AAAA records **must** point to the server for issuance to succeed.
- If SSL fails, the script prints the Let's Encrypt validation error.
- Supports any site added through CloudPanel (Node.js, PHP, Python, Static, Reverse Proxy).
