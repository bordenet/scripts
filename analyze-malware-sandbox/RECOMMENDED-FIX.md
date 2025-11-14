# RECOMMENDED FIX - How to Actually Make This Work

After hours of debugging, here's what will ACTUALLY work:

## The Problem

The current approach has fundamental flaws:
1. **Standard Alpine ISO lacks 9p support** (VirtFS doesn't work)
2. **UTM Emulate mode has unreliable port forwarding**
3. **Too many manual steps with clipboard disabled**
4. **SSH authentication is completely broken**

## The Solution: Use Alpine Virtual ISO

### Step 1: Download the RIGHT Alpine ISO

```bash
cd ~/GitHub/scripts/inspection-sandbox

# Backup the broken one
mv alpine.iso alpine-standard-broken.iso

# Download Alpine VIRT (has 9p/VirtFS support built-in!)
curl -L -o alpine.iso "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.1-x86_64.iso"
```

### Step 2: Destroy and Recreate

```bash
# Burn down the broken VM
./setup-sandbox.sh burn

# Confirm it's gone
utmctl list

# Run setup again (downloads ISO, generates keys)
./setup-sandbox.sh
```

### Step 3: Create VM in UTM (Same as Before)

1. Open UTM → Create New VM
2. **Emulate** → Other
3. Skip ISO
4. x86_64, 2GB RAM, 2 CPU cores, 8GB disk
5. **Shared Directory:** Browse to `shared` folder, Read Only
6. Name: inspection-sandbox
7. Save

### Step 4: Configure VM

Edit VM:

**Drives:**
- Add CD/DVD drive with alpine.iso

**Network:**
- Mode: **Shared Network**
- Port Forward: TCP, Guest 22, Host 127.0.0.1:2222

**Sharing:**
- VirtFS mode
- Shared directory: (already set)
- ❌ Enable Clipboard (KEEP IT ON until SSH works!)

### Step 5: Install Alpine

Start VM, login as root, run:

```bash
setup-alpine
```

**IMPORTANT:** Choose `yes` for SSH root login (not prohibit-password yet!)

After installation:

```bash
# Install 9p modules (alpine-virt has these!)
modprobe 9p
modprobe 9pnet
modprobe 9pnet_virtio

# Mount shared folder (should work now!)
mkdir -p /media/shared
mount -t 9p -o trans=virtio,version=9p2000.L shared /media/shared

# Check if it worked
ls /media/shared
# Should see: id_rsa.pub, analyze.sh, etc.

# Setup SSH key
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat /media/shared/id_rsa.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Verify
cat /root/.ssh/authorized_keys

# Add shared to fstab for auto-mount
echo "shared /media/shared 9p trans=virtio,version=9p2000.L,ro,_netdev 0 0" >> /etc/fstab

# Install tools
apk add bash curl

# Enable SSH
rc-update add sshd
service sshd start

# DON'T POWEROFF YET! Test SSH first!
```

### Step 6: Test SSH BEFORE Isolating

**On your Mac (different terminal):**

```bash
ssh -i ~/GitHub/scripts/inspection-sandbox/id_rsa root@192.168.64.2
```

**If this works:**
```bash
# In SSH session, verify everything
ls /media/shared
cat /root/.ssh/authorized_keys
exit
```

**Also test port forwarding:**
```bash
ssh -i ~/GitHub/scripts/inspection-sandbox/id_rsa -p 2222 root@localhost
```

**Only if BOTH work, then:**

### Step 7: Lock It Down

**In the VM:**
```bash
# Now change to prohibit-password
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
service sshd restart
poweroff
```

**In UTM:**
1. Edit VM → Network
2. Change to "Emulated VLAN"
3. ✅ Check "Isolate Guest from Host"
4. ❌ Disable Clipboard Sharing now
5. Save

**Start VM and test:**
```bash
./status.sh
```

Should show SSH working!

## Alternative: Use VirtualBox

VirtualBox has better Alpine support:

```bash
brew install --cask virtualbox

# Create VM
VBoxManage createvm --name inspection-sandbox --register
VBoxManage modifyvm inspection-sandbox --memory 2048 --cpus 2 --nic1 nat
VBoxManage storagectl inspection-sandbox --name SATA --add sata
VBoxManage createhd --filename ~/VirtualBox\ VMs/inspection-sandbox/disk.vdi --size 8192
VBoxManage storageattach inspection-sandbox --storagectl SATA --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/inspection-sandbox/disk.vdi
VBoxManage storageattach inspection-sandbox --storagectl SATA --port 1 --device 0 --type dvddrive --medium ~/GitHub/scripts/inspection-sandbox/alpine.iso
VBoxManage modifyvm inspection-sandbox --natpf1 "ssh,tcp,127.0.0.1,2222,,22"
VBoxManage sharedfolder add inspection-sandbox --name shared --hostpath ~/GitHub/scripts/inspection-sandbox/shared --readonly

# Start VM
VBoxManage startvm inspection-sandbox

# SSH setup same as above, but VirtualBox shared folders are more reliable
```

## Even Simpler: Docker

Skip VMs entirely:

```bash
# Run Alpine in Docker with shared folder
docker run -it --rm \
  -v ~/GitHub/scripts/inspection-sandbox/shared:/shared:ro \
  -p 2222:22 \
  alpine:latest sh

# Inside container
apk add openssh bash curl
ssh-keygen -A
mkdir -p /root/.ssh
cat /shared/id_rsa.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
/usr/sbin/sshd

# Test from Mac
ssh -i ~/GitHub/scripts/inspection-sandbox/id_rsa -p 2222 root@localhost
```

Docker is:
- ✅ Simpler
- ✅ Faster
- ✅ Shared folders just work
- ✅ Port forwarding just works
- ✅ Still isolated

## Summary

**The real fix:** Use alpine-virt ISO (has 9p support) or switch to VirtualBox/Docker.

**Don't:** Keep fighting with standard Alpine + UTM Emulate mode.

**Do:** Test SSH works BEFORE isolating the network.

**Remember:** Alpine-virt is specifically built for VMs and has all the kernel modules you need.
