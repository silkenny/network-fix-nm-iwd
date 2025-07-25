#!/bin/bash

#==============================================================================
# Network Restore: Revert NetworkManager & iwd Changes
# Description: Restores the original network configuration
# Author: silkenny
# License: MIT
# Version: 2.0.0
#==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backup"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/restore-network-$(date +%Y%m%d-%H%M%S).log"
CONFIG_FILE="${SCRIPT_DIR}/.network-fix-config"

# Create log directory
mkdir -p "$LOG_DIR"

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

check_backup_exists() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        log_error "Cannot restore without backup files"
        exit 1
    fi
    
    if [[ ! -f "${BACKUP_DIR}/service-states.backup" ]]; then
        log_error "Service states backup not found"
        log_error "Cannot determine original configuration"
        exit 1
    fi
}

show_banner() {
    echo -e "${YELLOW}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              Network Restore: Revert Changes                 ║
║                                                              ║
║  This script will restore the original network              ║
║  configuration before the NetworkManager/iwd fix was        ║
║  applied.                                                    ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

restore_networkmanager_config() {
    log_info "Restoring NetworkManager configuration..."
    
    local nm_conf="/etc/NetworkManager/NetworkManager.conf"
    local backup_file="${BACKUP_DIR}/NetworkManager.conf.backup"
    
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$nm_conf"
        log_success "NetworkManager configuration restored"
    else
        log_warning "No NetworkManager backup found, skipping..."
    fi
}

restore_service_states() {
    log_info "Restoring original service states..."
    
    # Source the backup file to get original states
    source "${BACKUP_DIR}/service-states.backup"
    
    # Restore iwd service
    case "$IWD_STATUS" in
        "active")
            systemctl enable iwd
            systemctl start iwd
            log_info "Restored iwd service to active state"
            ;;
        "enabled")
            systemctl enable iwd
            log_info "Restored iwd service to enabled state"
            ;;
        "inactive")
            systemctl disable iwd 2>/dev/null || true
            systemctl stop iwd 2>/dev/null || true
            log_info "Kept iwd service in inactive state"
            ;;
    esac
    
    # Restore wpa_supplicant service
    case "$WPA_SUPPLICANT_STATUS" in
        "active")
            systemctl enable wpa_supplicant
            systemctl start wpa_supplicant
            log_info "Restored wpa_supplicant service to active state"
            ;;
        "enabled")
            systemctl enable wpa_supplicant
            log_info "Restored wpa_supplicant service to enabled state"
            ;;
        "inactive")
            systemctl disable wpa_supplicant 2>/dev/null || true
            systemctl stop wpa_supplicant 2>/dev/null || true
            log_info "Kept wpa_supplicant service in inactive state"
            ;;
    esac
    
    # Always ensure NetworkManager is running
    systemctl restart NetworkManager
    log_info "Restarted NetworkManager"
}

test_restoration() {
    log_info "Testing restoration..."
    
    sleep 3
    
    # Check service states
    local nm_status=$(systemctl is-active NetworkManager || echo "inactive")
    local iwd_status=$(systemctl is-active iwd || echo "inactive")
    
    if [[ "$nm_status" == "active" ]]; then
        log_success "NetworkManager is running"
    else
        log_error "NetworkManager is not running"
        return 1
    fi
    
    # Test basic connectivity
    if nmcli device status &>/dev/null; then
        log_success "NetworkManager is responding to commands"
    else
        log_warning "NetworkManager may not be fully functional"
    fi
}

cleanup_fix_artifacts() {
    log_info "Cleaning up fix artifacts..."
    
    # Remove configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        rm "$CONFIG_FILE"
        log_info "Removed configuration file"
    fi
    
    log_success "Cleanup completed"
}

show_current_status() {
    echo -e "\n${YELLOW}Current Network Service Status:${NC}"
    echo "=================================="
    
    printf "%-20s: %s\n" "NetworkManager" "$(systemctl is-active NetworkManager || echo 'inactive')"
    printf "%-20s: %s\n" "iwd" "$(systemctl is-active iwd || echo 'inactive')"
    printf "%-20s: %s\n" "wpa_supplicant" "$(systemctl is-active wpa_supplicant || echo 'inactive')"
    
    echo ""
}

show_backup_info() {
    echo -e "\n${BLUE}Available Backups:${NC}"
    echo "==================="
    
    if [[ -f "${BACKUP_DIR}/service-states.backup" ]]; then
        echo "✓ Service states backup"
        # Show backup date
        local backup_date
        backup_date=$(head -1 "${BACKUP_DIR}/service-states.backup" | grep -o '[0-9-]* [0-9:]*' || echo "Unknown date")
        echo "  Created: $backup_date"
    fi
    
    if [[ -f "${BACKUP_DIR}/NetworkManager.conf.backup" ]]; then
        echo "✓ NetworkManager configuration backup"
    fi
    
    echo ""
}

confirm_restoration() {
    if [[ "${1:-}" == "--force" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  • Restore original NetworkManager configuration"
    echo "  • Restore original service states (iwd, wpa_supplicant)"
    echo "  • Restart network services"
    echo "  • Remove fix configuration files"
    echo ""
    
    read -p "Do you want to continue with the restoration? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restoration cancelled by user"
        exit 0
    fi
}

show_final_status() {
    echo -e "\n${GREEN}Restoration Complete!${NC}"
    echo "===================="
    
    printf "%-20s: %s\n" "NetworkManager" "$(systemctl is-active NetworkManager || echo 'inactive')"
    printf "%-20s: %s\n" "iwd" "$(systemctl is-active iwd || echo 'inactive')"
    printf "%-20s: %s\n" "wpa_supplicant" "$(systemctl is-active wpa_supplicant || echo 'inactive')"
    
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "• Your network configuration has been restored to its original state"
    echo "• You may need to reconnect to Wi-Fi networks"
    echo "• If you were using iwd, you can now use 'iwctl' commands again"
    echo "• Check the restore log at: $LOG_FILE"
    echo ""
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Restoration failed with exit code $exit_code"
        echo -e "\n${RED}Restoration failed!${NC}"
        echo "Check the log file for details: $LOG_FILE"
        echo "Your system may be in an inconsistent state"
        echo "Consider manually reviewing network service configurations"
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
    check_backup_exists
    
    # Show current status and backup info
    show_current_status
    show_backup_info
    
    # Confirm restoration
    confirm_restoration "$@"
    
    # Perform restoration
    log_info "Starting network configuration restoration..."
    
    restore_networkmanager_config
    restore_service_states
    test_restoration
    cleanup_fix_artifacts
    
    log_success "Network configuration restoration completed successfully!"
    
    # Show results
    show_final_status
}

# Run main function with all arguments
main "$@"
