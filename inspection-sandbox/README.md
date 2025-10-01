# Malware Inspection Sandbox

A **fully automated** sandboxed environment for safely analyzing potentially hazardous email attachments and suspicious files on macOS. Everything is scripted to minimize human error.

## 🎯 Features

- **Isolated VM Environment:** Uses UTM with **Virtualize mode** (native performance, not slow emulation)
- **Network Isolation:** VM cannot access your network or host machine
- **Read-Only File Sharing:** Malware cannot write back to your host
- **Comprehensive Analysis Tools:** ClamAV, strings, hexdump, oletools, exiftool, and more
- **Fully Scripted:** Minimal manual steps, maximum automation
- **Safe by Default:** No clipboard sharing, no unnecessary host access

## 📋 Prerequisites

You need Homebrew and UTM:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install UTM
brew install --cask utm
```

## 🚀 Quick Start

### Step 1: Initial Setup

Run the setup script to download Alpine Linux and create SSH keys:

```bash
./setup_sandbox.sh
```

This will:
- Check dependencies
- Download Alpine Linux ISO (~207 MB)
- Generate SSH keys for secure VM access
- Create the `shared/` directory

### Step 2: Create the VM

**IMPORTANT:** Use **Virtualize** mode, NOT Emulate (which is very slow).

```bash
./create-vm.sh
```

This will show you step-by-step instructions to create the VM in UTM. The key settings:

- **Mode:** Virtualize (NOT Emulate!)
- **RAM:** 2048 MB
- **CPU:** 2 cores
- **Storage:** 8 GB
- **Network:** Emulated VLAN with "Isolate Guest from Host" enabled
- **Port Forwarding:** Host 127.0.0.1:2222 → Guest :22
- **Shared Directory:** Read-only mount of `shared/` folder (VirtFS mode)
- **Clipboard Sharing:** Disabled for security

### Step 3: Provision the VM

After creating and starting the VM in UTM, provision it:

```bash
./provision-vm.sh
```

This script will guide you through:
1. Installing Alpine Linux inside the VM (`setup-alpine`)
2. Configuring SSH access
3. Mounting the shared directory
4. Testing the connection

**Follow the on-screen instructions carefully.** The script automates as much as possible.

### Step 4: Inspect Files

Now you can safely inspect suspicious files:

```bash
./inspect.sh suspicious-file.pdf
```

Or:

```bash
# Copy file to shared directory first
cp ~/Downloads/sketchy-invoice.exe shared/
./inspect.sh sketchy-invoice.exe
```

The script will:
1. Start the VM (if not running)
2. Copy the file to the shared directory
3. Run comprehensive analysis inside the isolated VM
4. Display a detailed security report

## 📁 Project Structure

```
inspection-sandbox/
├── setup_sandbox.sh      # Initial setup (downloads ISO, generates keys)
├── create-vm.sh          # Instructions for creating the VM in UTM
├── provision-vm.sh       # Automates Alpine Linux configuration
├── inspect.sh            # Easy wrapper to analyze files
├── alpine.iso            # Alpine Linux installation ISO
├── id_rsa                # SSH private key (generated)
├── id_rsa.pub            # SSH public key (generated)
└── shared/               # Read-only directory shared with VM
    ├── analyze.sh        # Analysis script (runs inside VM)
    └── [your files]      # Files you want to inspect
```

## 🔍 Analysis Tools Included

The sandbox includes these security analysis tools:

**General Analysis:**
- `file` - File type identification
- `strings` - Extract printable strings
- `hexyl` - Modern hex viewer
- `exiftool` - Metadata extraction

**Malware Detection:**
- `clamav` - Antivirus scanning
- `yara` - Pattern matching
- `ssdeep` - Fuzzy hashing

**Office Documents:**
- `oletools` - Analyze Office documents for macros/exploits
- `olevba` - Extract and analyze VBA macros
- `oleid` - Detect suspicious Office files

**PDF Analysis:**
- `pdfinfo` - PDF metadata
- JavaScript detection

**Executable Analysis:**
- `radare2` - Binary analysis framework
- `readelf` - ELF file analysis

**Archive Extraction:**
- `unzip`, `p7zip`, `unrar`, `cabextract`

## 🎮 Usage Examples

### Inspect an Email Attachment

```bash
# Download attachment from email client
cp ~/Downloads/suspicious-invoice.pdf .

# Inspect it safely
./inspect.sh suspicious-invoice.pdf
```

### Analyze Multiple Files

```bash
# Copy all suspicious files to shared directory
cp ~/Downloads/*.exe shared/

# Inspect each one
./inspect.sh malware1.exe
./inspect.sh malware2.exe
```

### Manual Analysis (Advanced)

```bash
# Start the VM
utmctl start inspection-sandbox

# SSH into it
ssh -i id_rsa -p 2222 root@localhost

# Inside the VM:
ls /media/shared/              # See your files
/media/shared/analyze.sh scan /media/shared/file.exe
hexyl /media/shared/file.exe   # Manual hex inspection
strings /media/shared/file.exe | less
```

## 🛠️ Useful Commands

```bash
# Start the VM
utmctl start inspection-sandbox

# Stop the VM
utmctl stop inspection-sandbox

# SSH into the VM
ssh -i id_rsa -p 2222 root@localhost

# Check VM status
utmctl status inspection-sandbox

# Destroy everything and start over
./setup_sandbox.sh burn
```

## 🔥 Burn It All Down

To completely destroy the sandbox and start fresh:

```bash
./setup_sandbox.sh burn
```

This will:
- Stop the VM
- Delete the VM
- Remove all generated files (keeps your suspicious files in `shared/`)

Then start over from Step 1.

## 🛡️ Security Features

1. **Network Isolation:** VM cannot access the internet or your LAN
2. **Read-Only Sharing:** Malware cannot modify host files
3. **No Clipboard Sharing:** Prevents data exfiltration
4. **Minimal VM:** Alpine Linux (tiny attack surface)
5. **Disposable:** Destroy and recreate anytime
6. **SSH Key Auth:** No password-based access

## ⚡ Performance Notes

**Use Virtualize Mode!**

- ✅ **Virtualize:** Near-native performance, uses Apple's Hypervisor framework
- ❌ **Emulate:** Very slow, only use if you need a different CPU architecture

On Apple Silicon (M1/M2/M3), Alpine x86_64 will be emulated but should still be reasonably fast in Virtualize mode.

## 🐛 Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

### VM Boots to UEFI Shell (Shell> _)

**Quick fix:** In the UEFI shell, type:
```
fs0:
\EFI\BOOT\BOOTX64.EFI
```

**Permanent fix:** After installing Alpine, remove the ISO from VM settings or use the UEFI shell method each boot.

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for details.

### SSH Connection Fails

```bash
# Check if VM is running
utmctl status inspection-sandbox

# Check if SSH port is open
nc -zv localhost 2222

# Try connecting manually
ssh -v -i id_rsa -p 2222 root@localhost

# Inside VM, check SSH status
service sshd status
```

### Shared Directory Not Mounting

Inside the VM:

```bash
# Check if shared directory is in fstab
cat /etc/fstab | grep shared

# Try mounting manually
mount -t 9p -o trans=virtio,version=9p2000.L shared /media/shared

# Check UTM settings: Sharing → Directory Share Mode → VirtFS
```

### VM Won't Start

- Check UTM console for error messages
- Verify the ISO path is correct
- Ensure you allocated enough disk space (8 GB minimum)
- Try recreating the VM

## 📚 Future Enhancements

- [ ] Automated snapshots for easy reversion
- [ ] Web-based UI for analysis reports
- [ ] Network traffic capture (controlled network simulation)
- [ ] Windows VM support
- [ ] Batch file analysis
- [ ] Integration with VirusTotal API (optional, requires internet)

## 🤝 Contributing

This is a personal tool but feel free to adapt it for your needs. The scripts are heavily commented for educational purposes.

## ⚠️ Legal Disclaimer

This tool is for **defensive security research and education only**. Do not use it for illegal purposes. Only analyze files you have permission to inspect. The authors are not responsible for misuse.

## 📄 License

MIT License - Use at your own risk

---

**Built to be better than whatever Gemini made. 😎**
