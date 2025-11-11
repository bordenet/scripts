# ACTUAL WORKING SETUP INSTRUCTIONS

These are the **REAL** steps that actually work, learned through painful trial and error.

## Prerequisites

```bash
brew install --cask utm
```

## Step 1: Initial Setup

```bash
cd ~/GitHub/scripts/inspection-sandbox
./setup-sandbox.sh
```

This downloads Alpine ISO and generates SSH keys.

## Step 2: Create VM in UTM

1. Open UTM
2. Click "+" → Create New VM
3. Select **"Emulate"** (NOT Virtualize - it has ISO boot issues)
4. Select "Other"
5. Skip ISO for now
6. Architecture: **x86_64**
7. RAM: **2048 MB**, CPU: **2 cores**
8. Storage: **8 GB**
9. Shared Directory: **Browse to `shared` folder**, set Read Only
10. Name: **inspection-sandbox**
11. Click Save

## Step 3: Configure VM Settings

Click the VM → Edit (🎛️ icon):

### Drives
- Add a **new CD/DVD drive**
- Browse to `alpine.iso`
- Make sure it's listed (we'll remove it after install)

### Network
- Network Mode: **Shared Network** (for installation only)
- Do NOT check "Isolate Guest from Host" yet

### Port Forwarding (under Network)
- Click "New..."
- Protocol: TCP
- Guest Port: 22
- Host Address: 127.0.0.1
- Host Port: 2222

### Sharing
- Directory Share Mode: **VirtFS** (doesn't work with standard Alpine, skip it)
- ❌ Uncheck "Enable Clipboard Sharing"

Click Save.

## Step 4: Install Alpine Linux

**Start the VM.**

If it boots to UEFI shell, type:
```
FS0:
EFI\BOOT\BOOTx64.EFI
```

**Login as `root` (no password)**

Run:
```bash
setup-alpine
```

Settings:
- Keyboard: `us`
- Hostname: `sandbox`
- Network: `eth0`, IP: `dhcp`
- Root password: **Choose a strong password**
- Timezone: Your timezone
- Proxy: `none`
- NTP: `chrony`
- APK mirror: `1` or `f` (find fastest)
- SSH: `openssh`
- Allow root SSH: `prohibit-password`
- Disk: `sda`
- Use: `sys`

**IMPORTANT: If setup-alpine fails due to network/mirror issues:**

```bash
# Bring up network manually
ifconfig eth0 up
udhcpc -i eth0

# Setup repos manually
setup-apkrepos
# Choose option 1

# Try setup-alpine again or continue manually
```

## Step 5: Post-Installation Setup

**After Alpine installs, run these commands:**

```bash
# Update package repos
apk update

# Install SSH if not already installed
apk add openssh bash curl

# Enable SSH to start on boot
rc-update add sshd

# Start SSH now
service sshd start
```

## Step 6: Setup SSH Key Authentication

**On your Mac, start a web server:**
```bash
cd ~/GitHub/scripts/inspection-sandbox
python3 -m http.server 8000
```

**In the VM:**
```bash
# Ensure network is up
ifconfig eth0 up
udhcpc -i eth0

# Get the host IP (look for "via" IP)
ip route | grep default

# Download SSH key (use the IP from above, usually 192.168.64.1)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
wget http://192.168.64.1:8000/id_rsa.pub -O /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Verify
cat /root/.ssh/authorized_keys

# Shutdown
poweroff
```

**On your Mac, stop the web server (Ctrl+C)**

## Step 7: Isolate the Network

**After VM shuts down:**

1. Edit VM → Network tab
2. Change to **"Emulated VLAN"**
3. ✅ Check **"Isolate Guest from Host"**
4. Click Save

**Remove the installation ISO (optional):**
- Edit VM → Find the CD/DVD drive with alpine.iso
- Remove it or clear it

## Step 8: Test SSH Connection

**Start the VM**

**On your Mac:**
```bash
cd ~/GitHub/scripts/inspection-sandbox
./status.sh
```

You should see:
- ✅ VM Running
- ✅ SSH Connection: Working

**Manual SSH test:**
```bash
ssh -i id_rsa -p 2222 root@localhost
```

## Step 9: Install Analysis Tools

**SSH into the VM:**
```bash
ssh -i id_rsa -p 2222 root@localhost
```

**Inside the VM, you'll need to temporarily enable network to install tools.**

This is the **CRITICAL ISSUE**: The standard Alpine ISO doesn't support VirtFS/9p shared folders.

**Two options:**

### Option A: Use Alpine Virtual ISO (Better)
Download the `alpine-virt` ISO instead which has 9p support:
```bash
curl -L -o alpine.iso "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.1-x86_64.iso"
```

Then recreate the VM.

### Option B: Install tools via network (Current method)
1. Edit VM → Network → Change to "Shared Network", uncheck isolation
2. Restart VM
3. SSH in and run:
```bash
ifconfig eth0 up
udhcpc -i eth0
/media/shared/analyze.sh install-tools
```
4. Shutdown, re-isolate network

## Step 10: Use the Sandbox

```bash
./inspect.sh suspicious-file.pdf
```

---

## Key Lessons Learned

1. **Virtualize mode has UEFI boot issues** - Use Emulate mode
2. **Standard Alpine ISO lacks 9p support** - Shared folders don't work, use alpine-virt ISO or network transfer
3. **Network must be enabled during installation** - Can't download packages when isolated
4. **setup-alpine can fail** - Be prepared to do manual setup
5. **Clipboard sharing must be enabled to paste** - Or use wget/http server method
6. **Host IP in VM is usually 192.168.64.1** - Not 10.0.2.2 (check with `ip route`)

## Working File Transfer Methods

Since VirtFS doesn't work with standard Alpine:

1. **HTTP server method** (used above)
2. **SCP from host while network enabled**
3. **Use alpine-virt ISO** (has 9p support built-in)

---

**This documentation reflects what ACTUALLY works, not theoretical perfection.**
