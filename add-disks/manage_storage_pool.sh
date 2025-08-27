#!/bin/bash

# ==============================================================================
# Libvirt LVM Storage Pool Management Script
#
# Author: AI Assistant
# Version: 1.0
#
# A robust script to create, extend, and inspect Libvirt LVM storage pools.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Color Definitions ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Helper Functions ---
function print_info() {
    echo -e "${C_BLUE}INFO: $1${C_RESET}"
}

function print_success() {
    echo -e "${C_GREEN}SUCCESS: $1${C_RESET}"
}

function print_warning() {
    echo -e "${C_YELLOW}WARNING: $1${C_RESET}"
}

function print_error() {
    echo -e "${C_RED}ERROR: $1${C_RESET}" >&2
    exit 1
}

function check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Command '$1' not found. Please install it. (e.g., on Ubuntu/Debian: sudo apt install lvm2)"
    fi
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo."
    fi
}

function confirm_action() {
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Operation cancelled by user."
        exit 1
    fi
}


# --- Sub-command Functions ---

# 1. Create a new LVM-based storage pool
function create_pool() {
    if [[ $# -lt 2 ]]; then
        print_error "Usage: $0 create <pool_name> <vg_name> <device1> [device2] ..."
    fi

    local pool_name="$1"
    local vg_name="$2"
    shift 2
    local devices=("$@")

    print_info "Starting creation of new LVM storage pool..."
    print_info "Pool Name: ${C_CYAN}${pool_name}${C_RESET}"
    print_info "Volume Group Name: ${C_CYAN}${vg_name}${C_RESET}"
    print_info "Physical Devices: ${C_CYAN}${devices[*]}${C_RESET}"
    echo

    # --- Pre-flight Checks ---
    check_command "pvcreate"
    check_command "vgcreate"
    check_command "virsh"

    if virsh pool-list --all | grep -qw "$pool_name"; then
        print_error "A libvirt pool named '$pool_name' already exists."
    fi

    if vgdisplay "$vg_name" &> /dev/null; then
        print_error "An LVM Volume Group named '$vg_name' already exists."
    fi

    for device in "${devices[@]}"; do
        if ! [ -b "$device" ]; then
            print_error "Device '$device' is not a valid block device."
        fi
        if pvs "$device" &> /dev/null; then
             print_error "Device '$device' is already part of an LVM volume group."
        fi
    done

    # --- DANGER ZONE: Confirmation ---
    print_warning "This operation will IRREVERSIBLY DESTROY ALL DATA on the following disks:"
    for device in "${devices[@]}"; do
        print_warning "  - $device"
    done
    confirm_action

    # --- Execution ---
    print_info "Step 1/4: Creating LVM Physical Volumes (PVs)..."
    pvcreate -f "${devices[@]}"
    print_success "PVs created successfully."

    print_info "Step 2/4: Creating LVM Volume Group (VG)..."
    vgcreate "$vg_name" "${devices[@]}"
    print_success "Volume Group '$vg_name' created successfully."

    print_info "Step 3/4: Defining new Libvirt storage pool..."
    virsh pool-define-as --name "$pool_name" --type logical --source-name "$vg_name" --target "/dev/$vg_name"
    print_success "Libvirt pool '$pool_name' defined successfully."

    print_info "Step 4/4: Starting and enabling autostart for the pool..."
    virsh pool-start "$pool_name"
    virsh pool-autostart "$pool_name"
    virsh pool-refresh "$pool_name"
    print_success "Libvirt pool '$pool_name' is now active and set to autostart."
    echo
    print_success "All done! You can now use '$pool_name' in your Terraform/Tofu configurations."
    virsh pool-info "$pool_name"
}

# 2. Add a new disk to an existing LVM pool
function add_disk() {
    if [[ $# -ne 2 ]]; then
        print_error "Usage: $0 add-disk <vg_name> <new_device>"
    fi

    local vg_name="$1"
    local new_device="$2"

    print_info "Starting to add a new disk to an existing LVM Volume Group..."
    print_info "Volume Group Name: ${C_CYAN}${vg_name}${C_RESET}"
    print_info "New Physical Device: ${C_CYAN}${new_device}${C_RESET}"
    echo

    # --- Pre-flight Checks ---
    check_command "pvcreate"
    check_command "vgextend"

    if ! vgdisplay "$vg_name" &> /dev/null; then
        print_error "Volume Group '$vg_name' does not exist."
    fi

    if ! [ -b "$new_device" ]; then
        print_error "Device '$new_device' is not a valid block device."
    fi

    if pvs "$new_device" &> /dev/null; then
        print_error "Device '$new_device' is already part of an LVM volume group."
    fi

    # --- DANGER ZONE: Confirmation ---
    print_warning "This operation will IRREVERSIBLY DESTROY ALL DATA on disk: $new_device"
    confirm_action

    # --- Execution ---
    print_info "Step 1/3: Creating LVM Physical Volume (PV) on the new disk..."
    pvcreate -f "$new_device"
    print_success "PV created successfully on $new_device."

    print_info "Step 2/3: Extending the LVM Volume Group..."
    vgextend "$vg_name" "$new_device"
    print_success "Volume Group '$vg_name' extended successfully."

    print_info "Step 3/3: Refreshing associated Libvirt pools..."
    # Find all pools using this VG and refresh them
    pools_to_refresh=$(virsh pool-dumpxml --all | grep -B 2 "<source-name>$vg_name</source-name>" | grep "<name>" | sed -e 's/.*<name>\(.*\)<\/name>.*/\1/')
    if [ -n "$pools_to_refresh" ]; then
        for pool in $pools_to_refresh; do
            print_info "Refreshing libvirt pool '$pool' to recognize new capacity..."
            virsh pool-refresh "$pool"
            print_success "Pool '$pool' refreshed."
            virsh pool-info "$pool"
        done
    else
        print_warning "No Libvirt pool found associated with VG '$vg_name'. LVM capacity increased, but you may need to manually refresh pools if they exist."
    fi

    echo
    print_success "Disk '$new_device' successfully added to Volume Group '$vg_name'."
}

# 3. List all storage pools
function list_pools() {
    print_info "Listing all defined Libvirt storage pools:"
    virsh pool-list --all
}

# 4. Show detailed info for a specific pool
function pool_info() {
    if [[ $# -ne 1 ]]; then
        print_error "Usage: $0 info <pool_name>"
    fi
    local pool_name="$1"

    print_info "Detailed information for pool '$pool_name':"
    if ! virsh pool-info "$pool_name" &> /dev/null; then
        print_error "Pool '$pool_name' not found or is not active."
    fi
    virsh pool-info "$pool_name"
    echo
    print_info "XML definition for pool '$pool_name':"
    virsh pool-dumpxml "$pool_name"
}

# 5. Show LVM information
function lvm_info() {
    print_info "Displaying LVM Physical Volumes (PVs):"
    pvs
    echo
    print_info "Displaying LVM Volume Groups (VGs):"
    vgs
    echo
    print_info "Displaying LVM Logical Volumes (LVs):"
    lvs
}


# --- Main Logic & Help ---

function show_help() {
    echo -e "${C_CYAN}Libvirt LVM Storage Pool Management Script${C_RESET}"
    echo
    echo -e "This script helps you manage LVM-based storage pools for Libvirt."
    echo
    echo -e "${C_YELLOW}Usage:${C_RESET}"
    echo -e "  $0 <command> [options]"
    echo
    echo -e "${C_YELLOW}Available Commands:${C_RESET}"
    echo -e "  ${C_GREEN}create <pool_name> <vg_name> <device1> [device2]...${C_RESET}"
    echo -e "    Creates a new LVM-based storage pool from one or more physical disks."
    echo -e "    Example: $0 create hdd_pool vg_hdd /dev/sda /dev/sdb"
    echo
    echo -e "  ${C_GREEN}add-disk <vg_name> <new_device>${C_RESET}"
    echo -e "    Adds a new physical disk to an existing LVM Volume Group to expand its capacity."
    echo -e "    Example: $0 add-disk vg_hdd /dev/sdc"
    echo
    echo -e "  ${C_GREEN}list${C_RESET}"
    echo -e "    Lists all defined Libvirt storage pools (active and inactive)."
    echo
    echo -e "  ${C_GREEN}info <pool_name>${C_RESET}"
    echo -e "    Shows detailed information and XML definition for a specific storage pool."
    echo -e "    Example: $0 info hdd_pool"
    echo
    echo -e "  ${C_GREEN}lvm-info${C_RESET}"
    echo -e "    Displays a summary of the current LVM setup (PVs, VGs, LVs)."
    echo
    echo -e "  ${C_GREEN}help | --help${C_RESET}"
    echo -e "    Shows this help message."
    echo
}

# --- Command Dispatcher ---
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

check_root

SUBCOMMAND=$1
shift

case "$SUBCOMMAND" in
    create)
        create_pool "$@"
        ;;
    add-disk)
        add_disk "$@"
        ;;
    list)
        list_pools
        ;;
    info)
        pool_info "$@"
        ;;
    lvm-info)
        lvm_info
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $SUBCOMMAND"
        show_help
        exit 1
        ;;
esac

exit 0
