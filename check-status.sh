#!/bin/bash

#==============================================================================
# Network Status Checker
# Description: Checks the current status of network services and configuration
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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.network-fix-config"

#==============================================================================
# Utility Functions
#==============================================================================

print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo -e "\n${BOLD}${CYAN}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${BOLD}${CYAN}$(printf '%*s' $padding '')${title}$(printf '%*s' $padding '')${NC}"
    echo -e "${BOLD}${CYAN}$(printf '=%.0s' $(seq 1 $width))${NC}"
}

print_section() {
    local title="$1"
    echo -e "\n${BOLD}${BLUE}$title${NC}"
    echo -e "${BLUE}$(printf -- '-%.0s' $(seq 1 ${#title}))${NC}"
}

get_service_status() {
    local service="$1"
    local status="unknown"
    local enabled="unknown"
    
    if systemctl list-unit-files | grep -q "^${service}\.service"; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status="active"
        elif systemctl is-failed --quiet "$service" 2>/dev/null; then
            status="failed"
        else
            status="inactive"
        fi
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            enabled="enabled"
        else
            enabled="disabled"
        fi
    else
        status="not-found"
        enabled="not-found"
    fi
    
    echo "$status|$enabled"
}

format_status() {
    local status="$1"
    case "$status" in
        "active") echo -e "${GREEN}●${NC} Active" ;;
        "inactive") echo -e "${RED}●${NC} Inactive" ;;
        "failed") echo -e "${RED}●${NC} Failed" ;;
        "not-found") echo -e "${YELLOW}●${NC} Not Found" ;;
        *) echo -e "${YELLOW}●${NC} Unknown" ;;
    esac
}

format_enabled() {
    local enabled="$1"
    case "$enabled" in
        "enabled") echo -e "${GREEN}Enabled${NC}" ;;
        "disabled") echo -e "${RED}Disabled${NC}" ;;
        "not-found") echo -e "${YELLOW}Not Found${NC}" ;;
        *) echo -e "${YELLOW}Unknown${NC}" ;;
    esac
}

#==============================================================================
# Status Check Functions
#==============================================================================

check_services() {
    print_section "Service Status"
    
    local services=("NetworkManager" "iwd" "wpa_supplicant" "systemd-networkd")
    
    printf "%-20s %-12s %-12s %s\n" "Service" "Status" "Enabled" "Description"
    printf "%-20s %-12s %-12s %s\n" "-------" "------" "-------" "-----------"
    
    for service in "${services[@]}"; do
        local result
        result=$(get_service_status "$service")
        local status="${result%|*}"
        local enabled="${result#*|}"
        
        local description=""
        case "$service" in
            "NetworkManager") description="Main network manager" ;;
            "iwd") description="Intel wireless daemon" ;;
            "wpa_supplicant") description="WPA supplicant daemon" ;;
            "systemd-networkd") description="systemd network manager" ;;
        esac
        
        printf "%-20s %-20s %-20s %s\n" \
            "$service" \
            "$(format_status "$status")" \
            "$(format_enabled "$enabled")" \
            "$description"
    done
}

check_network_devices() {
    print_section "Network Devices"
    
    if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager; then
        echo -e "${BLUE}NetworkManager devices:${NC}"
        nmcli device status 2>/dev/null || echo "  No devices found or NetworkManager not responding"
    else
        echo -e "${YELLOW}NetworkManager not available${NC}"
    fi
    
    echo ""
    
    if command -v iwctl &> /dev/null && systemctl is-active --quiet iwd; then
        echo -e "${BLUE}iwd devices:${NC}"
        iwctl device list 2>/dev/null || echo "  No devices found or iwd not responding"
    else
        echo -e "${YELLOW}iwd not available or inactive${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}Physical network interfaces:${NC}"
    if command -v ip &> /dev/null; then
        ip link show | grep -E "^[0-9]+:" | sed 's/^/  /'
    else
        ls /sys/class/net/ | sed 's/^/  /'
    fi
}

check_wifi_status() {
    print_section "Wi-Fi Status"
    
    # Check rfkill status
    if command -v rfkill &> /dev/null; then
        echo -e "${BLUE}RF Kill status:${NC}"
        rfkill list wifi | sed 's/^/  /' || echo "  No Wi-Fi devices found"
        echo ""
    fi
    
    # Check Wi-Fi networks (if NetworkManager is active)
    if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager; then
        echo -e "${BLUE}Available Wi-Fi networks (via NetworkManager):${NC}"
        local networks
        networks=$(nmcli device wifi list 2>/dev/null | wc -l)
        if [[ $networks -gt 1 ]]; then
            echo "  Found $((networks-1)) networks"
            nmcli device wifi list 2>/dev/null | head -6 | sed 's/^/  /'
            if [[ $networks -gt 6 ]]; then
                echo "  ... and $((networks-6)) more networks"
            fi
        else
            echo "  No networks found (try: nmcli device wifi rescan)"
        fi
        echo ""
    fi
    
    # Check current connections
    if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager; then
        echo -e "${BLUE}Active connections:${NC}"
        nmcli connection show --active 2>/dev/null | sed 's/^/  /' || echo "  No active connections"
    fi
}

check_configuration() {
    print_section "Configuration Status"
    
    # Check NetworkManager configuration
    local nm_conf="/etc/NetworkManager/NetworkManager.conf"
    if [[ -f "$nm_conf" ]]; then
        echo -e "${BLUE}NetworkManager configuration:${NC}"
        echo "  Config file: $nm_conf"
        
        if grep -q "wifi\.backend" "$nm_conf"; then
            local backend
            backend=$(grep "wifi\.backend" "$nm_conf" | cut -d'=' -f2 | tr -d ' ')
            echo "  Wi-Fi backend: $backend"
        else
            echo "  Wi-Fi backend: default (wpa_supplicant)"
        fi
        
        echo ""
    fi
    
    # Check if fix has been applied
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${GREEN}Network fix status: Applied${NC}"
        if [[ -r "$CONFIG_FILE" ]]; then
            source "$CONFIG_FILE" 2>/dev/null || true
            if [[ -n "${TIMESTAMP:-}" ]]; then
                local fix_date
                fix_date=$(date -d "@$TIMESTAMP" 2>/dev/null || echo "Unknown")
                echo "  Applied on: $fix_date"
            fi
        fi
    else
        echo -e "${YELLOW}Network fix status: Not applied${NC}"
    fi
    
    echo ""
    
    # Check backup status
    local backup_dir="${SCRIPT_DIR}/backup"
    if [[ -d "$backup_dir" ]] && [[ -n "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
        echo -e "${BLUE}Backup status:${NC}"
        echo "  Backup directory: $backup_dir"
        echo "  Available backups:"
        ls -la "$backup_dir" | tail -n +2 | sed 's/^/    /'
    else
        echo -e "${YELLOW}No backups found${NC}"
    fi
}

check_connectivity() {
    print_section "Network Connectivity"
    
    # Check if we have any network interfaces up
    local interfaces_up
    interfaces_up=$(ip link show up | grep -c "state UP" || echo "0")
    echo "  Network interfaces up: $interfaces_up"
    
    # Check for default route
    if ip route show default &>/dev/null; then
        echo -e "  Default route: ${GREEN}Present${NC}"
        ip route show default | head -1 | sed 's/^/    /'
    else
        echo -e "  Default route: ${RED}Missing${NC}"
    fi
    
    echo ""
    
    # Test basic connectivity (if available)
    echo -e "${BLUE}Connectivity test:${NC}"
    if command -v ping &> /dev/null; then
        if timeout 3 ping -c 1 8.8.8.8 &>/dev/null; then
            echo -e "  Internet connectivity: ${GREEN}Working${NC}"
        else
            echo -e "  Internet connectivity: ${RED}Failed${NC}"
        fi
    else
        echo "  Ping not available for connectivity test"
    fi
}

show_recommendations() {
    print_section "Recommendations"
    
    local nm_status="${1:-}"
    local iwd_status="${2:-}"
    
    # Analyze current state and provide recommendations
    if [[ "$nm_status" == "active" && "$iwd_status" == "active" ]]; then
        echo -e "${RED}⚠️  CONFLICT DETECTED${NC}"
        echo "  Both NetworkManager and iwd are running simultaneously."
        echo "  This can cause Wi-Fi connectivity issues."
        echo ""
        echo -e "${BLUE}Recommended actions:${NC}"
        echo "  • Run './fix-network.sh' to resolve the conflict"
        echo "  • This will disable iwd and configure NetworkManager properly"
        
    elif [[ "$nm_status" == "active" && "$iwd_status" != "active" ]]; then
        echo -e "${GREEN}✓ Configuration looks good${NC}"
        echo "  NetworkManager is active and iwd is not conflicting."
        echo ""
        if [[ -f "$CONFIG_FILE" ]]; then
            echo -e "${BLUE}Maintenance options:${NC}"
            echo "  • Run './restore-network.sh' to revert to original configuration"
        fi
        
    elif [[ "$nm_status" != "active" && "$iwd_status" == "active" ]]; then
        echo -e "${YELLOW}⚠️  Using iwd only${NC}"
        echo "  Only iwd is active. This is fine if intentional."
        echo ""
        echo -e "${BLUE}Available options:${NC}"
        echo "  • Use 'iwctl' commands to manage Wi-Fi"
        echo "  • Run './fix-network.sh' to switch to NetworkManager"
        
    else
        echo -e "${RED}⚠️  No active network manager${NC}"
        echo "  Neither NetworkManager nor iwd is active."
        echo ""
        echo -e "${BLUE}Recommended actions:${NC}"
        echo "  • Start NetworkManager: sudo systemctl start NetworkManager"
        echo "  • Or start iwd: sudo systemctl start iwd"
    fi
    
    echo ""
    
    # Additional recommendations based on common issues
    if command -v rfkill &> /dev/null; then
        if rfkill list wifi | grep -q "Soft blocked: yes"; then
            echo -e "${YELLOW}⚠️  Wi-Fi is soft blocked${NC}"
            echo "  • Unblock Wi-Fi: sudo rfkill unblock wifi"
            echo ""
        fi
    fi
}

show_banner() {
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                  Network Status Checker                     ║
║                                                              ║
║  Comprehensive analysis of network services and             ║
║  configuration status                                        ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    show_banner
    
    # Get service statuses for recommendations
    local nm_result iwd_result
    nm_result=$(get_service_status "NetworkManager")
    iwd_result=$(get_service_status "iwd")
    local nm_status="${nm_result%|*}"
    local iwd_status="${iwd_result%|*}"
    
    # Run all status checks
    check_services
    check_network_devices
    check_wifi_status
    check_configuration
    check_connectivity
    show_recommendations "$nm_status" "$iwd_status"
    
    print_header "Status Check Complete"
    echo -e "\n${BLUE}For more detailed logs, check:${NC}"
    echo "  • Recent fix logs: ${SCRIPT_DIR}/logs/"
    echo "  • System logs: journalctl -u NetworkManager"
    echo "  • System logs: journalctl -u iwd"
    echo ""
}

# Run main function
main "$@"
