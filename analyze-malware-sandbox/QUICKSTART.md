# Quick Start Guide - Malware Inspection Sandbox

## 🚀 Setup (First Time Only)

```bash
# 1. Run initial setup
./setup-sandbox.sh

# 2. Create the VM (follow on-screen instructions)
./create-vm.sh

# 3. Provision the VM (after creating it in UTM)
./provision-vm.sh
```

## 🔍 Daily Usage

```bash
# Inspect a suspicious file
./inspect.sh suspicious-file.pdf
```

That's it! The script handles everything else.

## 📝 Key Reminders

- ✅ **Use VIRTUALIZE mode** in UTM (not Emulate!)
- ✅ Network must be **Emulated VLAN** with **"Isolate Guest from Host"**
- ✅ Shared directory must be **Read Only**
- ✅ Port forwarding: **127.0.0.1:2222 → 22**

## 🛠️ Common Commands

```bash
# Start VM
utmctl start inspection-sandbox

# Stop VM
utmctl stop inspection-sandbox

# SSH into VM
ssh -i id_rsa -p 2222 root@localhost

# Destroy and start over
./setup-sandbox.sh burn
```

## ⚠️ First VM Setup Steps (Inside UTM)

After creating the VM in UTM and booting it:

1. Login as `root` (no password)
2. Run: `setup-alpine`
3. Set a root password when prompted
4. Choose disk `sda`, mode `sys`
5. After install completes, run these commands:

```bash
rc-update add sshd
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
apk add bash curl sudo
mkdir -p /media/shared
echo "shared /media/shared 9p trans=virtio,version=9p2000.L,ro,_netdev 0 0" >> /etc/fstab
mount -a
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat /media/shared/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
service sshd start
reboot
```

6. After reboot, return to host and press ENTER in `provision-vm.sh`

## 📊 What Gets Analyzed

The `analyze.sh` script checks:

- File type and basic info
- MD5, SHA1, SHA256 hashes
- Metadata (EXIF data)
- ClamAV antivirus scan
- Suspicious strings (URLs, IPs, emails, keywords)
- Office document macros (oletools)
- PDF JavaScript detection
- Hex dump of file header

## 🔥 Troubleshooting

**SSH won't connect:**
```bash
# Check VM is running
utmctl status inspection-sandbox

# Test port
nc -zv localhost 2222

# Inside VM, check SSH
service sshd status
```

**Shared folder not working:**
```bash
# Inside VM
mount | grep shared
# Should show: shared on /media/shared type 9p
```

---

For full details, see [README.md](README.md)
