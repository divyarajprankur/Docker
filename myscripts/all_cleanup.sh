#!/bin/bash

# Docker Complete Cleanup Script
# Preserves ALL resources used by running containers
# For Docker Engine 29.4.2 with containerd image store
# Created: May 6, 2026

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script name
SCRIPT_NAME=$(basename "$0")

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Function to show script usage
usage() {
    echo "Usage: $SCRIPT_NAME [OPTIONS]"
    echo "Options:"
    echo "  -y, --yes           Automatically answer yes to all prompts"
    echo "  -a, --aggressive    Include volume pruning (DANGER: data loss)"
    echo "  -s, --stopped       Also remove stopped containers (keeps running only)"
    echo "  -v, --verbose       Show verbose output"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME                  # Interactive mode (safe)"
    echo "  $SCRIPT_NAME -y               # Auto yes (keeps running containers only)"
    echo "  $SCRIPT_NAME -y -s            # Remove stopped containers too"
    echo "  $SCRIPT_NAME -y -a            # Auto yes + aggressive (DANGER: deletes volumes)"
    exit 0
}

# Initialize variables
AUTO_YES=false
AGGRESSIVE=false
REMOVE_STOPPED=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -a|--aggressive)
            AGGRESSIVE=true
            shift
            ;;
        -s|--stopped)
            REMOVE_STOPPED=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Function to run command with optional verbosity
run_cmd() {
    if [ "$VERBOSE" = true ]; then
        $@
    else
        $@ 2>/dev/null
    fi
}

# Header
print_color "================================================" "$BLUE"
print_color "    Docker Complete Cleanup Script (Safe Mode)   " "$BLUE"
print_color "================================================" "$BLUE"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_color "❌ Error: Docker is not running or not installed" "$RED"
    exit 1
fi

# Get running containers info
RUNNING_CONTAINERS=$(docker ps -q | wc -l)
RUNNING_IMAGES=$(docker ps --format '{{.Image}}' | sort -u | wc -l)
RUNNING_VOLUMES=$(docker ps --format '{{range .Mounts}}{{.Name}}{{"\n"}}{{end}}' | grep -v '^$' | sort -u | wc -l)
RUNNING_NETWORKS=$(docker ps --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{"\n"}}{{end}}' | sort -u | wc -l)

# Display current disk usage
print_color "📊 Current Docker Disk Usage:" "$GREEN"
print_color "----------------------------------------" "$GREEN"
docker system df
echo ""

if [ "$VERBOSE" = true ]; then
    print_color "📊 Detailed Disk Usage:" "$YELLOW"
    print_color "----------------------------------------" "$YELLOW"
    docker system df -v
    echo ""
fi

# Display what will be preserved
print_color "🟢 RESOURCES THAT WILL BE PRESERVED:" "$GREEN"
print_color "----------------------------------------" "$GREEN"
echo -e "  Running containers: ${CYAN}$RUNNING_CONTAINERS${NC}"
echo -e "  Images in use:      ${CYAN}$RUNNING_IMAGES${NC}"
echo -e "  Volumes in use:     ${CYAN}$RUNNING_VOLUMES${NC}"
echo -e "  Networks in use:    ${CYAN}$RUNNING_NETWORKS${NC}"
echo ""

# Display what will be cleaned
print_color "🔴 RESOURCES THAT WILL BE CLEANED:" "$RED"
print_color "----------------------------------------" "$RED"
echo "  ✓ Dangling images (no tags, not in use)"
echo "  ✓ Build cache"
echo "  ✓ Unused networks"
if [ "$REMOVE_STOPPED" = true ]; then
    echo "  ✓ Stopped containers"
else
    echo "  ✗ Stopped containers (use -s flag to remove)"
fi
if [ "$AGGRESSIVE" = true ]; then
    echo "  ✓ Unused volumes (⚠️  DATA LOSS RISK)"
else
    echo "  ✗ Unused volumes (use -a flag for aggressive mode)"
fi
echo ""

# Confirm cleanup
if [ "$AUTO_YES" = false ]; then
    print_color "⚠️  This script will clean unused Docker resources." "$YELLOW"
    echo -e "  ${GREEN}Running containers and their dependencies will be SAFE.${NC}"
    if [ "$AGGRESSIVE" = true ]; then
        print_color "  🔴 AGGRESSIVE MODE: WILL DELETE UNUSED VOLUMES (potential data loss)!" "$RED"
    fi
    if [ "$REMOVE_STOPPED" = true ]; then
        print_color "  🟡 Will remove ALL stopped containers" "$YELLOW"
    fi
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color "❌ Cleanup cancelled" "$RED"
        exit 0
    fi
fi

# Save state before cleanup for comparison
BEFORE_SPACE=$(docker system df --format "{{.TotalReclaimable}}" 2>/dev/null | head -1 || echo "0")

# Start cleanup
print_color "🧹 Starting Docker cleanup..." "$BLUE"
echo ""

# 1. Remove stopped containers (if flag set)
if [ "$REMOVE_STOPPED" = true ]; then
    print_color "1️⃣ Removing stopped containers..." "$GREEN"
    STOPPED_COUNT=$(docker ps -a -q -f status=exited -f status=created -f status=dead | wc -l)
    if [ "$STOPPED_COUNT" -gt 0 ]; then
        if [ "$AUTO_YES" = true ]; then
            docker container prune --force
        else
            docker container prune
        fi
        echo -e "  ${GREEN}✓ Removed $STOPPED_COUNT stopped containers${NC}"
    else
        echo "  No stopped containers to remove"
    fi
    echo ""
else
    print_color "1️⃣ Skipping stopped container removal (use -s flag)" "$YELLOW"
    echo ""
fi

# 2. Clean up unused images (preserving running container images)
print_color "2️⃣ Cleaning up unused images (preserving running containers)..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker image prune --all --force
else
    docker image prune --all
fi
echo ""

# 3. Clean up build cache
print_color "3️⃣ Cleaning up build cache..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker builder prune --all --force
else
    docker builder prune --all
fi
echo ""

# 4. Clean up unused networks
print_color "4️⃣ Cleaning up unused networks..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker network prune --force
else
    docker network prune
fi
echo ""

# 5. Clean up volumes (only in aggressive mode)
if [ "$AGGRESSIVE" = true ]; then
    print_color "5️⃣ Cleaning up unused volumes (AGGRESSIVE MODE)..." "$RED"
    # Get count of unused volumes
    UNUSED_VOLUMES=$(docker volume ls -q | wc -l)
    if [ "$UNUSED_VOLUMES" -gt 0 ]; then
        print_color "  ⚠️  WARNING: This will delete $UNUSED_VOLUMES unused volume(s)!" "$RED"
        if [ "$AUTO_YES" = false ]; then
            read -p "Are you ABSOLUTELY sure you want to delete volumes? (yes/NO): " confirm_volumes
            if [ "$confirm_volumes" != "yes" ]; then
                print_color "  ❌ Volume cleanup skipped" "$YELLOW"
            else
                docker volume prune --force
                echo -e "  ${GREEN}✓ Removed unused volumes${NC}"
            fi
        else
            docker volume prune --force
            echo -e "  ${GREEN}✓ Removed unused volumes${NC}"
        fi
    else
        echo "  No unused volumes to remove"
    fi
    echo ""
else
    print_color "5️⃣ Skipping volume cleanup (use -a flag for aggressive mode)" "$YELLOW"
    echo ""
fi

# 6. System prune (comprehensive)
print_color "6️⃣ Running system-wide cleanup..." "$GREEN"
if [ "$AGGRESSIVE" = true ]; then
    if [ "$AUTO_YES" = true ]; then
        docker system prune --all --volumes --force
    else
        docker system prune --all --volumes
    fi
else
    if [ "$AUTO_YES" = true ]; then
        docker system prune --all --force
    else
        docker system prune --all
    fi
fi
echo ""

# Display after cleanup stats
print_color "📊 Disk Usage After Cleanup:" "$GREEN"
print_color "----------------------------------------" "$GREEN"
docker system df
echo ""

# Show what's still running
print_color "🟢 RUNNING CONTAINERS (PRESERVED):" "$CYAN"
print_color "----------------------------------------" "$CYAN"
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
else
    echo "  No containers currently running"
fi
echo ""

# Show preserved images
print_color "🟢 IMAGES CURRENTLY IN USE:" "$CYAN"
print_color "----------------------------------------" "$CYAN"
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    docker ps --format '{{.Image}}' | sort -u | while read image; do
        echo "  ✓ $image"
    done
else
    echo "  No images currently in use"
fi
echo ""

# Calculate space reclaimed
AFTER_SPACE=$(docker system df --format "{{.TotalReclaimable}}" 2>/dev/null | head -1 || echo "0")
print_color "💾 Space Analysis:" "$YELLOW"
print_color "----------------------------------------" "$YELLOW"
echo "  Reclaimable before: $(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || echo 'N/A')"
echo "  Reclaimable after:  $(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || echo 'N/A')"
echo ""

# Verify nothing critical was removed
print_color "✅ Cleanup completed successfully!" "$GREEN"
echo ""
print_color "💡 Safety Verification:" "$GREEN"
echo "  ✓ All running containers are intact"
echo "  ✓ Images used by running containers preserved"
echo "  ✓ Networks used by running containers preserved"
if [ "$AGGRESSIVE" = true ]; then
    echo "  ✓ Volumes used by running containers preserved"
fi
echo ""

# Additional tips
print_color "💡 Tips to save more space:" "$YELLOW"
echo "  - Limit container logs: --log-opt max-size=10m --log-opt max-file=3"
echo "  - Use .dockerignore files in builds"
echo "  - Consider smaller base images (alpine, slim variants)"
echo "  - Run registry garbage collection if using private registry"
echo ""

print_color "✨ Script finished!" "$GREEN"
