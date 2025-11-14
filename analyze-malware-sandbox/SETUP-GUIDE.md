# Malware Inspection Sandbox - Setup Guide

**Status:** ✅ Ready to build (October 6, 2025)

This guide will help you create a working malware inspection sandbox using UTM, Alpine Linux (virt), and automated analysis tools.

## What's Different This Time

Previous attempts failed because:
- ❌ Used standard Alpine ISO (lacks 9p/VirtFS support for shared folders)
- ❌ Disabled clipboard before verifying SSH works
- ❌ Isolated network before testing connectivity
- ❌ UTM Emulate mode port forwarding was unreliable

**This guide fixes all of that:**
- ✅ Uses alpine-virt ISO (has 9p kernel modules built-in)
- ✅ Tests SSH before locking down
- ✅ Keeps clipboard enabled until verified working
- ✅ Step-by-step verification at each stage

## Prerequisites

- macOS with UTM installed
- `brew install utmctl` (for automation)
- ~8GB free disk space
- Internet connection

## Setup Steps

### 1. Initial Setup (Already Done!)

```bash
cd ~/GitHub/scripts/inspection-sandbox
./setup-sandbox.sh
```

This created:
- `alpine.iso` - Alpine virt ISO (60MB, has 9p support!)
- `id_rsa` / `id_rsa.pub` - SSH key pair
- `shared/` - Directory for file transfer to VM

### 2. Create VM in UTM

1. **Open UTM** → Click "Create a New Virtual Machine"

2. **Choose Emulate** → Select "Other"

3. **Skip ISO for now** → Click Continue (we'll add it later)

4. **Architecture and CPU:**
   - Architecture: x86_64
   - Memory: 2048 MB (2GB)
   - CPU Cores: 2

5. **Storage:**
   - Size: 8192 MB (8GB)

6. **Shared Directory:**
   - Click "Browse"
   - Select: `~/GitHub/scripts/inspection-sandbox/shared`
   - ✅ Check "Read Only"

7. **Summary:**
   - Name: `inspection-sandbox`
   - Save

### 3. Configure VM Settings

Before starting the VM, edit its settings:

#### Drives Tab
- Click "New Drive" → "Import"
- Select: `~/GitHub/scripts/inspection-sandbox/alpine.iso`
- Interface: IDE (or CD/DVD)

#### Network Tab
- Network Mode: **Shared Network**
- Port Forward:
  - Protocol: TCP
  - Guest Address: (leave empty)
  - Guest Port: 22
  - Host Address: 127.0.0.1
  - Host Port: 2222

#### Sharing Tab
- ✅ Enable Clipboard Sharing (KEEP THIS ON for now!)
- VirtFS Mode: (should already be set)

Save settings.

### 4. Install Alpine Linux

Start the VM and login as `root` (no password needed at boot).

Run the setup:
```bash
setup-alpine
```

**Important answers:**
- Keyboard: `us`
- Variant: `us`
- Hostname: `sandbox`
- Network: `eth0` (press Enter)
- IP address: `dhcp`
- Manual network config: `no`
- Root password: Choose a password (you'll need this once)
- Timezone: `America/Los_Angeles` (or your timezone)
- Proxy: `none`
- NTP client: `chrony`
- Mirror: `1` (use first mirror)
- SSH server: `openssh`
- **Allow root SSH login:** `yes` (NOT prohibit-password yet!)
- Disk: `sda`
- Use mode: `sys`
- Erase disk: `y`

Wait for installation to complete.

When done:
```bash
poweroff
```

### 5. Eject Install ISO

In UTM:
- Edit VM settings → Drives
- Remove or eject the alpine.iso drive
- Save

Start VM again.

### 6. Setup Shared Folder and SSH (Critical Step!)

Login as `root` with the password you set.

```bash
# Load 9p kernel modules (alpine-virt has these!)
modprobe 9p
modprobe 9pnet
modprobe 9pnet_virtio

# Create mount point
mkdir -p /media/shared

# Mount the shared folder
mount -t 9p -o trans=virtio,version=9p2000.L shared /media/shared

# Verify it worked
ls /media/shared
# You should see: id_rsa.pub, analyze.sh
```

**If the mount fails**, you have the wrong ISO. Stop and use alpine-virt!

If it works, continue:

```bash
# Make it auto-mount on boot
echo "shared /media/shared 9p trans=virtio,version=9p2000.L,ro,_netdev 0 0" >> /etc/fstab

# Setup SSH key authentication
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat /media/shared/id_rsa.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Verify the key is there
cat /root/.ssh/authorized_keys
# Should show a long ssh-rsa key

# Install useful tools
apk add bash curl file

# Make sure SSH is enabled and running
rc-update add sshd
service sshd restart
```

**DO NOT POWEROFF YET!** We need to test SSH first.

### 7. Test SSH (Critical - Don't Skip!)

Keep the VM running. On your Mac, open a new terminal:

```bash
cd ~/GitHub/scripts/inspection-sandbox

# Test direct IP SSH
ssh -i id_rsa root@192.168.64.2
```

**If it asks for a password**, something is wrong with the key. Check:
- Is `/root/.ssh/authorized_keys` correct in the VM?
- Are permissions 600 on authorized_keys and 700 on .ssh?

**If it works:**
```bash
# Verify shared folder is accessible
ls /media/shared
exit
```

Now test port forwarding:
```bash
ssh -i id_rsa -p 2222 root@localhost
```

**If this also works**, you're good! If not, UTM port forwarding may be broken.

### 8. Lock Down Security (Only After SSH Works!)

**In the VM (via SSH or console):**

```bash
# Now we can safely require key-based auth only
sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
service sshd restart

# Test that password auth is disabled
# (Try SSH without the key - should fail)

# Shutdown
poweroff
```

**In UTM (VM Settings):**
- Sharing tab:
  - ❌ Disable Clipboard Sharing (security)
- Network tab (optional - for full isolation):
  - Change to "Emulated VLAN"
  - ✅ Check "Isolate Guest from Host"

**Note:** If you isolate the network, port forwarding won't work. You'll need to use direct IP (192.168.64.2) while the VM is running.

### 9. Verify Everything Works

Start the VM and run:

```bash
cd ~/GitHub/scripts/inspection-sandbox
./status.sh
```

You should see:
- ✅ VM is running
- ✅ SSH is working
- ✅ Shared folder is mounted
- ✅ Analysis tools are available

### 10. Test File Inspection

```bash
# Copy a test file to the shared folder
echo "test malware sample" > shared/test.txt

# Run inspection
./inspect.sh shared/test.txt
```

You should see analysis output with MD5/SHA256 hashes, strings, etc.

## What You Now Have

A fully functional malware inspection sandbox:

- **Isolated VM**: Alpine Linux running in UTM
- **SSH Access**: Key-based authentication only
- **Shared Folder**: Read-only file transfer from host to VM
- **Analysis Tools**: ClamAV, oletools, exiftool, yara, radare2, etc.
- **Automation**: One-command file inspection with `./inspect.sh`

## Daily Usage

```bash
# Start VM (if not running)
cd ~/GitHub/scripts/inspection-sandbox
./status.sh  # Shows VM status

# Inspect a suspicious file
./inspect.sh /path/to/suspicious/file.pdf

# SSH into the VM for manual analysis
ssh -i id_rsa -p 2222 root@localhost
# or
ssh -i id_rsa root@192.168.64.2
```

## Troubleshooting

**Shared folder not mounting?**
```bash
# In VM
modprobe 9p 9pnet 9pnet_virtio
mount -t 9p -o trans=virtio,version=9p2000.L shared /media/shared
```

**SSH not working?**
```bash
# Check if VM is running
utmctl list

# Check if SSH is reachable
nc -zv localhost 2222

# Try direct IP instead
ssh -i id_rsa root@192.168.64.2

# Check VM console for errors
# (Open UTM, double-click VM to see console)
```

**VM won't start?**
- Make sure alpine.iso is ejected from Drives
- Try increasing RAM to 4GB
- Check UTM logs

## Scripts Reference

- `./setup-sandbox.sh` - Initial setup (downloads ISO, generates keys)
- `./setup-sandbox.sh burn` - Destroys VM and cleans up
- `./status.sh` - Shows VM and SSH status
- `./inspect.sh <file>` - Analyzes a file in the sandbox
- `./provision-vm.sh` - Installs analysis tools in the VM (run once after setup)

## Next Steps

1. Run `./provision-vm.sh` to install all malware analysis tools
2. Copy suspicious files to `shared/` directory
3. Use `./inspect.sh` to analyze them safely

## The Key Difference: Alpine Virt vs Standard

**Alpine Standard ISO:**
- ❌ No 9p kernel modules
- ❌ VirtFS doesn't work
- ❌ Can't mount shared folders
- ❌ Have to use workarounds (HTTP server, manual typing)

**Alpine Virt ISO:**
- ✅ Built for virtualization
- ✅ Has 9p kernel modules pre-compiled
- ✅ VirtFS just works
- ✅ Shared folders mount perfectly

This one change fixes everything!

## Success Criteria

Before considering setup complete, verify:

- [ ] VM boots to login prompt
- [ ] `ssh -i id_rsa -p 2222 root@localhost` works without password
- [ ] Inside VM: `ls /media/shared` shows host files
- [ ] `./status.sh` reports all green
- [ ] `./inspect.sh` can analyze a test file

If all boxes are checked, you're done! 🎉
