#!/bin/bash
# KijaniKiosk Lab Setup Script
# Run as: sudo bash lab-setup.sh

set -e

echo "[+] Creating directory structure..."
mkdir -p /opt/kijanikiosk/{api,payments,logs,config,scripts,shared/logs}

echo "[+] Creating placeholder application files..."
echo "console.log('KijaniKiosk API running as: ' + process.getuid());" \
  > /opt/kijanikiosk/api/server.js
echo "# Payment processor" > /opt/kijanikiosk/payments/processor.py
echo "# Log aggregator" > /opt/kijanikiosk/logs/aggregator.py

echo "[+] Writing sensitive config files..."
cat > /opt/kijanikiosk/config/db.env << 'EOF'
DB_HOST=internal-postgres.kijanikiosk.internal
DB_PORT=5432
DB_NAME=kijanikiosk_prod
DB_USER=kk_app
DB_PASSWORD=s3cr3t-pr0d-p@ssword
EOF

cat > /opt/kijanikiosk/config/payments-api.env << 'EOF'
PAYMENTS_API_KEY=pk_live_AbCdEfGhIjKlMnOpQrStUvWxYz
PAYMENTS_WEBHOOK_SECRET=whsec_XyZaBcDeFgHiJkLmNoPqRsTuV
EOF

echo "[+] Creating deploy script with dangerous permissions..."
cat > /opt/kijanikiosk/scripts/deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying KijaniKiosk..."
EOF
chmod 4777 /opt/kijanikiosk/scripts/deploy.sh

echo "[+] Setting world-readable permissions on config..."
chmod -R 777 /opt/kijanikiosk/config/
chmod -R 777 /opt/kijanikiosk/

echo "[setup complete] Confirm the broken state before proceeding:"
ls -la /opt/kijanikiosk/config/
stat /opt/kijanikiosk/scripts/deploy.sh