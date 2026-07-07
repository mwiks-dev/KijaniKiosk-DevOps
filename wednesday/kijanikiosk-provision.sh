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

    # Allow SSH BEFORE enabling the firewall
    ufw allow 22/tcp

    # Allow HTTP
    ufw allow 80/tcp

    # Enable firewall non-interactively
    ufw --force enable

    # Verify the ruleset
    ufw status verbose

    success "Firewall configured successfully."
}

# =====================================================
# Phase 6
# =====================================================
verify_state() {
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
# Main
# =====================================================
main() {
    check_prerequisites
    provision_packages
    provision_users
    provision_dirs
    provision_services
    provision_firewall
    verify_state

    success "KijaniKiosk provisioning completed successfully."
}

main "$@"