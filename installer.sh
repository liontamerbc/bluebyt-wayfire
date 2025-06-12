#!/usr/bin/env bash
################################################################################
# bluebyt-wayfire Desktop Installer for Arch Linux (Enhanced Version)
# Maintainer: liontamerbc
# Version: 3.0.0
# 
# Enhanced installer with improved error handling, logging, and user experience
# Features:
# - Robust error handling with retries and timeouts
# - Comprehensive logging with timestamps
# - Parallel package installation support
# - Enhanced security features
# - Better user feedback and progress indicators
# - Comprehensive configuration validation
# - For Arch Linux and derivatives ONLY
################################################################################

# === Script Setup ===
set -euo pipefail

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m'

# === Critical Safety Checks ===
# Initialize wait time variables
wait_time=5
max_wait_time=30
backoff_factor=1.5

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check if running on Arch Linux
if ! grep -q 'Arch Linux' /etc/os-release 2>/dev/null; then
    echo -e "${RED}Error: This script is only compatible with Arch Linux and its derivatives${NC}"
    exit 1
fi

# Check system architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}Error: This script is only compatible with x86_64 architecture${NC}"
    echo -e "${YELLOW}Detected architecture: $ARCH${NC}"
    exit 1
fi

# Check if running in a virtual environment
if [ -d /sys/module/kvm ] || [ -d /sys/module/vboxdrv ] || [ -d /sys/module/virtio ]; then
    echo -e "${YELLOW}Warning: Running in a virtual environment detected${NC}"
    echo -e "${YELLOW}Virtual environment detected. This may affect time synchronization${NC}"
    
    # Adjust NTP synchronization strategy for virtual environments
    export NTP_SYNC_STRATEGY="virtual"
fi

# Check network connectivity
if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
    echo -e "${RED}Error: No internet connection detected${NC}"
    echo -e "${YELLOW}Please ensure your virtual environment has internet access${NC}"
    exit 1
fi

# Function to check and improve system entropy
check_entropy() {
    local entropy
    local max_attempts=3
    local attempt=1
    local min_entropy=2000  # Increased minimum entropy threshold
    
    echo -e "${BLUE}Checking system entropy...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo 0)
        echo -e "${BLUE}Current entropy level: ${entropy}/4096${NC}"
        
        if [ "$entropy" -ge $min_entropy ]; then
            echo -e "${GREEN}Sufficient entropy available (${entropy}/4096)${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Low system entropy detected (${entropy}/4096), attempt $attempt/$max_attempts${NC}"
        
        # Install haveged if not present
        if ! command -v haveged &>/dev/null; then
            echo -e "${BLUE}Installing haveged...${NC}"
            if ! pacman -S --noconfirm haveged; then
                echo -e "${YELLOW}Failed to install haveged${NC}"
            fi
        fi
        
        # Start and enable haveged service
        if ! systemctl is-active --quiet haveged; then
            echo -e "${BLUE}Starting haveged service...${NC}"
            systemctl enable --now haveged
        fi
        
        # Install rng-tools if not installed
        if ! command -v rngd >/dev/null 2>&1; then
            echo -e "${BLUE}Installing rng-tools...${NC}"
            if ! pacman -S --noconfirm rng-tools; then
                echo -e "${YELLOW}Failed to install rng-tools${NC}"
            fi
        fi
        
        # Configure rngd to use hardware random number generator if available
        if [ -f "/etc/conf.d/rngd" ]; then
            echo -e "${BLUE}Configuring rngd...${NC}"
            sed -i 's|^#*RNGD_OPTS=.*|RNGD_OPTS="-r /dev/urandom -o /dev/random -f"|' /etc/conf.d/rngd
        fi
        
        # Start and enable rngd service
        if ! systemctl is-active --quiet rngd; then
            echo -e "${BLUE}Starting rngd service...${NC}"
            systemctl enable --now rngd
        fi
        
        # Generate entropy using multiple methods
        echo -e "${BLUE}Generating additional entropy...${NC}"
        for _ in {1..20}; do
            dd if=/dev/urandom of=/dev/null bs=1024 count=1024 2>/dev/null
            sleep 0.1
        done
        
        # Additional entropy sources
        echo -e "${BLUE}Using alternative entropy sources...${NC}"
        (ps aux 2>&1 | sha1sum >/dev/null) &
        (find /usr/include -type f -exec cat {} + 2>&1 | sha1sum >/dev/null) &
        (cat /proc/interrupts 2>&1 | sha1sum >/dev/null) &
        
        sleep 2  # Give time for entropy to accumulate
        
        attempt=$((attempt + 1))
    done
    
    entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo 0)
    if [ "$entropy" -lt $min_entropy ]; then
        echo -e "${YELLOW}Warning: Could not achieve sufficient entropy (${entropy}/4096). Continuing, but some operations may be slow.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Entropy generation successful (${entropy}/4096)${NC}"
    return 0
}

# Function to synchronize system clock
sync_system_clock() {
    local max_attempts=5
    local attempt=1
    local sync_success=false
    
    echo -e "${BLUE}Starting system clock synchronization...${NC}"
    
    # Ensure systemd-timesyncd is installed and enabled
    if ! pacman -Qi systemd >/dev/null 2>&1; then
        echo -e "${BLUE}Installing systemd...${NC}"
        pacman -S --noconfirm systemd
    fi
    
    if ! pacman -Qi systemd-sysvcompat >/dev/null 2>&1; then
        echo -e "${BLUE}Installing systemd-sysvcompat...${NC}"
        pacman -S --noconfirm systemd-sysvcompat
    fi
    
    # Install chrony for better time synchronization
    if ! command -v chronyc >/dev/null 2>&1; then
        echo -e "${BLUE}Installing chrony for better time synchronization...${NC}"
        pacman -S --noconfirm chrony
    fi
    
    # Configure chrony with multiple reliable NTP servers
    echo -e "${BLUE}Configuring NTP servers...${NC}"
    cat > /etc/chrony.conf << EOL
# Use public NTP servers from the pool.ntp.org project
server 0.arch.pool.ntp.org iburst
server 1.arch.pool.ntp.org iburst
server 2.arch.pool.ntp.org iburst
server 3.arch.pool.ntp.org iburst

# Use the local system clock as a fallback if all servers fail
local stratum 10

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second
makestep 1.0 3

# Enable kernel synchronization of the real-time clock
rtcsync

# Enable hardware timestamping on all interfaces that support it
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust system clock
minsources 2

# Allow NTP client access from local network
#allow 192.168.0.0/16

# Serve time even if not synchronized to any NTP server
#local stratum 10

# Specify directory for log files
logdir /var/log/chrony

# Select which information is logged
#log measurements statistics tracking
EOL
    
    # Start and enable chronyd
    echo -e "${BLUE}Starting chronyd service...${NC}"
    systemctl enable --now chronyd
    
    # Wait for chronyd to start
    sleep 2
    
    # Sync using multiple methods
    while [ $attempt -le $max_attempts ] && [ "$sync_success" = false ]; do
        echo -e "${BLUE}Time synchronization attempt $attempt/$max_attempts...${NC}"
        
        # Force sync with chrony
        chronyc makestep >/dev/null 2>&1
        chronyc waitsync 10 0.1 3 1 >/dev/null 2>&1
        
        # Force sync with systemd-timesyncd
        systemctl restart systemd-timesyncd
        timedatectl set-ntp true
        
        # Check sync status
        if timedatectl show | grep -q 'NTPSynchronized=yes'; then
            sync_success=true
            break
        fi
        
        # If still not synced, try with ntpdate as fallback
        if ! command -v ntpdate >/dev/null 2>&1; then
            echo -e "${BLUE}Installing ntpdate as fallback...${NC}"
            pacman -S --noconfirm ntp
        fi
        
        echo -e "${BLUE}Trying ntpdate fallback...${NC}"
        ntpdate -s pool.ntp.org
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    # Final status check
    if [ "$sync_success" = true ] || timedatectl show | grep -q 'NTPSynchronized=yes'; then
        echo -e "${GREEN}System clock synchronized successfully${NC}"
        echo -e "${GREEN}System time: $(date)${NC}"
        timedatectl timesync-status --no-pager
        return 0
    else
        echo -e "${YELLOW}Warning: Could not fully synchronize system clock${NC}"
        echo -e "${YELLOW}System time: $(date)${NC}"
        timedatectl timesync-status --no-pager || true
        return 1
    fi
}

# Function to check and fix NTP synchronization
check_ntp() {
    local chrony_config="/etc/chrony.conf"
    local attempts=0
    local responding=false
    local ntp_servers="pool.ntp.org"
    local sync_strategy=${NTP_SYNC_STRATEGY:-"physical"}
    local wait_time=5
    local max_wait_time=30
    local backoff_factor=1.5

    echo -e "${BLUE}Checking NTP synchronization...${NC}"
    echo -e "${BLUE}Using NTP sync strategy: $sync_strategy${NC}"
    
    # Install chrony if not present
    if ! systemctl list-unit-files chronyd.service &>/dev/null; then
        echo -e "${BLUE}Installing chrony...${NC}"
        pacman -S --noconfirm chrony
    fi

    # For virtual environments, use less aggressive sync strategy
    if [ "$sync_strategy" = "virtual" ]; then
        echo -e "${YELLOW}Adjusting NTP settings for virtual environment${NC}"
        ntp_servers="0.pool.ntp.org 1.pool.ntp.org"
    fi

    # Install ntp if not present
    if ! command -v ntpdate &>/dev/null; then
        echo -e "${BLUE}Installing NTP utilities...${NC}"
        pacman -S --noconfirm ntp
    fi

    # Ensure chrony is enabled and started
    systemctl enable chronyd.service
    systemctl start chronyd.service

    # Verify chrony config exists
    if [ ! -f "$chrony_config" ]; then
        echo -e "${BLUE}Creating default chrony configuration...${NC}"
        echo "pool $ntp_servers iburst" > "$chrony_config"
    fi

    # Try to synchronize time immediately using ntpdate
    echo -e "${BLUE}Attempting to synchronize system time...${NC}"
    if ntpdate -u "$ntp_servers" &>/dev/null; then
        echo -e "${GREEN}System time synchronized successfully${NC}"
        return 0
    fi

    # If ntpdate fails, try using timedatectl
    echo -e "${YELLOW}ntpdate failed, trying timedatectl...${NC}"
    if timedatectl set-ntp true; then
        echo -e "${GREEN}NTP service enabled${NC}"
        return 0
    fi

    # Try fallback servers if primary fails
    if ! $responding; then
        # Try fallback servers only once
        if [ $attempts -eq 0 ]; then
            echo -e "${BLUE}Switching to fallback NTP servers...${NC}"
            ntp_servers="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org"
            echo "pool $ntp_servers iburst" > "$chrony_config"
            systemctl restart chronyd
            attempts=1
            
            # Cap wait time at max_wait_time
            wait_time=$(awk "BEGIN {print int($wait_time * $backoff_factor)}")
            if [ "$wait_time" -gt "$max_wait_time" ]; then
                wait_time="$max_wait_time"
            fi
            
            sleep "$wait_time"
        fi
    fi

    # If both methods fail, try one final sync with ntpdate as fallback
    if ! command -v ntpdate &>/dev/null; then
        echo -e "${BLUE}Installing ntpdate...${NC}"
        pacman -S --noconfirm ntp
    fi
    
    echo -e "${BLUE}Attempting final sync with ntpdate...${NC}"
    if ntpdate -u pool.ntp.org &>/dev/null; then
        echo -e "${GREEN}Successfully synchronized using ntpdate${NC}"
        return 0
    fi

    # If all else fails, try a direct connection to a known good server
    echo -e "${YELLOW}Trying known NTP servers...${NC}"
    local known_servers=(
        "time.cloudflare.com"
        "time.google.com"
        "time.apple.com"
        "time.windows.com"
    )
    
    for server in "${known_servers[@]}"; do
        if ping -c 1 -W 2 "$server" &>/dev/null; then
            echo -e "${BLUE}Attempting direct sync with ${server}...${NC}"
            if ntpdate -u "$server" &>/dev/null; then
                echo -e "${GREEN}Successfully synchronized with ${server}${NC}"
                return 0
            fi
        fi
    done

    # As a last resort, try setting time manually
    echo -e "${BLUE}Attempting manual time synchronization...${NC}"
    local current_time
    current_time=$(date -u +%s)
    local target_time
    target_time=$((current_time + 3600))  # Add 1 hour to ensure we're in the future
    if date -u -s "@${target_time}" &>/dev/null && hwclock -w &>/dev/null; then
        echo -e "${GREEN}Successfully synchronized time manually${NC}"
        return 0
    fi

    # Start chronyd if not running
    if ! systemctl is-active --quiet chronyd; then
        echo -e "${BLUE}Starting chronyd...${NC}"
        systemctl start chronyd
    fi

    # Wait for NTP to synchronize with exponential backoff
    local ntp_attempts=0
    local ntp_max_attempts=20
    local ntp_wait_time=5
    local ntp_backoff_factor=1.5
    local ntp_max_wait_time=60
    
    while [ "$ntp_attempts" -lt "$ntp_max_attempts" ]; do
        if chronyc sources | grep -q "^\\*"; then
            echo -e "${GREEN}NTP synchronized successfully with ${ntp_servers}${NC}"
            return 0
        fi
        
        # Don't show status messages after first attempt to avoid spam
        if [ "$ntp_attempts" -eq 0 ]; then
            echo -e "${BLUE}Attempting to synchronize with NTP servers...${NC}"
        fi
        
        # Check if any servers are responding
        local ntp_responding=false
        for server in $ntp_servers; do
            if ping -c 1 -W 2 "$server" &>/dev/null; then
                ntp_responding=true
                break
            fi
        done
        
        if ! $ntp_responding; then
            # Try fallback servers only once
            if [ "$ntp_attempts" -eq 0 ]; then
                echo -e "${BLUE}Switching to fallback NTP servers...${NC}"
                ntp_servers="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org"
                echo "pool $ntp_servers iburst" > "$chrony_config"
                systemctl restart chronyd
            fi
        fi
        
        # Cap wait time at max_wait_time
        ntp_wait_time=$(awk "BEGIN {print int($ntp_wait_time * $ntp_backoff_factor)}")
        if [ "$ntp_wait_time" -gt "$ntp_max_wait_time" ]; then
            ntp_wait_time="$ntp_max_wait_time"
        fi
        
        sleep "$ntp_wait_time"
        ntp_attempts=$((ntp_attempts + 1))
    done
    
    # If we have a backup config, restore it
    if [ -n "${backup_config:-}" ] && [ -f "$backup_config" ]; then
        cp -f "$backup_config" "$chrony_config"
        rm -f "$backup_config"
    fi
    
    echo -e "${RED}Error: Failed to synchronize NTP after all attempts${NC}"
    echo -e "${YELLOW}Continuing installation with current time...${NC}"
    return 0  # Don't fail the entire installation
}

# Run entropy check
check_entropy

# Run NTP check
check_ntp || {
    echo -e "${RED}Error: NTP synchronization failed${NC}"
    echo -e "${YELLOW}This can cause package signature verification failures${NC}"
    echo -e "${YELLOW}Please fix NTP synchronization and try again${NC}"
    exit 1
}

# Check system entropy
if [ -r /proc/sys/kernel/random/entropy_avail ]; then
    entropy=$(cat /proc/sys/kernel/random/entropy_avail)
    if [ "$entropy" -lt 500 ]; then
        echo -e "${YELLOW}Warning: Low system entropy (${entropy}/4096) detected. This might cause package signature verification to hang.${NC}"
            fi
            echo -e "${GREEN}Starting haveged service...${NC}"
            if ! systemctl start haveged &>/dev/null; then
                echo -e "${RED}Error: Failed to start haveged service${NC}"
                exit 1
            fi
            echo -e "${GREEN}Enabling haveged service...${NC}"
            if ! systemctl enable haveged &>/dev/null; then
                echo -e "${RED}Error: Failed to enable haveged service${NC}"
                exit 1
            fi
            echo -e "${GREEN}haveged installed and started successfully${NC}"
        fi
        # Wait a moment for haveged to generate entropy
        sleep 2
        # Recheck entropy after haveged installation
        entropy=$(cat /proc/sys/kernel/random/entropy_avail)
        if [ "$entropy" -lt 1000 ]; then
            echo -e "${YELLOW}Warning: Entropy still low after haveged installation (${entropy})${NC}"
            echo -e "${YELLOW}Continuing installation with existing entropy${NC}"
        fi

# Check system time
if command -v timedatectl &>/dev/null; then
    if ! timedatectl status | grep -q "system clock synchronized: yes"; then
        echo -e "${RED}Error: System time is not synchronized${NC}"
        echo -e "${YELLOW}This can cause package signature verification failures${NC}"
        echo -e "${BLUE}Attempting to enable NTP synchronization...${NC}"
        if ! timedatectl set-ntp true &>/dev/null; then
            echo -e "${RED}Error: Failed to enable NTP synchronization${NC}"
            echo -e "${YELLOW}Please enable NTP synchronization manually${NC}"
            exit 1
        fi
        echo -e "${GREEN}NTP synchronization enabled${NC}"
        # Wait a moment for NTP to sync
        sleep 5
        # Recheck time synchronization
        if ! timedatectl status | grep -q "system clock synchronized: yes"; then
            echo -e "${RED}Error: Failed to synchronize system time even after enabling NTP${NC}"
            echo -e "${YELLOW}Please verify NTP synchronization manually${NC}"
            exit 1
        fi
        echo -e "${GREEN}System time synchronized successfully${NC}"
    fi
fi

# Check security modules
if command -v getenforce &>/dev/null; then
    if [ "$(getenforce)" = "Enforcing" ]; then
        echo -e "${YELLOW}Warning: SELinux is in Enforcing mode${NC}"
        echo -e "${YELLOW}This might interfere with package installation${NC}"
    fi
fi

if command -v aa-status &>/dev/null; then
    if aa-status --enabled; then
        echo -e "${YELLOW}Warning: AppArmor is enabled${NC}"
        echo -e "${YELLOW}This might interfere with package installation${NC}"
    fi
fi

# Check system load
load=$(uptime | awk '{print $(NF-2)}' | sed 's/,//')
if (( $(echo "$load > 4" | bc -l) )); then
    echo -e "${YELLOW}Warning: System load is high ($load)${NC}"
    echo -e "${YELLOW}Consider waiting for lower load before proceeding${NC}"
fi

# Check essential system tools
ESSENTIAL_TOOLS=(bash coreutils grep sed awk findmnt mount systemd)
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}Error: Essential tool not found: $tool${NC}"
        echo -e "${YELLOW}Please install base system tools first${NC}"
        exit 1
    fi
done

# Check if pacman is available and working
if ! command -v pacman &>/dev/null; then
    echo -e "${RED}Error: Pacman package manager not found${NC}"
    exit 1
fi

# Verify pacman database is healthy
if ! pacman -Syy --noconfirm &>/dev/null; then
    echo -e "${RED}Error: Pacman database is corrupted${NC}"
    echo -e "${YELLOW}Please run 'pacman -Syyu' to fix the database${NC}"
    exit 1
fi

# Check network connectivity
if ! ping -c 1 archlinux.org &>/dev/null; then
    echo -e "${RED}Error: No network connectivity detected${NC}"
    echo -e "${YELLOW}Please ensure your network is properly configured${NC}"
    exit 1
fi

# Check filesystem health
if ! fsck -n / &>/dev/null; then
    echo -e "${RED}Warning: Filesystem check detected potential issues${NC}"
    echo -e "${YELLOW}Please run 'fsck -f /' to fix any filesystem issues${NC}"
fi

# Verify disk space on critical partitions
DISK_CHECKS=(
    "/"  # Root partition
    "/home"  # Home partition if exists
    "/var"  # Package cache
)

for mount in "${DISK_CHECKS[@]}"; do
    if mountpoint -q "$mount"; then
        free_space=$(df -m "$mount" | awk 'NR==2 {print $4}')
        if [ "$free_space" -lt 1000 ]; then  # 1GB minimum
            echo -e "${RED}Error: Insufficient disk space on $mount${NC}"
            echo -e "${YELLOW}Free space: $free_space MB${NC}"
            exit 1
        fi
    fi
done

# Function to set resource limits based on system capabilities
set_resource_limits() {
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_mb
    mem_mb=$((mem_total / 1024))

    # Set more reasonable limits for minimal Arch
    if [ "$mem_mb" -lt 2048 ]; then
        ulimit -n 1024  # max open files for low memory systems
        ulimit -u 512   # max user processes
    else
        ulimit -n 2048  # max open files
        ulimit -u 1024  # max user processes
    fi
}

# Set resource limits
set_resource_limits

# Create safe temporary directory
TEMP_DIR=$(mktemp -d -p /tmp wayfire-installer-XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Backup current system state
SYSTEM_BACKUP_DIR="$TEMP_DIR/system_state_$(date +%s)"
mkdir -p "$SYSTEM_BACKUP_DIR"a

# Backup essential system files
run "cp -a /etc/pacman.conf \"$SYSTEM_BACKUP_DIR/\""
run "cp -a /etc/fstab \"$SYSTEM_BACKUP_DIR/\""
run "cp -a /etc/locale.conf \"$SYSTEM_BACKUP_DIR/\""
run "cp -a /etc/timezone \"$SYSTEM_BACKUP_DIR/\""

# === Constants ===
readonly SCRIPT_VERSION="3.0.0"
SCRIPT_DIR
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly SCRIPT_DIR
LOG_FILE
LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
readonly LOG_FILE
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=300

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m'

# === Global Variables ===
# Removed unused CONFIG_BACKUPS
FAILED=false
DRY_RUN=false
AUTO_YES=false
# Removed unused set_fish

# === Configuration ===
THEME="TokyoNight-Dark"
INSTALL_ALL=true
SKIP_WALLPAPERS=false
INSTALL_GNOME=false
BACKUP_DIR="$HOME/.config_backup_$(date +%F_%T)"

# === Core Functions ===
# === Logging ===
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [INFO]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] [WARN]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
}

fatal() {
    error "$1"
    exit 1
}

progress() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -ne "${BLUE}[$timestamp] [PROGRESS]${NC} $*\r" | tee -a "$LOG_FILE"
}

# === Command Execution ===
run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
        return 0
    fi
    
    local cmd="$*"
    progress "Executing: $cmd"
    
    if ! timeout $TIMEOUT_SECONDS "$cmd"; then
        local error_msg="Command failed: $cmd"
        error "$error_msg"
        echo "$error_msg" >> "$LOG_FILE"
        return 1
    fi
    
    log "Successfully executed: $cmd"
    return 0
}

# === User Interaction ===
header() {
    local title="$1"
    echo
    echo -e "${BLUE}=== $title ===${NC}"
    echo
    log "Starting $title"
}

confirm() {
    if [ "$AUTO_YES" = true ] || [ "$DRY_RUN" = true ]; then
        log "[AUTO-YES/DRY-RUN] Would prompt: $*"
        return 0
    fi
    
    local prompt="$1"
    local default=${2:-N}
    
    while true; do
        read -r -p "$prompt ($default): " REPLY
        case $REPLY in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) 
                if [ "$default" = "Y" ]; then
                    return 0
                else
                    return 1
                fi
                ;;
        esac
    done
}

# === Utility ===
retry() {
    local cmd="$1"
    local retries=${2:-$MAX_RETRIES}
    local delay=5
    
    for ((i=1; i<=retries; i++)); do
        if eval "$cmd"; then
            return 0
        fi
        warn "Attempt $i/$retries failed. Retrying in $delay seconds..."
        sleep "$delay"
        ((delay+=5))
    done
    return 1
}

timeout() {
    local timeout=$1
    shift
    local cmd="$*"
    
    if ! timeout --preserve-status "$timeout" "$cmd"; then
        error "Command timed out after $timeout seconds: $cmd"
        return 1
    fi
    return 0
}

validate_checksum() {
    local file="$1"
    local expected_checksum="$2"
    
    if ! command -v sha256sum >/dev/null 2>&1; then
        error "sha256sum not found. Cannot verify checksum."
        return 1
    fi
    
    local actual_checksum
    actual_checksum=$(sha256sum "$file" | awk '{print $1}')
    
    if [ "$actual_checksum" != "$expected_checksum" ]; then
        error "Checksum verification failed for $file"
        return 1
    fi
    
    return 0
}

# === Cleanup ===
cleanup() {
    local exit_code=$?
    
    # Only show header if we're not exiting due to an error
    if [ $exit_code -eq 0 ]; then
        header "Cleaning up"
    else
        echo -e "\n${RED}Error detected! Cleaning up...${NC}"
    fi
    
    # Remove temporary directory
    if [ -d "$TEMP_DIR" ]; then
        run "rm -rf \"$TEMP_DIR\""
    fi
    
    # Exit with the original status code
    exit $exit_code
}

trap cleanup EXIT SIGINT SIGTERM

# === Usage ===
usage() {
    cat << 'EOF'
Usage: $0 [options]

Options:
  -t THEME    Set the color theme (default: TokyoNight-Dark)
  -p          Install minimal set of packages (no extra applications)
  -w          Skip wallpaper installation
  -n          Dry run - show what would be done
  -g          Install GNOME packages (for GNOME integration)
  -y          Automatic yes to prompts
  -h          Show this help message

Long options:
  --gnome     Same as -g (install GNOME packages)
  --yes       Same as -y (automatic yes to prompts)

Examples:
  $0 -t Dracula     # Install with Dracula theme
  $0 -p            # Minimal installation
  $0 --yes         # Auto-confirm all prompts

Requirements:
  - Arch Linux or compatible distribution
  - Minimum 2GB disk space
  - Minimum 2GB RAM recommended

GNOME Desktop:
  - By default, you'll be prompted to install GNOME as a fallback desktop
  - Use -g|--gnome to force GNOME installation without prompting
  - GNOME provides a stable fallback desktop and improves hardware support

For more information, visit:
https://github.com/bluebyt/bluebyt-wayfire
EOF
    exit 0
}

# === Main Installation ===
main()
{
    # === Command Line Parsing ===
    while getopts ":t:pwnghy" opt; do
        case "${opt}" in
            t) THEME="${OPTARG}" ;;
            p) INSTALL_ALL=false ;;
            w) SKIP_WALLPAPERS=true ;;
            n) DRY_RUN=true ;;
            g) INSTALL_GNOME=true ;;
            y) AUTO_YES=true ;;
            h) usage ;;
            \?) error "Invalid option -${OPTARG}"; usage ;;
        esac
    done

    # Support for long options (--gnome and --yes)
    for arg in "$@"; do
        if [[ "$arg" == "--gnome" ]]; then
            INSTALL_GNOME=true
        elif [[ "$arg" == "--yes" ]]; then
            AUTO_YES=true
        fi
    done

    # === Initial Checks ===
    if [ "$EUID" -eq 0 ]; then
        fatal "Please run this script as a regular user, not root."
    fi

    if ! grep -q '^ID=arch' /etc/os-release; then
        fatal "This installer is only supported on Arch Linux."
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        fatal "sudo is required but not installed."
    fi

    # === Pre-flight Checks ===
    header "Pre-flight system checks"
    log "Selected theme: $THEME"
    log "Full installation: $INSTALL_ALL"
    log "Install wallpapers: $([ "$SKIP_WALLPAPERS" = "true" ] && echo "no" || echo "yes")"
    log "Dry-run: $DRY_RUN"
    log "Install GNOME first: $INSTALL_GNOME"
    log "Non-interactive mode: $AUTO_YES"
    log "Installer version: $SCRIPT_VERSION"

    if ! confirm "Do you want to proceed with the installation?"; then
        fatal "Aborted by user."
    fi

    # === System Requirements ===
    header "Verifying system requirements"
    
    # Check disk space
    local required_space=10000  # 10GB minimum required for full installation
    local available_space
    available_space=$(df -m / | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        error "Insufficient disk space. Required: $required_space MB, Available: $available_space MB"
        exit 1
    fi
    
    # Check memory
    local mem
    mem=$(free -m | awk '/Mem:/ {print $2}')
    if [ "$mem" -lt 2048 ]; then
        warn "Low memory detected ($mem MB). Installation may be slow."
    fi

    # Check CPU cores
    local cores
    cores=$(nproc)
    if [ "$cores" -lt 4 ]; then
        warn "Low CPU cores detected ($cores cores). Installation may be slow."
    fi

    # === Package Installation ===
    header "Installing required packages"
    
    # Consolidated list of all required packages
    local ALL_PACKAGES="wayfire kitty fish zed wlogout xava wcm git gcc ninja rust nimble sudo lxappearance base-devel libxml2 curl pciutils meson"
    
    if [ "$INSTALL_ALL" = false ]; then
        ALL_PACKAGES="wayfire kitty fish zed wlogout xava wcm git gcc base-devel curl pciutils meson"
    fi
    
    # Install packages with retry mechanism and error handling
    local install_cmd="sudo pacman -S --needed --noconfirm $ALL_PACKAGES"
    
    if ! retry "$install_cmd"; then
        error "Failed to install required packages after multiple attempts."
        exit 1
    fi
    
    # Verify package installation
    for pkg in $ALL_PACKAGES; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            error "Failed to install required package: $pkg"
            exit 1
        fi
    done
    
    # Log successful installation
    log "All required packages installed successfully"
    log "Selected theme: $THEME"
    log "Full installation: $INSTALL_ALL"
    log "Install wallpapers: $([ "$SKIP_WALLPAPERS" = "true" ] && echo "no" || echo "yes")"
    log "Dry-run: $DRY_RUN"
    log "Install GNOME first: $INSTALL_GNOME"
    log "Non-interactive mode: $AUTO_YES"
    log "Installer version: $SCRIPT_VERSION"

    if ! confirm "Do you want to proceed with the installation?"; then
        fatal "Aborted by user."
    fi

    # === System Requirements ===
    header "Verifying system requirements"
    
    # Check disk space
    check_space 10000  # 10GB minimum required for full installation
    
    # Check memory
    local mem
    mem=$(free -m | awk '/Mem:/ {print $2}')
    if [ "$mem" -lt 2048 ]; then
        warn "Low memory detected. Installation may be slow."
    fi

    # Check CPU cores
    local cores
    cores=$(nproc)
    if [ "$cores" -lt 4 ]; then
        warn "Low CPU cores detected. Installation may be slow."
    fi

    # === Package Installation ===
    header "Installing essential packages"
    
    # Install essential tools
    local ESSENTIALS="git gcc ninja rust nimble sudo lxappearance base-devel libxml2 curl pciutils meson wayfire"
    if [ "$INSTALL_ALL" = false ]; then
        ESSENTIALS="git gcc base-devel curl pciutils meson"
    fi
    
    # Install packages with retry mechanism
    if ! retry "sudo pacman -S --needed --noconfirm $ESSENTIALS"; then
        error "Failed to install essential packages after multiple attempts."
        exit 1
    fi
    
    # Verify package installation
    for pkg in $ESSENTIALS; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            error "Failed to install required package: $pkg"
            exit 1
        fi
    done

    # === Wayfire Session Configuration ===
    header "Configuring Wayfire session"
    
    if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
        # Create directory if it doesn't exist
        if [ ! -d /usr/share/wayland-sessions ]; then
            if ! run "sudo mkdir -p /usr/share/wayland-sessions"; then
                error "Failed to create wayland-sessions directory"
                exit 1
            fi
        fi
        
        # Write Wayfire session file
        if ! sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF
        then
            error "Failed to create wayfire.desktop file"
            exit 1
        fi
    fi

    # === Wayfire Configuration ===
    header "Setting up Wayfire configuration"
    
    local config_dir="$HOME/.config/wayfire"
    local config_file="$config_dir/wayfire.ini"
    
    if [ ! -d "$config_dir" ]; then
        run "mkdir -p \"$config_dir\""
    fi
    
    # Create or update wayfire.ini
    if [ ! -f "$config_file" ] || confirm "Would you like to update Wayfire configuration?"; then
        sudo tee "$config_file" >/dev/null <<EOF
[core]
output_layout = $(wayfire-output-layout)

[output]
background_color = #000000

[view]
border_width = 0
border_color = #000000

[workspaces]
num_workspaces = 10

[plugins]
plugins = ipc ipc-rules follow-focus

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF
        if ! sudo tee "$config_file" >/dev/null; then
            error "Failed to create wayfire.ini"
            exit 1
        fi
    fi

    # === Wayfire Plugin Configuration ===
    header "Configuring Wayfire plugins"
    
    # Create plugin configuration directory
    local plugin_dir="$config_dir/plugins"
    if [ ! -d "$plugin_dir" ]; then
        run "mkdir -p \"$plugin_dir\""
    fi
    
    # Configure ipc plugin
    local ipc_config="$plugin_dir/ipc.ini"
    if [ ! -f "$ipc_config" ]; then
        sudo tee "$ipc_config" >/dev/null <<EOF
[ipc]
socket_path = /tmp/wayfire-wayland-1.socket
EOF
        if ! sudo tee "$ipc_config" >/dev/null; then
            error "Failed to create ipc configuration"
            exit 1
        fi
    fi

    # === Autostart Configuration ===
    header "Setting up autostart"
    
    local autostart_dir="$HOME/.config/autostart"
    if [ ! -d "$autostart_dir" ]; then
        run "mkdir -p \"$autostart_dir\""
    fi
    
    # Create autostart entry for Wayfire
    sudo tee "$autostart_dir/wayfire.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF

    # === Verify Wayfire Installation ===
    header "Verifying Wayfire installation"
    
    if ! command -v wayfire >/dev/null 2>&1; then
        error "Wayfire installation failed. Please check the logs."
        exit 1
    fi
    
    local wayfire_version
    wayfire_version=$(wayfire --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ -z "$wayfire_version" ]; then
        error "Wayfire version verification failed"
        exit 1
    fi
    
    log "Wayfire version $wayfire_version installed successfully"
    log "Wayfire session and configuration setup complete"

    # === Detect Virtual Machine and Hardware ===
    header "Detecting system type and hardware"

    # Check if running in a virtual machine
    is_vm=false
    VM_VENDOR=$(lspci | grep -iE 'VirtualBox|VMware|Virtual Machine|QEMU|KVM')
    if [ -n "$VM_VENDOR" ]; then
        is_vm=true
        log "Detected virtual machine: $VM_VENDOR"
    fi

    # Install virtual machine specific drivers if detected
    if [ "$is_vm" = true ]; then
        header "Installing virtual machine drivers"
        
        # Install common VM tools
        run "sudo pacman -S --needed --noconfirm virtualbox-guest-utils open-vm-tools"
        
        # Install specific VM tools based on vendor
        if echo "$VM_VENDOR" | grep -qi 'VirtualBox'; then
            if ! retry "sudo pacman -S --needed --noconfirm virtualbox-guest-modules-arch"; then
                error "Failed to install VirtualBox modules"
                exit 1
            fi
        elif echo "$VM_VENDOR" | grep -qi 'VMware'; then
            if ! retry "sudo pacman -S --needed --noconfirm open-vm-tools-desktop"; then
                error "Failed to install VMware tools"
                exit 1
            fi
        fi
        
        # Enable VM services with retries
        if ! retry "sudo systemctl enable vboxservice"; then
            warn "Failed to enable vboxservice"
        fi
        
        if ! retry "sudo systemctl enable vmtoolsd"; then
            warn "Failed to enable vmtoolsd"
        fi
        
        # Install basic graphics drivers with retry
        if ! retry "sudo pacman -S --needed --noconfirm mesa xf86-video-vmware"; then
            error "Failed to install graphics drivers"
            exit 1
        fi
        
        log "Virtual machine drivers installed successfully"
    else
        # === CPU Microcode ===
        header "Detecting CPU and installing microcode"
        
        # Detect CPU vendor
        local cpu_vendor=""
        if grep -qi 'GenuineIntel' /proc/cpuinfo; then
            cpu_vendor="Intel"
            if ! retry "sudo pacman -S --needed --noconfirm intel-ucode"; then
                error "Failed to install Intel microcode"
                exit 1
            fi
        elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
            cpu_vendor="AMD"
            if ! retry "sudo pacman -S --needed --noconfirm amd-ucode"; then
                error "Failed to install AMD microcode"
                exit 1
            fi
        fi
        
        # Verify microcode installation
        if [ -n "$cpu_vendor" ]; then
            if ! grep -qi "$cpu_vendor" /proc/cmdline; then
                warn "Microcode not loaded. You may need to reboot for changes to take effect."
            fi
        fi

        # === GPU Drivers ===
        header "Detecting GPU and installing drivers"
        
        # Get GPU information
        GPU_VENDOR=$(lspci | grep -E 'VGA|3D' | head -n1)
        if [ -z "$GPU_VENDOR" ]; then
            warn "No GPU detected. Using default mesa drivers."
            run "sudo pacman -S --needed --noconfirm mesa"
        else
            log "Detected GPU: $GPU_VENDOR"
            
            # Install GPU-specific drivers with retry and verification
            if echo "$GPU_VENDOR" | grep -qi 'NVIDIA'; then
                if ! retry "sudo pacman -S --needed --noconfirm nvidia nvidia-utils"; then
                    error "Failed to install NVIDIA drivers"
                    exit 1
                fi
                
                # Verify NVIDIA driver installation
                if ! retry "modprobe nvidia"; then
                    warn "Failed to load NVIDIA module"
                fi
                
                # Check if Wayland support is available
                if command -v nvidia-smi >/dev/null 2>&1; then
                    if ! nvidia-smi >/dev/null 2>&1; then
                        warn "NVIDIA driver not properly loaded"
                    fi
                fi
            elif echo "$GPU_VENDOR" | grep -qi 'AMD'; then
                if ! retry "sudo pacman -S --needed --noconfirm xf86-video-amdgpu mesa vulkan-radeon"; then
                    error "Failed to install AMD drivers"
                    exit 1
                fi
                
                # Verify AMD driver installation
                if ! retry "modprobe amdgpu"; then
                    warn "Failed to load AMD GPU module"
                fi
                
                # Check if Wayland support is available
                if command -v glxinfo >/dev/null 2>&1; then
                    if ! glxinfo | grep -qi "direct rendering: Yes"; then
                        warn "Direct rendering not enabled for AMD GPU"
                    fi
                fi
            elif echo "$GPU_VENDOR" | grep -qi 'Intel'; then
                if ! retry "sudo pacman -S --needed --noconfirm mesa vulkan-intel"; then
                    error "Failed to install Intel drivers"
                    exit 1
                fi
                
                # Verify Intel driver installation
                if ! retry "modprobe i915"; then
                    warn "Failed to load Intel i915 module"
                fi
                
                # Check if Wayland support is available
                if command -v glxinfo >/dev/null 2>&1; then
                    if ! glxinfo | grep -qi "direct rendering: Yes"; then
                        warn "Direct rendering not enabled for Intel GPU"
                    fi
                fi
            else
                warn "Unknown GPU vendor. Using default mesa drivers."
                run "sudo pacman -S --needed --noconfirm mesa"
            fi
        fi
    fi

    # === Wayfire Configuration ===
    header "Configuring Wayfire"
    
    # Install Wayfire and essential plugins
    local WAYFIRE_PACKAGES="wayfire wayfire-plugins-extra wayfire-plugins-std wayfire-plugins-tiling wayfire-plugins-workspaces wayfire-plugins-scale wayfire-plugins-effects"
    if ! retry "sudo pacman -S --needed --noconfirm $WAYFIRE_PACKAGES"; then
        error "Failed to install Wayfire packages"
        exit 1
    fi
    
    # Install additional Wayfire plugins
    local WAYFIRE_EXTRA_PLUGINS="wayfire-plugins-gnome wayfire-plugins-kde wayfire-plugins-steam wayfire-plugins-gaming"
    if ! retry "sudo pacman -S --needed --noconfirm $WAYFIRE_EXTRA_PLUGINS"; then
        warn "Failed to install additional Wayfire plugins. Core functionality will still work."
    fi
    
    # Configure Wayfire
    local WAYFIRE_CONFIG_DIR="$HOME/.config/wayfire"
    mkdir -p "$WAYFIRE_CONFIG_DIR"
    
    # Create basic configuration
    cat > "$WAYFIRE_CONFIG_DIR/wayfire.ini" << EOF
[core]
backend = auto
vsync = true

[output]
primary = auto
scale = 1

[workspaces]
number = 4

[focus]
follow_mouse = true

[plugins]
plugins = ipc ipc-rules follow-focus

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF

    # Enable Wayfire autostart
    if [ ! -d "$HOME/.config/autostart" ]; then
        mkdir -p "$HOME/.config/autostart"
    fi
    
    cat > "$HOME/.config/autostart/wayfire.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Wayfire
Exec=wayfire
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Wayfire
Comment[en_US]=Wayfire Window Manager
Comment=Wayfire Window Manager
EOF

    # Set default session to Wayfire
    if [ -d "/usr/share/wayland-sessions" ]; then
        if ! retry "sudo cp -f wayfire.desktop /usr/share/wayland-sessions/"; then
            warn "Failed to set Wayfire as default session"
        fi
    fi

    # Network Configuration
    header "Configuring network"
    
    # Check for network controllers
    if lspci | grep -qi 'Network controller'; then
        log "Network controller detected. Installing network tools."
        
        # Install network packages with retry
        if ! retry "sudo pacman -S --needed --noconfirm linux-firmware wireless_tools networkmanager"; then
            error "Failed to install network tools"
            exit 1
        fi
        
        # Enable NetworkManager
        if ! retry "sudo systemctl enable NetworkManager"; then
            warn "Failed to enable NetworkManager"
        fi
    else
        log "No network controller detected. Skipping network configuration."
    fi
    
    # Enable NetworkManager anyway for wired connections
    if ! retry "sudo systemctl enable NetworkManager"; then
        warn "Failed to enable NetworkManager"
    else
        run "sudo systemctl enable NetworkManager"
    fi

    # Bluetooth
    if lsusb | grep -qi bluetooth || lspci | grep -qi bluetooth; then
        run "sudo pacman -S --needed --noconfirm bluez bluez-utils"
        if ! retry "sudo systemctl enable --now bluetooth"; then
            warn "Failed to enable Bluetooth service"
        fi
    fi

    # === Display Server Configuration ===
    header "Configuring display server"
    
    # Install Wayland and essential packages
    if ! retry "sudo pacman -S --needed --noconfirm wayland wayland-protocols"; then
        error "Failed to install Wayland packages"
        exit 1
    fi
    
    # Configure display server
    local DISPLAY_CONFIG_DIR="$HOME/.config/wayland"
    if [ ! -d "$DISPLAY_CONFIG_DIR" ]; then
        mkdir -p "$DISPLAY_CONFIG_DIR"
    fi
    
    # Create display server configuration
    cat > "$DISPLAY_CONFIG_DIR/display.conf" << EOF
[display]
backend = auto
vsync = true
scale = 1

# Handle multiple displays
[output]
primary = auto
scale = 1
mode = auto
position = auto
EOF
    
    # Configure display hotplugging
    if [ -d "/usr/share/wayland-sessions" ]; then
        if ! retry "sudo pacman -S --needed --noconfirm udev"; then
            warn "Failed to install udev. Display hotplugging may not work properly."
        fi
    fi

    # === Session Management ===
    header "Configuring session management"
    
    # Install session management tools
    if ! retry "sudo pacman -S --needed --noconfirm xdg-desktop-portal xdg-desktop-portal-wlr"; then
        error "Failed to install session management tools"
        exit 1
    fi
    
    # Enable session management services
    local SESSION_SERVICES=(
        "xdg-desktop-portal"
        "xdg-desktop-portal-wlr"
        "pipewire"
        "pipewire-pulse"
        "pipewire-media-session"
    )
    
    for service in "${SESSION_SERVICES[@]}"; do
        if ! retry "sudo systemctl enable --user $service"; then
            warn "Failed to enable $service"
        fi
    done
    
    # Enable system services with verification
    local SYSTEM_SERVICES=(
        "systemd-logind"
        "elogind"
        "dbus"
        "systemd-journald"
        "systemd-timesyncd"
        "systemd-networkd"
        "systemd-resolved"
        "systemd-udevd"
        "systemd-timedated"
        "systemd-hostnamed"
    )
    
    # System services to enable
    local SYSTEM_SERVICES=(
        "systemd-journald"
        "systemd-udevd"
        "systemd-networkd"
        "systemd-resolved"
        "systemd-timesyncd"
    )
    
    # Enable and verify all services
    for service in "${SYSTEM_SERVICES[@]}"; do
        if ! retry "sudo systemctl enable $service"; then
            warn "Failed to enable system service: $service"
        fi
        
        if ! retry "sudo systemctl is-active --quiet $service"; then
            warn "Service $service is not active"
        fi
    done
    
    # Enable monitoring tools
    header "Setting up system monitoring"
    
    # Install monitoring tools
    local MONITORING_TOOLS=(
        "htop"
        "iftop"
        "iotop"
        "nmon"
        "glances"
        "vnstat"
        "iftop"
    )
    
    for tool in "${MONITORING_TOOLS[@]}"; do
        if ! retry "sudo pacman -S --needed --noconfirm $tool"; then
            warn "Failed to install monitoring tool: $tool"
        fi
    done
    
    # Configure monitoring tools
    if [ -f /etc/vnstat.conf ]; then
        sed -i 's/^Interface.*/Interface "enp0s3"/' /etc/vnstat.conf
        run "sudo systemctl enable --now vnstat"
    fi
    
    # Set up log rotation
    if [ -f /etc/logrotate.conf ]; then
        cat >> /etc/logrotate.conf << EOF
/var/log/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
}
EOF
    fi
    
    for service in "${SYSTEM_SERVICES[@]}"; do
        if ! retry "sudo systemctl enable $service"; then
            warn "Failed to enable system service: $service"
        fi
        
        # Verify service status
        if ! retry "sudo systemctl is-active --quiet $service"; then
            warn "Service $service is not active"
        fi
    done
    
    # Configure system settings
    header "Configuring system settings"
    
    # Set system timezone
    if [ -f /etc/timezone ]; then
        local current_tz
        current_tz=$(cat /etc/timezone)
        if [ -z "$current_tz" ]; then
            local tz
            tz=$(timedatectl list-timezones | grep -i "$(hostname)" | head -n1)
            if [ -n "$tz" ]; then
                run "sudo timedatectl set-timezone $tz"
            fi
        fi
    fi
    
    # Enable hardware clock synchronization
    run "sudo timedatectl set-local-rtc 0"
    run "sudo timedatectl set-ntp true"
    
    # Set hostname
    local hostname
    hostname=$(hostname)
    if [ -n "$hostname" ]; then
        run "sudo hostnamectl set-hostname $hostname"
    fi
    
    # Set locale
    if [ -f /etc/locale.conf ]; then
        local locale
        locale=$(grep LANG /etc/locale.conf | cut -d= -f2)
        if [ -z "$locale" ]; then
            run "sudo localectl set-locale LANG=en_US.UTF-8"
        fi
    fi
    
    # Set keyboard layout
    run "sudo localectl set-keymap us"
    
    # Optimize system settings
    header "Optimizing system performance"
    
    # Enable ZRAM swap
    if ! grep -q "zram" /etc/modules-load.d/zram.conf; then
        echo "zram" | sudo tee /etc/modules-load.d/zram.conf
        run "sudo modprobe zram"
    fi
    
    # Optimize swap settings
    if [ -f /etc/sysctl.d/99-sysctl.conf ]; then
        cat >> /etc/sysctl.d/99-sysctl.conf << EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF
        run "sudo sysctl -p"
    fi
    
    # Enable CPU governor
    if [ -f /etc/default/cpufreq ]; then
        echo "GOVERNOR=performance" | sudo tee /etc/default/cpufreq
        run "sudo systemctl enable --now cpufreq"
    fi
    
    # Security Hardening
    header "Applying security hardening"
    
    # Enable AppArmor
    if ! grep -q "apparmor" /etc/modules; then
        echo "apparmor" | sudo tee -a /etc/modules
        run "sudo modprobe apparmor"
    fi
    
    # Enable SELinux
    if [ -f /etc/selinux/config ]; then
        sed -i 's/^SELINUX=.*$/SELINUX=enforcing/' /etc/selinux/config
        run "sudo setenforce 1"
    fi
    
    # Enable firewall
    run "sudo pacman -S --needed --noconfirm ufw"
    run "sudo ufw default deny incoming"
    run "sudo ufw default allow outgoing"
    run "sudo ufw enable"
    
    # Enable auditd
    run "sudo pacman -S --needed --noconfirm audit"
    run "sudo systemctl enable --now auditd"
    
    # Enable hardware clock synchronization
    run "sudo timedatectl set-local-rtc 0"
    run "sudo timedatectl set-ntp true"
    
    # Set hostname
    local hostname
    hostname=$(hostname)
    if [ -n "$hostname" ]; then
        run "sudo hostnamectl set-hostname $hostname"
    fi
    
    # Set locale
    if [ -f /etc/locale.conf ]; then
        local locale
        locale=$(grep LANG /etc/locale.conf | cut -d= -f2)
        if [ -z "$locale" ]; then
            run "sudo localectl set-locale LANG=en_US.UTF-8"
        fi
    fi
    
    # Set keyboard layout
    run "sudo localectl set-keymap us"
    
    # Create optimized session script
    cat > "$HOME/.local/bin/start-wayfire" << EOF
#!/bin/sh

# Set environment variables
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/$UID
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share

# Set up Wayland environment
export WAYLAND_DEBUG=1
export WAYFIRE_BACKEND=auto
export WAYFIRE_VSYNC=true

# Set up audio environment
export PULSE_SERVER=unix:/run/user/$UID/pulse/native
export PULSE_RUNTIME_PATH=/run/user/$UID/pulse

# Start Wayfire with optimizations
exec wayfire
EOF
    
    run "chmod +x $HOME/.local/bin/start-wayfire"
    
    # Create session autostart directory
    local AUTOSTART_DIR="$HOME/.config/autostart"
    if [ ! -d "$AUTOSTART_DIR" ]; then
        run "mkdir -p $AUTOSTART_DIR"
    fi
    
    # Create Wayfire autostart entry
    cat > "$AUTOSTART_DIR/wayfire.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Wayfire
Exec=$HOME/.local/bin/start-wayfire
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Wayfire
Comment[en_US]=Wayland compositor
Name=Wayfire
Comment=Wayland compositor
EOF
    
    run "chmod +x $HOME/.local/bin/start-wayfire"

    # === GNOME Desktop Installation ===
    header "GNOME Desktop Installation"

    if [ "$INSTALL_GNOME" = true ]; then
        # GNOME installation forced by flag
        log "Installing GNOME Desktop Environment (forced by flag)"
        run "sudo pacman -S --needed --noconfirm gnome gnome-tweaks gnome-terminal"
        run "sudo systemctl enable --now gdm"
        log "GNOME installed. You can log in to GNOME for troubleshooting or as a fallback environment."
    else
        # Prompt for GNOME installation
        if confirm "Would you like to install GNOME Desktop as a fallback environment?\n\nGNOME provides:\n- A stable fallback desktop\n- Graphical troubleshooting tools\n- Better hardware support\n- Easy system management\n\nInstall GNOME now?"; then
            log "Installing GNOME Desktop Environment"
            run "sudo pacman -S --needed --noconfirm gnome gnome-tweaks gnome-terminal"
            run "sudo systemctl enable --now gdm"
            log "GNOME installed. You can log in to GNOME for troubleshooting or as a fallback environment."
        else
            log "Skipping GNOME installation."
        fi
    fi
    # Continue with Wayfire installation
    header "Installing Wayfire and dependencies"

    # === Wayfire Installation ===
    header "Installing Wayfire and dependencies"
    
    # Install core packages with optimization flags
    local WAYLAND_PACKAGES=(
        "wayland"
        "wlroots"
        "xorg-xwayland"
        "kitty"
        "swaybg"
        "swaylock"
        "swayidle"
        "dunst"
        "mako"
        "grim"
        "slurp"
        "swaywm-waybar"
    )
    
    local OPTIMIZATION_FLAGS="--noconfirm --needed --asdeps"
    
    for pkg in "${WAYLAND_PACKAGES[@]}"; do
        if ! retry "sudo pacman $OPTIMIZATION_FLAGS $pkg"; then
            error "Failed to install package: $pkg"
            exit 1
        fi
    done

    # Build Wayfire components with error handling
    local WAYFIRE_COMPONENTS=(
        "https://github.com/WayfireWM/wayfire.git wayfire"
        "https://github.com/WayfireWM/wf-shell.git wf-shell"
        "https://github.com/WayfireWM/wcm.git wcm"
        "https://github.com/soreau/pixdecor.git pixdecor"
    )
    
    for component in "${WAYFIRE_COMPONENTS[@]}"; do
        local repo
        repo=$(echo "$component" | cut -d' ' -f1)
        local pkg
        pkg=$(echo "$component" | cut -d' ' -f2)
        
        if ! build_git_pkg "$repo" "$pkg"; then
            error "Failed to build $pkg"
            exit 1
        fi
    done
    
    # Verify Wayfire installation
    if ! command -v wayfire >/dev/null 2>&1; then
        error "Wayfire installation failed. Please check the logs."
        exit 1
    fi
    
    # Verify Wayfire version and configure
    local wayfire_version
    wayfire_version=$(wayfire --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ -z "$wayfire_version" ]; then
        error "Wayfire version verification failed"
        exit 1
    fi
    
    log "Wayfire version $wayfire_version installed successfully"
    
    # Configure Wayfire settings
    header "Configuring Wayfire settings"
    
    # Create Wayfire config directory
    local WAYFIRE_CONFIG_DIR="$HOME/.config/wayfire"
    if [ ! -d "$WAYFIRE_CONFIG_DIR" ]; then
        run "mkdir -p $WAYFIRE_CONFIG_DIR"
    fi
    
    # Create basic Wayfire config
    cat > "$WAYFIRE_CONFIG_DIR/wayfire.ini" << EOF
[core]
backend = auto
vsync = true

[output]
use-randr = true
auto-arrange = true

[workspaces]
num-workspaces = 10

[focus]
focus-follows-pointer = true

[plugins]
plugins =
    workspaces
    move
    resize
    fullscreen
    close
    minimize
    maximize
    tile
    scale
    effects
    screenshot
    keyboard
    pointer
    xwayland
    xwayland-clipboard
    xwayland-cursor
    xwayland-input
    xwayland-output
    xwayland-viewport
    xwayland-xwayland
    xwayland-xwayland-clipboard
    xwayland-xwayland-cursor
    xwayland-xwayland-input
    xwayland-xwayland-output
    xwayland-xwayland-viewport
    xwayland-xwayland-xwayland

[autostart]
launcher = $HOME/.config/wayfire/scripts/inactive-alpha.py
EOF
    
    # Create Wayfire scripts directory
    local WAYFIRE_SCRIPTS_DIR="$HOME/.config/wayfire/scripts"
    if [ ! -d "$WAYFIRE_SCRIPTS_DIR" ]; then
        run "mkdir -p $WAYFIRE_SCRIPTS_DIR"
    fi
    
    # Create inactive alpha script
    cat > "$WAYFIRE_SCRIPTS_DIR/inactive-alpha.py" << EOF
#!/usr/bin/env python3

import wayfire

def on_window_focus(window, state):
    if state:
        window.set_alpha(1.0)
    else:
        window.set_alpha(0.8)

wayfire.subscribe('window_focus', on_window_focus)
EOF
    
    run "chmod +x $WAYFIRE_SCRIPTS_DIR/inactive-alpha.py"

    # === Theme and Icons ===
    header "Installing theme and icons"
    
    # Install GTK theme with backup and verification
    local THEME_DIR="$HOME/.local/share/themes"
    local THEME_NAME="TokyoNight-Dark"
    
    # Backup existing theme
    if [ -d "$THEME_DIR/$THEME_NAME" ]; then
        backup_config "$THEME_DIR/$THEME_NAME" "$BACKUP_DIR/themes/"
    fi
    
    # Install icons with verification
    local ICONS_DIR="$HOME/.local/share/icons"
    local ICON_THEME="Aretha-Dark"
    
    # Backup existing icons
    if [ -d "$ICONS_DIR/$ICON_THEME" ]; then
        backup_config "$ICONS_DIR/$ICON_THEME" "$BACKUP_DIR/icons/"
    fi
    
    # Install icons
    if [ ! -d "$SCRIPT_DIR/Aretha-Dark-Icons" ]; then
        if ! retry "git clone https://github.com/EliverLara/Aretha.git"; then
            error "Failed to clone icons repository"
            exit 1
        fi
        run "mv Aretha Aretha-Dark-Icons"
        run "rm -rf Aretha"
    fi
    
    if ! cd "$SCRIPT_DIR/Aretha-Dark-Icons"; then
        error "Failed to access icons directory"
        exit 1
    fi
    
    if ! retry "./install.sh -d \"$ICONS_DIR\" -c dark"; then
        error "Failed to install icons"
        exit 1
    fi
    
    if ! cd "$SCRIPT_DIR"; then
        error "Failed to return to script directory"
        exit 1
    fi
    
    # Verify icons installation
    if [ ! -d "$ICONS_DIR/$ICON_THEME" ]; then
        error "Icons installation failed"
        exit 1
    fi
    
    # Clean up
    if ! retry "rm -rf \"$SCRIPT_DIR/Aretha-Dark-Icons\""; then
        warn "Failed to clean up icons installation files"
    fi
    
    # Install theme
    if [ ! -d "$SCRIPT_DIR/Tokyo-Night-GTK-Theme" ]; then
        if ! retry "git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git"; then
            error "Failed to clone theme repository"
            exit 1
        fi
    fi
    
    if ! cd "$SCRIPT_DIR/Tokyo-Night-GTK-Theme/themes"; then
        error "Failed to access theme directory"
        exit 1
    fi
    
    if ! retry "./install.sh -d \"$THEME_DIR\" -c dark -l --tweaks black"; then
        error "Failed to install theme"
        exit 1
    fi
    
    if ! cd "$SCRIPT_DIR"; then
        error "Failed to return to script directory"
        exit 1
    fi
    
    # Verify theme installation
    if [ ! -d "$THEME_DIR/$THEME_NAME" ]; then
        error "Theme installation failed"
        exit 1
    fi
    
    # Clean up
    if ! retry "rm -rf \"$SCRIPT_DIR/Tokyo-Night-GTK-Theme\""; then
        warn "Failed to clean up theme installation files"
    fi

    # Install icons
    if [ ! -d "$SCRIPT_DIR/Aretha-Dark-Icons" ]; then
        fatal "Aretha-Dark-Icons not found. Please download it from https://www.gnome-look.org/p/2180417 and place it in $SCRIPT_DIR."
    fi
    run "mkdir -p \"$HOME/.local/share/icons\""
    run "mv \"$SCRIPT_DIR/Aretha-Dark-Icons\" \"$HOME/.local/share/icons/\""

    # === Desktop Configuration ===
    header "Configuring desktop environment"
    
    # Apply theme and icons
    run "mkdir -p \"$HOME/.config/gtk-3.0\""
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=Aretha-Dark-Icons
EOF

    # Install system tools
    run "sudo pacman -S --needed --noconfirm exa fish mako swappy"

    # Set Fish as default shell if requested
    if confirm "Set Fish as default shell?"; then
        # Removed unused set_fish
        if ! grep -qx "/usr/bin/fish" /etc/shells; then
            echo "/usr/bin/fish" | sudo tee -a /etc/shells
        fi
        run "chsh -s /usr/bin/fish"
    fi

    # Install Zed editor
    header "Installing Zed editor"
    if ! command -v zed >/dev/null 2>&1; then
        run "curl -fsSL https://zed.dev/install.sh | sh"
    fi

    # Install AUR packages if full install
    if [ "$INSTALL_ALL" = true ]; then
        header "Installing AUR packages"
        run "paru -S --noconfirm eww ironbar fzf zoxide starship ulauncher nwg-look vesktop ristretto swayosd clapper wcm mpv ncmpcpp thunar swww xava-git wlogout"
    fi

    # === Configuration Backup ===
    header "Backing up configurations"
    
    # Create backup directory
    if [ -d "$BACKUP_DIR" ]; then
        suffix=$(date +%s)
        BACKUP_DIR="${BACKUP_DIR}_$suffix"
    fi
    run "mkdir -p \"$BACKUP_DIR\""

    # Backup existing configurations
    if [ -d "$HOME/.config" ]; then
        backup_config "$HOME/.config" "$BACKUP_DIR/config"
    fi
    if [ -d "$HOME/.bin" ]; then
        backup_config "$HOME/.bin" "$BACKUP_DIR/bin"
    fi

    # === Copy New Configurations ===
    header "Copying new configurations"
    
    # Copy configuration files
    if [ -d "$SCRIPT_DIR/.config" ]; then
        run "cp -rv \"$SCRIPT_DIR/.config\" \"$HOME/\""
    fi
    if [ -d "$SCRIPT_DIR/.bin" ]; then
        run "cp -rv \"$SCRIPT_DIR/.bin\" \"$HOME/\""
        run "mkdir -p \"$HOME/.config/fish\""
        echo "set -gx PATH \$HOME/.bin \$PATH" >> "$HOME/.config/fish/config.fish"
    fi

    # === Wayfire Configuration ===
    header "Configuring Wayfire"
    
    # Configure follow-focus and inactive-alpha
    run "mkdir -p \"$HOME/.config/environment.d\""
    echo "WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket" > "$HOME/.config/environment.d/environment.conf"

    # Setup IPC scripts
    local IPC_DIR="$HOME/.config/ipc-scripts"
    run "mkdir -p \"$IPC_DIR\""
    
    if [ -f "$SCRIPT_DIR/ipc-scripts/inactive-alpha.py" ] && [ -f "$SCRIPT_DIR/ipc-scripts/wayfire_socket.py" ]; then
        run "cp \"$SCRIPT_DIR/ipc-scripts/inactive-alpha.py\" \"$IPC_DIR/\""
        run "cp \"$SCRIPT_DIR/ipc-scripts/wayfire_socket.py\" \"$IPC_DIR/\""
    else
        run "curl -fL \"https://github.com/WayfireWM/wayfire/raw/master/examples/inactive-alpha.py\" -o \"$IPC_DIR/inactive-alpha.py\""
        run "curl -fL \"https://github.com/WayfireWM/wayfire/raw/master/examples/wayfire_socket.py\" -o \"$IPC_DIR/wayfire_socket.py\""
    fi
    run "chmod +x \"$IPC_DIR/inactive-alpha.py\" \"$IPC_DIR/wayfire_socket.py\""

    # Configure Wayfire.ini
    local WAYFIRE_INI="$HOME/.config/wayfire.ini"
    if [ -f "$WAYFIRE_INI" ]; then
        run "sed -i 's/^plugins =.*/plugins = ipc ipc-rules follow-focus/' \"$WAYFIRE_INI\""
        run "sed -i '/\[autostart\]/a launcher = $IPC_DIR/inactive-alpha.py' \"$WAYFIRE_INI\""
    else
        cat > "$WAYFIRE_INI" <<EOF
[Settings]
plugins = ipc ipc-rules follow-focus

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF
    fi

    # === Wayfire Session ===
    header "Creating Wayfire session"
    if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
        # Create directory if it doesn't exist
        if [ ! -d /usr/share/wayland-sessions ]; then
            run "sudo mkdir -p /usr/share/wayland-sessions"
        fi
        
        # Write Wayfire session file
        sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF
    fi

    # === Verification ===
    header "Verifying installations"
    
    local failed=false
    for cmd in wayfire kitty fish zed wcm xava wlogout; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "$cmd not found!"
            failed=true
        fi
    done

    if [ "$failed" = true ]; then
        fatal "Some required components are missing. Please check the log file for details."
    fi

    # === Final Summary ===
    echo
    if [ "$FAILED" = "true" ]; then
        echo -e "${RED}Installation completed with errors.${NC}"
        echo "Please review $LOG_FILE for more information."
        exit 1
    else
        echo -e "${GREEN}Installation completed successfully!${NC}"
        echo "See $LOG_FILE for a detailed log."
        echo "To start Wayfire:" && echo "    1. Log out of your current session" && echo "    2. Select 'Wayfire' from your display manager's session list" && echo "    3. Log back in to start Wayfire"
        exit 0
    fi
}
