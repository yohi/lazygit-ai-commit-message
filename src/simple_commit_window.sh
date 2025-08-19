#!/bin/bash
# Simple commit message input using standard tools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Simple commit message input using available editors
show_simple_commit_window() {
    local ai_message="$1"
    local temp_file="/tmp/ai-commit-message.txt"
    
    # Write AI message to temp file
    echo "$ai_message" > "$temp_file"
    
    # Try different editors in order of preference
    local editors=("nano" "vim" "vi" "emacs")
    local editor_found=false
    
    for editor in "${editors[@]}"; do
        if command -v "$editor" >/dev/null 2>&1; then
            log_info "Using editor: $editor"
            if "$editor" "$temp_file"; then
                editor_found=true
                break
            fi
        fi
    done
    
    if ! $editor_found; then
        log_error "No suitable editor found"
        echo "Error: No text editor available" >&2
        return 1
    fi
    
    # Read the edited message
    if [[ -f "$temp_file" ]]; then
        cat "$temp_file"
        rm -f "$temp_file"
        return 0
    else
        log_error "Temp file not found"
        return 1
    fi
}

# Fallback commit function
simple_commit() {
    local message="$1"
    echo "Generated commit message: $message"
    echo -n "Commit with this message? [Y/n]: "
    read -r response
    
    case "$response" in
        ""|"y"|"Y"|"yes"|"Yes"|"YES")
            if git commit -m "$message"; then
                echo "✅ Commit successful!"
                return 0
            else
                echo "❌ Commit failed"
                return 1
            fi
            ;;
        *)
            echo "❌ Commit cancelled"
            return 1
            ;;
    esac
}

# Main function for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -gt 0 ]]; then
        show_simple_commit_window "$1"
    else
        echo "Usage: $0 <ai_message>"
        exit 1
    fi
fi