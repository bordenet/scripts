#!/bin/bash
#
# Malware Analysis Script
# Runs inside the VM to analyze potentially malicious files
#

set -euo pipefail

TOOLS_INSTALLED_MARKER="/root/.analysis_tools_installed"

#
# Install analysis tools
#
install_tools() {
    echo "========================================"
    echo "Installing Analysis Tools"
    echo "========================================"
    echo ""

    # Update package repository
    echo "📦 Updating package repository..."
    apk update

    echo "🔧 Installing analysis tools..."
    apk add \
        file \
        binutils \
        strings \
        hexyl \
        clamav \
        clamav-daemon \
        freshclam \
        python3 \
        py3-pip \
        unzip \
        p7zip \
        cabextract \
        unrar \
        sqlite \
        exiftool \
        imagemagick \
        poppler-utils \
        yara \
        ssdeep \
        radare2

    echo "🦠 Updating ClamAV virus database (this may take a few minutes)..."
    freshclam || echo "⚠️  ClamAV database update had issues, continuing anyway..."

    echo "🔧 Installing Python analysis tools..."
    pip3 install --break-system-packages \
        oletools \
        pefile \
        yara-python \
        ssdeep \
        python-magic

    # Create marker file
    touch "${TOOLS_INSTALLED_MARKER}"

    echo ""
    echo "✅ All analysis tools installed successfully!"
}

#
# Scan a file
#
scan_file() {
    local target="$1"

    if [ ! -e "${target}" ]; then
        echo "❌ File not found: ${target}"
        exit 1
    fi

    echo "========================================"
    echo "Malware Analysis Report"
    echo "========================================"
    echo "Target: ${target}"
    echo "Date: $(date)"
    echo "========================================"
    echo ""

    # Check if tools are installed
    if [ ! -f "${TOOLS_INSTALLED_MARKER}" ]; then
        echo "⚠️  Analysis tools not installed. Installing now..."
        install_tools
        echo ""
    fi

    # Basic file information
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 FILE INFORMATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "File type:"
    file -b "${target}"
    echo ""
    echo "File size:"
    ls -lh "${target}" | awk '{print $5}'
    echo ""
    echo "MD5:    $(md5sum "${target}" | awk '{print $1}')"
    echo "SHA1:   $(sha1sum "${target}" | awk '{print $1}')"
    echo "SHA256: $(sha256sum "${target}" | awk '{print $1}')"
    echo ""

    # Metadata extraction
    if command -v exiftool &>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 METADATA (EXIF)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        exiftool "${target}" || echo "Could not extract metadata"
        echo ""
    fi

    # ClamAV scan
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🦠 CLAMAV VIRUS SCAN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if clamscan "${target}"; then
        echo "✅ No malware detected by ClamAV"
    else
        echo "⚠️  ClamAV detected potential threats!"
    fi
    echo ""

    # String extraction
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔤 INTERESTING STRINGS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "URLs and domains:"
    strings "${target}" | grep -E '(https?://|www\.|[a-zA-Z0-9][-a-zA-Z0-9]+\.(com|net|org|io|ru|cn))' | head -20 || echo "None found"
    echo ""
    echo "Email addresses:"
    strings "${target}" | grep -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | head -10 || echo "None found"
    echo ""
    echo "IP addresses:"
    strings "${target}" | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -10 || echo "None found"
    echo ""
    echo "Suspicious keywords:"
    strings "${target}" | grep -iE '(password|pass|pwd|exec|eval|shell|cmd|payload|exploit|malware)' | head -10 || echo "None found"
    echo ""

    # Office document analysis (if applicable)
    if file "${target}" | grep -qiE '(microsoft|office|ooxml|opendocument)'; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📎 OFFICE DOCUMENT ANALYSIS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        if command -v olevba &>/dev/null; then
            echo "Analyzing macros with olevba..."
            olevba "${target}" || echo "Could not analyze macros"
        fi
        if command -v oleid &>/dev/null; then
            echo ""
            echo "Analyzing with oleid..."
            oleid "${target}" || echo "Could not analyze with oleid"
        fi
        echo ""
    fi

    # PDF analysis (if applicable)
    if file "${target}" | grep -qi 'pdf'; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📕 PDF ANALYSIS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        if command -v pdfinfo &>/dev/null; then
            echo "PDF Information:"
            pdfinfo "${target}" || echo "Could not extract PDF info"
        fi
        echo ""
        echo "Checking for JavaScript in PDF:"
        strings "${target}" | grep -i 'javascript' || echo "None found"
        echo ""
    fi

    # PE executable analysis (if applicable)
    if file "${target}" | grep -qiE '(PE32|MS-DOS)'; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚙️  EXECUTABLE ANALYSIS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Imports and exports:"
        readelf -a "${target}" 2>/dev/null | head -50 || strings "${target}" | grep -iE '(kernel32|ntdll|advapi|user32)' | head -20 || echo "Could not analyze"
        echo ""
    fi

    # Hex dump (first 512 bytes)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔢 HEX DUMP (first 512 bytes)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if command -v hexyl &>/dev/null; then
        hexyl -n 512 "${target}"
    else
        hexdump -C "${target}" | head -32
    fi
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Analysis complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

#
# Show usage
#
usage() {
    cat <<EOF
Usage: $0 <command> [arguments]

Commands:
  install-tools           Install all analysis tools
  scan <file>            Scan a file for malware
  help                   Show this help message

Examples:
  $0 install-tools
  $0 scan /media/shared/suspicious.exe
  $0 scan /media/shared/document.pdf
EOF
}

#
# Main
#
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    case "$1" in
        install-tools)
            install_tools
            ;;
        scan)
            if [ $# -lt 2 ]; then
                echo "Error: scan command requires a file path"
                usage
                exit 1
            fi
            scan_file "$2"
            ;;
        help)
            usage
            ;;
        *)
            echo "Error: Unknown command '$1'"
            usage
            exit 1
            ;;
    esac
}

main "$@"
