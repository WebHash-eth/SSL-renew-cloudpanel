#!/bin/bash
#chmod +x renewssl.sh 
#crontab -e
#0 3 * * * /home/renewssl.sh >> /home/renewssl-cloudpanel-ssl.log 2>&1
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