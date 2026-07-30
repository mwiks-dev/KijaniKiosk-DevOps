#!/usr/bin/env bash

set -euo pipefail


check_prerequisites() {
    log "=== Pre-flight Checks ==="

    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        exit 1
    fi

    if [[ ! -f /etc/os-release ]]; then
        error "/etc/os-release not found."
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        error "This script only supports Ubuntu."
        exit 1
    fi

    success "Environment checks passed."
}

# =====================================================
# Variables
# =====================================================
APP_BASE="/opt/kijanikiosk"
APP_GROUP="kijanikiosk"
NODE_MAJOR_VERSION=18
NGINX_VERSION=1.24.0-2ubuntu7.13
MONITORING_SUBNET="10.0.1.0/24"

# =====================================================
# Logging functions
# =====================================================
log() {
    echo "[INFO] $*"
}

success() {
    echo "[ OK ] $*"
}

error() {
    echo "[ERROR] $*" >&2
}

# =====================================================
# Phase 1
# =====================================================
provision_packages() {
    log "=== Phase 1: Package Installation ==="

    # Update package index quietly
    apt-get update -qq

    # Install prerequisite packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        acl \
        ufw

    # Create keyring directory if it doesn't exist
    install -d -m 0755 /etc/apt/keyrings

    # Download the NodeSource GPG key (overwrite every run)
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg

    chmod 644 /etc/apt/keyrings/nodesource.gpg

    # Configure the NodeSource repository
    cat > /etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR_VERSION}.x nodistro main
EOF

    # Update package index again
    apt-get update -qq

    # Install nginx (pinned version) and nodejs
    if dpkg -s nodejs >/dev/null 2>&1; then
    success "Node.js already installed: $(node -v)"
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs
    fi

    apt-mark hold nodejs

    if dpkg -s nginx >/dev/null 2>&1; then
    success "nginx already installed."
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            nginx="${NGINX_VERSION}"
    fi

    apt-mark hold nginx

    # Log installed versions
    local nginx_version
    local node_version

    nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2)
    node_version=$(node -v)

    success "Installed nginx ${nginx_version} and Node.js ${node_version}"
}

# Why is overwriting the GPG key idempotent?

# Overwriting the key file is idempotent because the script always writes the same public key to the same location. 
# Running the script multiple times leaves the system in the same final state - the key file contains the current NodeSource signing key. 
# It doesn't create duplicate keys or accumulate changes, so repeated executions produce the same result.

# =====================================================
# Phase 2
# =====================================================
provision_users() {
    log "=== Phase 2: Service Accounts ==="

    # Create the application group if it doesn't already exist
    getent group "${APP_GROUP}" >/dev/null 2>&1 || \
        groupadd --system "${APP_GROUP}"

    # Create service accounts if missing and add them to the group
    for account in kk-api kk-payments kk-logs; do
        if ! id "${account}" >/dev/null 2>&1; then
            useradd \
                --system \
                --no-create-home \
                --shell /usr/sbin/nologin \
                "${account}"
        fi

        # Safe to run repeatedly
        usermod -aG "${APP_GROUP}" "${account}"
    done

    # Add amina to the application group if the account exists
    if id amina >/dev/null 2>&1; then
        usermod -aG "${APP_GROUP}" amina
    fi

    success "Service accounts and group membership configured successfully."
}

# =====================================================
# Phase 3
# =====================================================
provision_dirs() {
    log "=== Phase 3: Directory Structure ==="

    # Create directory structure
    mkdir -p "${APP_BASE}"/{api,payments,logs,config,scripts,shared/logs}

    # Ownership
    chown kk-api:kk-api "${APP_BASE}/api"
    chown kk-payments:kk-payments "${APP_BASE}/payments"
    chown kk-logs:kk-logs "${APP_BASE}/logs"

    chown root:"${APP_GROUP}" "${APP_BASE}/config"
    chown root:"${APP_GROUP}" "${APP_BASE}/scripts"

    chown kk-logs:kk-logs "${APP_BASE}/shared/logs"

    # Permissions
    chmod 750 "${APP_BASE}/api"
    chmod 750 "${APP_BASE}/payments"
    chmod 750 "${APP_BASE}/logs"
    chmod 750 "${APP_BASE}/config"
    chmod 750 "${APP_BASE}/scripts"

    # Shared log directory (SGID)
    chmod 2770 "${APP_BASE}/shared/logs"

    # ACLs
    setfacl -m u:kk-api:rwx "${APP_BASE}/shared/logs"
    setfacl -m u:kk-payments:rx "${APP_BASE}/shared/logs"

    # Default ACLs for newly created files/directories
    setfacl -d -m u:kk-api:rwx "${APP_BASE}/shared/logs"
    setfacl -d -m u:kk-payments:rx "${APP_BASE}/shared/logs"

    success "Directory structure, permissions, and ACLs configured successfully."
}


# =====================================================
# Phase 4
# =====================================================
provision_services() {
    log "=== Phase 4: systemd Unit Files ==="

    cat > /etc/systemd/system/kk-api.service << 'UNIT'
[Unit]
Description=KijaniKiosk API Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=kk-api
Group=kk-api
WorkingDirectory=/opt/kijanikiosk/api

ExecStart=/usr/bin/node server.js

Restart=on-failure
RestartSec=5
StartLimitBurst=3
StartLimitIntervalSec=60

EnvironmentFile=-/opt/kijanikiosk/config/api.env

StandardOutput=journal
StandardError=journal
SyslogIdentifier=kk-api

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
PrivateUsers=yes

ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes

MemoryDenyWriteExecute=yes
LockPersonality=yes

RestrictRealtime=yes
RestrictSUIDSGID=yes

RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

SystemCallArchitectures=native
SystemCallFilter=@system-service

UMask=0027

CapabilityBoundingSet=
AmbientCapabilities=

[Install]
WantedBy=multi-user.target
UNIT

    # Reload systemd to pick up the new unit
    systemctl daemon-reload

    # Enable service without starting it
    systemctl enable kk-api.service

    success "kk-api systemd service installed and enabled."
}

# =====================================================
# Phase 5
# =====================================================
provision_firewall() {
    log "=== Phase 5: Firewall Configuration ==="

    # Ensure UFW is installed
    if ! command -v ufw >/dev/null 2>&1; then
        error "ufw is not installed."
        exit 1
    fi

    # Reset to a clean state
    ufw --force reset

    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing

    # SSH
    ufw allow 22/tcp comment "SSH"

    # HTTP
    ufw allow 80/tcp comment "HTTP"

    # Monitoring subnet can access payments service
    ufw allow from "${MONITORING_SUBNET}" to any port 3001 proto tcp comment "Payments monitoring"

    # Everyone else blocked
    ufw deny 3001/tcp comment "Block external access"

    ufw --force enable

    success "Firewall configured successfully."
}

# =====================================================
# Phase 6
# =====================================================
provision_cleanup() {
    log "=== Phase 6: Post-Provisioning Verification ==="

    local failed=0

    # Verify service accounts
    for account in kk-api kk-payments kk-logs; do
        if id "${account}" >/dev/null 2>&1; then
            success "Account exists: ${account}"
        else
            log "FAIL: Account missing: ${account}"
            ((failed++))
        fi
    done

    # Verify directory structure
    for dir in \
        api \
        payments \
        logs \
        config \
        scripts \
        shared \
        shared/logs
    do
        if [[ -d "${APP_BASE}/${dir}" ]]; then
            success "Directory exists: ${APP_BASE}/${dir}"
        else
            log "FAIL: Missing directory: ${APP_BASE}/${dir}"
            ((failed++))
        fi
    done

    # Verify no SUID files exist
    if [[ -z "$(find "${APP_BASE}" -perm /4000 -print -quit 2>/dev/null)" ]]; then
        success "No SUID files found in ${APP_BASE}"
    else
        log "FAIL: SUID files detected in ${APP_BASE}"
        ((failed++))
    fi

    # Verify package holds
    if apt-mark showhold | grep -qx "nginx"; then
        success "nginx is held"
    else
        log "FAIL: nginx is not held"
        ((failed++))
    fi

    if apt-mark showhold | grep -qx "nodejs"; then
        success "nodejs is held"
    else
        log "FAIL: nodejs is not held"
        ((failed++))
    fi

    # Verify service is enabled
    if systemctl is-enabled kk-api.service >/dev/null 2>&1; then
        success "kk-api.service is enabled"
    else
        log "FAIL: kk-api.service is not enabled"
        ((failed++))
    fi

    # Final result
    if (( failed == 0 )); then
        success "All verification checks passed."
    else
        error "${failed} verification check(s) failed."
        exit 1
    fi
}

# =====================================================
# Phase 7
# =====================================================
provision_logging() {
  log "=== Phase 7: Logging Configuration ==="

  # Enable persistent journal storage
  mkdir -p /var/log/journal
  systemd-tmpfiles --create --prefix /var/log/journal 2>/dev/null || true

  # Configure size caps to prevent journal from filling disk
  cat >/tmp/kijanikiosk.conf <<'CONF'
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemMaxFileSize=50M
CONF

if ! cmp -s /tmp/kijanikiosk.conf /etc/systemd/journald.conf.d/kijanikiosk.conf; then
    mv /tmp/kijanikiosk.conf /etc/systemd/journald.conf.d/kijanikiosk.conf
    systemctl restart systemd-journald
else
    rm /tmp/kijanikiosk.conf
fi

  systemctl restart systemd-journald
  success "Persistent journal configured (max 500MB)"

  # Configure logrotate
    #
    cat > /etc/logrotate.d/kijanikiosk <<'EOF'
/opt/kijanikiosk/shared/logs/*.log {

    daily
    rotate 14

    compress
    delaycompress

    missingok
    notifempty

    copytruncate

    create 0640 kk-logs kk-logs

    sharedscripts

    postrotate
        systemctl kill -s HUP kk-api.service 2>/dev/null || true
        systemctl kill -s HUP kk-payments.service 2>/dev/null || true
        systemctl reload kk-logs.service 2>/dev/null || true
    endscript
}
EOF

    success "Logrotate configuration written."

    #
    # Validate logrotate configuration
    #
    if logrotate --debug /etc/logrotate.conf >/dev/null 2>&1; then
        success "logrotate configuration validated."
    else
        error "logrotate validation failed."
        exit 1
    fi

    success "Phase 7 completed successfully."
}

# =====================================================
# Phase 8
# =====================================================
provision_monitoring() {
    log "=== Phase 8: Monitoring Health Checks ==="

    mkdir -p "${APP_BASE}/health"

 # Write structured JSON
    printf '{
  "timestamp":"%s",
  "kk-api":%s,
  "kk-payments":%s,
  "kk-logs":%s
}
' \
    "$(date -Is)" \
    "$api_status" \
    "$payments_status" \
    "$logs_status" \
    > "${APP_BASE}/health/last-provision.json"

    chown kk-logs:kijanikiosk \
        "${APP_BASE}/health/last-provision.json"

    chmod 640 \
        "${APP_BASE}/health/last-provision.json"

    # Check service ports
    api_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3000" \
        2>/dev/null && echo '"ok"' || echo '"down"')

    payments_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3001" \
        2>/dev/null && echo '"ok"' || echo '"down"')

    logs_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3002" \
        2>/dev/null && echo '"ok"' || echo '"down"')

    

    success "Health check report written to ${APP_BASE}/health/last-provision.json"
}


verify_state() {
  log "=== Final Verification ==="
  local failed=0

  local held
  held=$(apt-mark showhold)
  for pkg in nginx nodejs; do
    if echo "${held}" | grep -q "^${pkg}$"; then
      success "PASS: Package held: ${pkg} ($(dpkg-query -W -f='${Version}' "${pkg}"))"
    else
      log "FAIL: Package not held: ${pkg}"
      ((failed++))
    fi
  done

  for account in kk-api kk-payments kk-logs; do
    if id "${account}" >/dev/null 2>&1; then
      success "PASS: Account exists: ${account}"
    else
      log "FAIL: Account missing: ${account}"
      ((failed++))
    fi
  done

  for dir in api payments config shared/logs scripts health; do
    if [[ -d "${APP_BASE}/${dir}" ]]; then
      success "PASS: Directory exists: ${APP_BASE}/${dir}"
    else
      log "FAIL: Directory missing: ${APP_BASE}/${dir}"
      ((failed++))
    fi
  done

  for pair in "kk-api:api.env" "kk-payments:payments-api.env"; do
    local user="${pair%%:*}"
    local envfile="${pair##*:}"
    if sudo -u "${user}" cat "${APP_BASE}/config/${envfile}" >/dev/null 2>&1; then
      success "PASS: ${envfile} readable by ${user}"
    else
      log "FAIL: ${envfile} NOT readable by ${user}"
      ((failed++))
    fi
  done

  local suid_files
  suid_files=$(find "${APP_BASE}" -perm /4000 2>/dev/null || true)
  if [[ -z "${suid_files}" ]]; then
    success "PASS: No SUID binaries under ${APP_BASE}"
  else
    log "FAIL: SUID binaries found: ${suid_files}"
    ((failed++))
  fi

  for svc in kk-api kk-payments kk-logs; do
    if systemctl is-enabled "${svc}.service" >/dev/null 2>&1; then
      success "PASS: ${svc}.service is enabled"
    else
      log "FAIL: ${svc}.service is not enabled"
      ((failed++))
    fi
  done

  local fw_status
  fw_status=$(ufw status)

  if echo "$fw_status" | grep -q "22/tcp.*ALLOW"; then
    success "PASS: Firewall — SSH (22/tcp) allowed"
  else
    log "FAIL: Firewall — SSH rule missing"
    ((failed++))
  fi

  if echo "$fw_status" | grep -q "80/tcp.*ALLOW"; then
    success "PASS: Firewall — HTTP (80/tcp) allowed"
  else
    log "FAIL: Firewall — HTTP rule missing"
    ((failed++))
  fi

  if echo "$fw_status" | grep -q "3001.*ALLOW.*${MONITORING_SUBNET}"; then
    success "PASS: Firewall — 3001/tcp allowed from ${MONITORING_SUBNET}"
  else
    log "FAIL: Firewall — 3001 monitoring subnet rule missing"
    ((failed++))
  fi

  if echo "$fw_status" | grep -q "3001.*DENY"; then
    success "PASS: Firewall — 3001/tcp external deny present"
  else
    log "FAIL: Firewall — 3001 deny rule missing"
    ((failed++))
  fi

  # Check that all rules have comments
  local uncommented
  uncommented=$(ufw status | grep -E "^[0-9]|ALLOW|DENY" | grep -v "#" | grep -cv "^Status\|^$\|^To\|^--\|^Default\|^New\|^Logging" || true)
  if [[ "$uncommented" -eq 0 ]]; then
    success "PASS: Firewall — all rules have comments"
  else
    warn "WARN: ${uncommented} firewall rule(s) may lack comments"
  fi


    # Verify Phase 7

    if [[ -d /var/log/journal ]]; then
        success "Persistent journal directory exists"
    else
        log "FAIL: Persistent journal directory missing"
        ((failed++))
    fi

    if [[ -f /etc/logrotate.d/kijanikiosk ]]; then
        success "Logrotate configuration exists"
    else
        log "FAIL: Logrotate configuration missing"
        ((failed++))
    fi

    if logrotate --debug /etc/logrotate.conf >/dev/null 2>&1; then
        success "Logrotate configuration validated"
    else
        log "FAIL: Logrotate validation failed"
        ((failed++))
    fi

    #
    # Verify Phase 8
    #

    if [[ -f "${APP_BASE}/health/last-provision.json" ]]; then
        success "Health report exists"
    else
        log "FAIL: Health report missing"
        ((failed++))
    fi

    if grep -q '"kk-api"' "${APP_BASE}/health/last-provision.json"; then
        success "Health report contains API status"
    else
        log "FAIL: API status missing from health report"
        ((failed++))
    fi

    if grep -q '"kk-payments"' "${APP_BASE}/health/last-provision.json"; then
        success "Health report contains Payments status"
    else
        log "FAIL: Payments status missing from health report"
        ((failed++))
    fi

    if [[ "$(stat -c '%U:%G' "${APP_BASE}/health/last-provision.json")" == "kk-logs:kijanikiosk" ]]; then
        success "Health report ownership correct"
    else
        log "FAIL: Health report ownership incorrect"
        ((failed++))
    fi

    if [[ "$(stat -c '%a' "${APP_BASE}/health/last-provision.json")" == "640" ]]; then
        success "Health report permissions correct"
    else
        log "FAIL: Health report permissions incorrect"
        ((failed++))
    fi

    if (( failed == 0 )); then
    success "=========================================="
    success "ALL VERIFICATION CHECKS PASSED"
    success "=========================================="
else
    error "=========================================="
    error "${failed} verification check(s) failed."
    error "=========================================="
    exit 1
fi
}
# =====================================================
# Main
# =====================================================
main() {
    check_prerequisites

    case "${1:-all}" in
        phase1)
            provision_packages
            ;;
        phase2)
            provision_users
            ;;
        phase3)
            provision_dirs
            ;;
        phase123)
            provision_packages
            provision_users
            provision_dirs
            provision_logging
            ;;
        all)
            provision_packages
            provision_users
            provision_dirs
            provision_logging
            provision_services
            provision_firewall
            provision_cleanup
            verify_state
            ;;
        *)
            echo "Usage: $0 [phase1|phase2|phase3|phase123|all]"
            exit 1
            ;;
    esac

    success "Provisioning completed."
}

main "$@"