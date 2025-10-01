# Troubleshooting Guide

## VM Boots to UEFI Shell Instead of Alpine Installer

**Symptom:** VM starts and shows `UEFI Interactive Shell v2.2` with `Shell> _` prompt

**Cause:** The boot order is incorrect - VM is not booting from the ISO

**Solution:**

### Option 1: Boot from ISO manually (Quick Fix)

In the UEFI Shell, type:
```
fs0:
```
Then:
```
ls
```
You should see EFI files. Then run:
```
\EFI\BOOT\BOOTX64.EFI
```

This will boot the Alpine installer.

### Option 2: Fix Boot Order in UTM (Permanent Fix)

1. **Stop the VM** (if running)
2. In UTM, click the VM name, then click 🎛️ (Edit)
3. Go to **"Drives"** tab
4. You should see two drives:
   - The Alpine ISO (CD/DVD)
   - The hard disk (8 GB)
5. **Important:** The ISO drive must be ABOVE the hard disk in the list
6. If it's not, drag the ISO to the top
7. Click **"Save"**
8. Start the VM

### Option 3: Change Boot Order at Startup

Some UTM versions allow you to press ESC during boot to enter the UEFI setup menu where you can change boot order.

### After Installing Alpine

Once you've installed Alpine Linux to the hard disk:

1. **Shut down the VM completely**
2. In UTM, edit the VM settings
3. Go to **"Drives"** tab
4. **Remove** or **disable** the Alpine ISO drive
5. Keep only the hard disk drive
6. Save and restart

This ensures the VM boots from the installed system, not the installer.

---

## Other Common Issues

### SSH Connection Timeout

**Solution:**
```bash
# Inside the VM, check if SSH is running
service sshd status

# If not running, start it
service sshd start

# Make sure it starts on boot
rc-update add sshd
```

### Shared Directory Not Mounting

**Solution:**
```bash
# Inside the VM
mkdir -p /media/shared
mount -t 9p -o trans=virtio,version=9p2000.L shared /media/shared

# Add to /etc/fstab for auto-mount
echo "shared /media/shared 9p trans=virtio,version=9p2000.L,ro,_netdev 0 0" >> /etc/fstab
```

### VM is Very Slow

**Check:** Are you using **Virtualize** mode or Emulate mode?
- ✅ Virtualize = Fast
- ❌ Emulate = Very slow

**Solution:** Recreate the VM using Virtualize mode (see create-vm.sh)

### Can't Connect - Port 2222 Not Open

**Check port forwarding in UTM:**
1. Edit VM → Network tab → Port Forwarding
2. Verify:
   - Protocol: TCP
   - Guest Port: 22
   - Host Address: 127.0.0.1
   - Host Port: 2222

### Alpine Installation Asks for Password But I Don't Have One

During `setup-alpine`, when it asks for the root password, you're **setting** it (not entering an existing one). Choose a strong password - you'll need it to login.

After SSH is configured with keys, you won't need the password anymore (key-based auth).
