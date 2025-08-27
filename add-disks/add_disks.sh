#!/bin/bash

# ==============================================================================
# Libvirt VM Disk Addition Script
#
# Author: AI Assistant
# Version: 2.0 (Shell-based)
#
# This script reads a configuration file and adds specified virtual disks
# to KVM/QEMU virtual machines using virsh and LVM commands.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# The file that defines which VMs get which disks.
CONFIG_FILE="disk_config.txt"
# The Libvirt storage pool where new volumes will be created.
# This MUST be an LVM-based pool.
STORAGE_POOL="tofu-pool-001"

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
        print_error "Command '$1' not found. Please install it."
    fi
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo."
    fi
}

# --- Main Logic ---

# 1. Pre-flight checks
check_root
check_command "virsh"
check_command "awk"

if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file '$CONFIG_FILE' not found. Please create it."
fi

if ! virsh pool-info "$STORAGE_POOL" &> /dev/null; then
    print_error "Libvirt storage pool '$STORAGE_POOL' not found or is not active."
fi

print_info "Using storage pool: ${C_CYAN}$STORAGE_POOL${C_RESET}"
print_info "Reading configuration from: ${C_CYAN}$CONFIG_FILE${C_RESET}"
echo

# 2. Process the configuration file
# Use 'grep' to filter out empty lines and comments
grep -vE '^\s*#|^\s*$' "$CONFIG_FILE" | while read -r line; do
    # Read the line into an array
    read -r -a params <<< "$line"
    vm_name="${params[0]}"
    
    print_warning "==================== Processing VM: $vm_name ===================="

    # Check if VM exists and is running
    if ! virsh dominfo "$vm_name" &> /dev/null; then
        print_error "VM '$vm_name' does not exist. Skipping."
        continue
    fi
    
    # Get the disk sizes, which are all parameters after the first one
    disk_sizes=("${params[@]:1}")
    if [ ${#disk_sizes[@]} -eq 0 ]; then
        print_info "No disk sizes specified for '$vm_name'. Skipping."
        continue
    fi

    disk_index=0
    for size_gb in "${disk_sizes[@]}"; do
        # Generate a unique volume name
        timestamp=$(date +%s)
        volume_name="${vm_name}-extra-disk-${disk_index}-${timestamp}"
        
        print_info "--> Task: Add a ${C_CYAN}${size_gb}GB${C_RESET} disk to ${C_CYAN}${vm_name}${C_RESET}"

        # --- Step A: Create the libvirt volume ---
        print_info "    Step 1/2: Creating new volume '${C_CYAN}${volume_name}${C_RESET}' in pool '${C_CYAN}${STORAGE_POOL}${C_RESET}'..."
        virsh vol-create-as --pool "$STORAGE_POOL" --name "$volume_name" --capacity "${size_gb}G" --format raw
        
        # Get the full path of the newly created volume
        volume_path=$(virsh vol-path --pool "$STORAGE_POOL" --vol "$volume_name")
        if [ -z "$volume_path" ]; then
            print_error "    Failed to get path for new volume '$volume_name'. Aborting for this disk."
            continue
        fi
        print_success "    Volume created at: $volume_path"

        # --- Step B: Attach the volume to the VM ---
        print_info "    Step 2/2: Attaching volume to VM '${C_CYAN}${vm_name}${C_RESET}'..."
        # We use --persistent to make the change permanent in the VM's XML config.
        # --live makes the change effective immediately without a reboot.

        # 自动找到下一个可用的设备名，比如 vdb, vdc ...
        target_device=$(virsh domblklist "$vm_name" --details | grep -o 'vd[a-z]' | sort -u | tail -n 1)
        if [[ -z "$target_device" ]]; then
             # 如果没有任何vdX盘，就从vda开始
             next_char='a'
        else
             # 找到最后一个字母，并获取下一个字母
             last_char=${target_device: -1}
             next_char=$(printf "\\$(printf '%03o' "$(( $(printf '%d' "'$last_char") + 1 ))" )")
        fi
        new_target="vd${next_char}"

        print_info "    Calculated next available target device: ${C_CYAN}${new_target}${C_RESET}"

        virsh attach-disk "$vm_name" "$volume_path" "$new_target" --targetbus virtio --driver qemu --persistent --live 
        
        print_success "    Disk successfully attached to '$vm_name'."
        echo
        
        disk_index=$((disk_index + 1))
    done

    # --- Step C: Verify the result ---
    print_info "Verifying disks for '$vm_name':"
    virsh domblklist "$vm_name"
    echo

done

print_success "==================== All tasks completed. ===================="
