#!/bin/bash

#==============================================================================
# Network Fix: NetworkManager & iwd Conflict Resolution
# Description: Resolves conflicts between NetworkManager and iwd
# Author: silkenny
# License: MIT
# Version: 2.0.0
#==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backup"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/fix-network-$(date +%Y%m%d-%H%M%S).log"
CONFIG_FILE="${SCRIPT_DIR}/.network-fix-config"

# Create necessary directories
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

#==============================================================================
# Logging Functions
#==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "WARNING" "$@"
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

#==============================================================================
# Utility Functions
#==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    local deps=("systemctl" "nmcli" "rfkill")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Please install the required packages and try again"
        exit 1
    fi
}

detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

backup_file() {
    local file="$1"
    local backup_name="$2"
    
    if [[ -f "$file" ]]; then
        cp "$file" "${BACKUP_DIR}/${backup_name}.backup"
        log_info "Backed up $file"
        return 0
    else
        log_warning "File $file does not exist, skipping backup"
        return 1
    fi
}

restore_file() {
    local file="$1"
    local backup_name="$2"
    
    if [[ -f "${BACKUP_DIR}/${backup_name}.backup" ]]; then
        cp "${BACKUP_DIR}/${backup_name}.backup" "$file"
        log_info "Restored $file from backup"
        return 0
    else
        log_warning "No backup found for $file"
        return 1
    fi
}

#==============================================================================
# Service Management Functions
#==============================================================================

check_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "active"
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "enabled"
    else
        echo "inactive"
    fi
}

backup_service_states() {
    log_info "Backing up service states..."
    
    cat > "${BACKUP_DIR}/service-states.backup" << EOF
# Service states backup - $(date)
IWD_STATUS=$(check_service_status "iwd")
NETWORKMANAGER_STATUS=$(check_service_status "NetworkManager")
WPA_SUPPLICANT_STATUS=$(check_service_status "wpa_supplicant")
EOF
    
    log_success "Service states backed up"
}

stop_conflicting_services() {
    log_info "Stopping conflicting services..."
    
    # Stop iwd if running
    if systemctl is-active --quiet iwd; then
        systemctl stop iwd
        log_info "Stopped iwd service"
    fi
    
    # Disable iwd to prevent auto-start
    if systemctl is-enabled --quiet iwd 2>/dev/null; then
        systemctl disable iwd
        log_info "Disabled iwd service"
    fi
    
    # Stop wpa_supplicant if it's running independently
    if systemctl is-active --quiet wpa_supplicant; then
        systemctl stop wpa_supplicant
        log_info "Stopped wpa_supplicant service"
    fi
}

configure_networkmanager() {
    log_info "Configuring NetworkManager..."
    
    local nm_conf="/etc/NetworkManager/NetworkManager.conf"
    
    # Backup original config
    backup_file "$nm_conf" "NetworkManager.conf"
    
    # Ensure NetworkManager uses wpa_supplicant
    if grep -q "\\[device\\]" "$nm_conf"; then
        # Update existing [device] section
        sed -i '/\[device\]/,/^\[/{s/wifi\.backend=.*/wifi.backend=wpa_supplicant/}' "$nm_conf"
        if ! grep -q "wifi\.backend" "$nm_conf"; then
            sed -i '/\[device\]/a wifi.backend=wpa_supplicant' "$nm_conf"
        fi
    else
        # Add [device] section
        echo -e "\n[device]\nwifi.backend=wpa_supplicant" >> "$nm_conf"
    fi
    
    log_success "NetworkManager configured to use wpa_supplicant"
}

restart_networkmanager() {
    log_info "Restarting NetworkManager..."
    
    systemctl restart NetworkManager
    sleep 3
    
    if systemctl is-active --quiet NetworkManager; then
        log_success "NetworkManager restarted successfully"
    else
        log_error "Failed to restart NetworkManager"
        return 1
    fi
    
    # Ensure NetworkManager is enabled
    if ! systemctl is-enabled --quiet NetworkManager; then
        systemctl enable NetworkManager
        log_info "Enabled NetworkManager service"
    fi
}

#==============================================================================
# Network Testing Functions
#==============================================================================

test_wifi_functionality() {
    log_info "Testing Wi-Fi functionality..."
    
    # Wait for NetworkManager to initialize
    sleep 5
    
    # Check if Wi-Fi is blocked
    if rfkill list wifi | grep -q "Soft blocked: yes"; then
        log_warning "Wi-Fi is soft blocked, unblocking..."
        rfkill unblock wifi
    fi
    
    # Test if NetworkManager can see Wi-Fi devices
    local wifi_devices
    wifi_devices=$(nmcli device status | grep wifi | wc -l)
    
    if [[ $wifi_devices -gt 0 ]]; then
        log_success "Found $wifi_devices Wi-Fi device(s)"
        
        # Try to scan for networks
        if nmcli device wifi rescan 2>/dev/null; then
            local networks
            networks=$(nmcli device wifi list | wc -l)
            log_success "Network scan successful, found $((networks-1)) networks"
        else
            log_warning "Network scan failed, but device is detected"
        fi
    else
        log_error "No Wi-Fi devices found by NetworkManager"
        return 1
    fi
}

#==============================================================================
# Main Functions
#==============================================================================

show_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              Network Fix: NM & iwd Conflict Resolution       ║
║                                                              ║
║  This script will resolve conflicts between NetworkManager   ║
║  and iwd by configuring NetworkManager as the primary       ║
║  Wi-Fi management service.                                   ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    local distro
    distro=$(detect_distribution)
    log_info "Detected distribution: $distro"
    
    # Check if both services exist
    if ! systemctl list-unit-files | grep -q "NetworkManager.service"; then
        log_error "NetworkManager not found on this system"
        exit 1
    fi
    
    if ! systemctl list-unit-files | grep -q "iwd.service"; then
        log_warning "iwd service not found - conflict may not exist"
    fi
    
    log_success "System compatibility check passed"
}

show_current_status() {
    echo -e "\n${YELLOW}Current Network Service Status:${NC}"
    echo "=================================="
    
    printf "%-20s: %s\n" "NetworkManager" "$(check_service_status 'NetworkManager')"
    printf "%-20s: %s\n" "iwd" "$(check_service_status 'iwd')"
    printf "%-20s: %s\n" "wpa_supplicant" "$(check_service_status 'wpa_supplicant')"
    
    echo ""
}

confirm_operation() {
    if [[ "${1:-}" == "--force" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Stop and disable iwd service"
    echo "  • Configure NetworkManager to use wpa_supplicant"
    echo "  • Restart NetworkManager"
    echo "  • Create backups of all modified files"
    echo ""
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

save_configuration() {
    cat > "$CONFIG_FILE" << EOF
# Network Fix Configuration
TIMESTAMP=$(date +%s)
BACKUP_CREATED=true
CHANGES_APPLIED=true
EOF
    log_info "Configuration saved"
}

apply_fix() {
    log_info "Starting network conflict resolution..."
    
    # Backup current state
    backup_service_states
    
    # Stop conflicting services
    stop_conflicting_services
    
    # Configure NetworkManager
    configure_networkmanager
    
    # Restart NetworkManager
    restart_networkmanager
    
    # Test functionality
    test_wifi_functionality
    
    # Save configuration
    save_configuration
    
    log_success "Network conflict resolution completed successfully!"
}

show_final_status() {
    echo -e "\n${GREEN}Final Network Service Status:${NC}"
    echo "=============================="
    
    printf "%-20s: %s\n" "NetworkManager" "$(check_service_status 'NetworkManager')"
    printf "%-20s: %s\n" "iwd" "$(check_service_status 'iwd')"
    printf "%-20s: %s\n" "wpa_supplicant" "$(check_service_status 'wpa_supplicant')"
    
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "• Use 'nmcli device wifi list' to scan for networks"
    echo "• Use 'nmcli device wifi connect <SSID>' to connect"
    echo "• Use './restore-network.sh' to revert changes if needed"
    echo "• Check logs at: $LOG_FILE"
    echo ""
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code"
        echo -e "\n${RED}Operation failed!${NC}"
        echo "Check the log file for details: $LOG_FILE"
        echo "Use './restore-network.sh' to revert any partial changes"
    fi
    exit $exit_code
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Initialize
    show_banner
    check_root
    check_dependencies
    check_system_compatibility
    
    # Show current status
    show_current_status
    
    # Confirm operation
    confirm_operation "$@"
    
    # Apply the fix
    apply_fix
    
    # Show results
    show_final_status
}

# Run main function with all arguments
main "$@"
