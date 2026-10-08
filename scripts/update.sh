#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

readonly RELEASE_API="https://delta.dev/api/releases/stable/latest/asset"
readonly RELEASE_BASE="https://releases.delta.dev/releases/stable"
readonly SOURCES_FILE="sources.json"

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

flake_ref() {
    echo "path:$(pwd -P)#delta-dev"
}

flake_path() {
    echo "path:$(pwd -P)"
}

get_current_version() {
    jq -r .version "$SOURCES_FILE"
}

get_latest_version() {
    local version
    version=$(curl -fsSL "$RELEASE_API?asset=delta&os=linux&arch=x86_64" | jq -r .version 2>/dev/null || echo "")
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        log_error "Failed to fetch latest version from delta.dev"
        exit 1
    fi
    echo "$version"
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "$SOURCES_FILE" ]; then
        log_error "flake.nix or $SOURCES_FILE not found. Run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_error "jq is required but not installed."; exit 1; }
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to a specific version"
    echo "  --check            Only check for updates"
    echo "  --help             Show this help message"
}

parse_arguments() {
    local target_version=""
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                target_version="$2"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    echo "$target_version|$check_only"
}

platform_path() {
    case "$1" in
        x86_64-linux) echo "delta-linux-x86_64.tar.gz" ;;
        aarch64-linux) echo "delta-linux-aarch64.tar.gz" ;;
        aarch64-darwin) echo "macos/aarch64/Delta.app.zip" ;;
    esac
}

prefetch_hash() {
    nix store prefetch-file --json "$1" | jq -r .hash
}

write_sources() {
    local version="$1"
    local platforms="{}"
    local system url hash

    for system in x86_64-linux aarch64-linux aarch64-darwin; do
        url="$RELEASE_BASE/$version/$(platform_path "$system")"
        log_info "Prefetching $system"
        hash=$(prefetch_hash "$url")
        platforms=$(jq --arg s "$system" --arg u "$url" --arg h "$hash" \
            '. + {($s): {url: $u, hash: $h}}' <<<"$platforms")
    done

    jq -n --arg v "$version" --argjson p "$platforms" \
        '{version: $v, platforms: $p}' >"$SOURCES_FILE"
}

verify_update() {
    log_info "Building Delta"
    nix build "$(flake_ref)" --print-build-logs

    log_info "Checking package contents"
    test -x ./result/bin/delta

    log_info "Evaluating flake outputs"
    nix flake check "$(flake_path)" --all-systems --no-build
}

update_flake_lock() {
    log_info "Updating flake.lock"
    nix flake update --flake "$(flake_path)"
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat "$SOURCES_FILE" flake.lock 2>/dev/null || true
}

update_to_version() {
    local current_version="$1"
    local new_version="$2"

    log_info "Updating Delta from $current_version to $new_version"
    write_sources "$new_version"
    update_flake_lock
    verify_update
    show_changes
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local args
    args=$(parse_arguments "$@")
    local target_version
    target_version=$(echo "$args" | cut -d'|' -f1)
    local check_only
    check_only=$(echo "$args" | cut -d'|' -f2)

    local current_version
    current_version=$(get_current_version)
    local latest_version
    if [ -n "$target_version" ]; then
        latest_version="$target_version"
    else
        latest_version=$(get_latest_version)
    fi

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version -> $latest_version"
        exit 1
    fi

    update_to_version "$current_version" "$latest_version"
}

main "$@"
