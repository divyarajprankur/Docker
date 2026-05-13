#!/bin/bash

# Docker Comprehensive Cleanup Script
# For Docker Engine 29.4.2 with containerd image store
# Created: May 6, 2026

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo "  -y, --yes      Automatically answer yes to all prompts"
    echo "  -a, --aggressive    Includes volume pruning (DANGER: data loss)"
    echo "  -v, --verbose  Show verbose output"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # Interactive mode (safe)"
    echo "  $SCRIPT_NAME -y           # Auto yes mode (safe)"
    echo "  $SCRIPT_NAME -y -a        # Auto yes + aggressive (DANGER)"
    exit 0
}

# Initialize variables
AUTO_YES=false
AGGRESSIVE=false
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
print_color "==========================================" "$BLUE"
print_color "    Docker Comprehensive Cleanup Script    " "$BLUE"
print_color "==========================================" "$BLUE"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_color "❌ Error: Docker is not running or not installed" "$RED"
    exit 1
fi

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

# Confirm cleanup
if [ "$AUTO_YES" = false ]; then
    print_color "⚠️  This script will clean up unused Docker resources." "$YELLOW"
    if [ "$AGGRESSIVE" = true ]; then
        print_color "⚠️  AGGRESSIVE MODE: WILL DELETE UNUSED VOLUMES (potential data loss)!" "$RED"
    else
        print_color "✅ SAFE MODE: Will NOT delete volumes (data safe)" "$GREEN"
    fi
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color "❌ Cleanup cancelled" "$RED"
        exit 0
    fi
fi

# Start cleanup
print_color "🧹 Starting Docker cleanup..." "$BLUE"
echo ""

# 1. Clean up containers (stopped)
print_color "1️⃣ Cleaning up stopped containers..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker container prune --force
else
    docker container prune
fi
echo ""

# 2. Clean up images
print_color "2️⃣ Cleaning up unused images..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker image prune --all --force
else
    docker image prune --all
fi
echo ""

# 3. Clean up networks
print_color "3️⃣ Cleaning up unused networks..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker network prune --force
else
    docker network prune
fi
echo ""

# 4. Clean up build cache
print_color "4️⃣ Cleaning up build cache..." "$GREEN"
if [ "$AUTO_YES" = true ]; then
    docker builder prune --all --force
else
    docker builder prune --all
fi
echo ""

# 5. Clean up volumes (only in aggressive mode)
if [ "$AGGRESSIVE" = true ]; then
    print_color "5️⃣ Cleaning up unused volumes (AGGRESSIVE MODE)..." "$RED"
    print_color "⚠️  WARNING: This will delete persistent data!" "$RED"
    
    if [ "$AUTO_YES" = false ]; then
        read -p "Are you ABSOLUTELY sure you want to delete volumes? (yes/NO): " confirm_volumes
        if [ "$confirm_volumes" != "yes" ]; then
            print_color "❌ Volume cleanup skipped" "$YELLOW"
        else
            docker volume prune --force
        fi
    else
        docker volume prune --force
    fi
    echo ""
else
    print_color "5️⃣ Skipping volume cleanup (use -a flag for aggressive mode)" "$YELLOW"
    echo ""
fi

# 6. System-wide prune (comprehensive)
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

# Display cleaned disk usage
print_color "📊 Disk Usage After Cleanup:" "$GREEN"
print_color "----------------------------------------" "$GREEN"
docker system df
echo ""

# Show reclaimable space summary
print_color "✅ Cleanup completed successfully!" "$GREEN"
echo ""

# Additional tips
print_color "💡 Tips to save more space:" "$YELLOW"
echo "  - Limit container logs: --log-opt max-size=10m --log-opt max-file=3"
echo "  - Use .dockerignore files in builds"
echo "  - Regularly run: docker system prune -a"
echo "  - Consider smaller base images (alpine, slim variants)"
echo ""

# Check for large directories
print_color "🔍 Checking for large Docker directories..." "$YELLOW"
echo ""

if [ -d "/var/lib/docker" ]; then
    DOCKER_SIZE=$(du -sh /var/lib/docker 2>/dev/null | cut -f1)
    echo "  /var/lib/docker: $DOCKER_SIZE"
fi

if [ -d "/var/lib/containerd" ]; then
    CONTAINERD_SIZE=$(du -sh /var/lib/containerd 2>/dev/null | cut -f1)
    echo "  /var/lib/containerd: $CONTAINERD_SIZE"
fi

echo ""

print_color "✨ Script finished!" "$GREEN"
