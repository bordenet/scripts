# WHERE WE LEFT OFF - CURRENT STATUS

**Date:** October 1, 2025 (Birthday debugging nightmare)

## Current Situation

### What's Working ✅
- VM is created and running in UTM (Emulate mode)
- Alpine Linux is installed on the VM
- Network is configured (VM has IP 192.168.64.2)
- SSH daemon is installed and running on the VM
- Port forwarding is configured in UTM (127.0.0.1:2222 → VM:22)
- SSH keys are generated on host Mac

### What's NOT Working ❌
- **SSH connection completely broken**
- Password authentication doesn't work (even after resetting with `passwd`)
- Key-based authentication doesn't work
- Port forwarding appears broken (connection refused on localhost:2222)
- Direct IP SSH also fails (192.168.64.2)
- The authorized_keys file may not be properly set up

## VM Current State

**VM Name:** inspection-sandbox
**VM IP:** 192.168.64.2
**Host Port Forward:** localhost:2222 → VM:22
**Network Mode:** Shared (NOT isolated)
**SSH Status in VM:** Running (verified with `netstat -tuln | grep 22`)

## Problems Encountered

1. **VirtFS/9p shared folder doesn't work** with standard Alpine ISO
   - Standard Alpine lacks 9p kernel support
   - Shared folder mounts fail
   - Had to use HTTP server method to transfer SSH key

2. **Port forwarding doesn't work** even though configured correctly
   - UTM config shows correct port forwarding setup
   - `nc -zv localhost 2222` fails with connection refused
   - May be UTM bug with Emulate mode

3. **SSH authentication completely broken**
   - Password auth fails (set to prohibit-password during setup-alpine)
   - Re-enabled password auth in sshd_config but still fails
   - Reset root password with `passwd` but still denied
   - Key auth not working (authorized_keys may be missing/wrong)

4. **Catch-22 situation**
   - Can't SSH in to fix SSH configuration
   - Console access only, no copy/paste
   - Can't easily transfer files to fix the issue

## What Was Attempted

### SSH Key Transfer Methods Tried:
1. ❌ VirtFS shared folder (doesn't work - no 9p support)
2. ❌ Clipboard paste (disabled for security)
3. ✅ HTTP server method (worked to download file, but key auth still broken)

### SSH Fixes Attempted:
1. Reinstalled openssh, openssh-server
2. Ran ssh-keygen -A to generate host keys
3. Added sshd to runlevel with rc-update
4. Restarted sshd service multiple times
5. Created /root/.ssh/authorized_keys via wget from HTTP server
6. Set correct permissions (700 on .ssh, 600 on authorized_keys)
7. Enabled PasswordAuthentication in sshd_config
8. Reset root password with passwd command
9. Verified SSH is listening on 0.0.0.0:22 with netstat
10. Verified network connectivity (VM can ping host)
11. Restarted entire UTM app
12. Tried both localhost:2222 and direct IP 192.168.64.2

**ALL FAILED**

## Next Steps to Try (When You Have Energy)

### Option 1: Nuclear - Start Over with Different Approach
1. **Use Alpine Virtual ISO instead of Standard:**
   ```bash
   cd ~/GitHub/scripts/inspection-sandbox
   mv alpine.iso alpine-standard-broken.iso
   curl -L -o alpine.iso "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.1-x86_64.iso"
   ```
   - Alpine virt has 9p support built-in
   - VirtFS shared folders should work
   - Can use shared folder for SSH key instead of HTTP server

2. **Recreate VM from scratch:**
   ```bash
   ./setup_sandbox.sh burn
   ./setup_sandbox.sh
   # Then recreate VM in UTM with alpine-virt ISO
   ```

### Option 2: Debug Current VM (Masochistic)
1. **In VM console, check SSH config:**
   ```bash
   cat /etc/ssh/sshd_config
   ```
   Look for:
   - PermitRootLogin (should be "yes" or "prohibit-password")
   - PasswordAuthentication (should be "yes" temporarily)
   - PubkeyAuthentication (should be "yes")

2. **Check if authorized_keys actually has content:**
   ```bash
   cat /root/.ssh/authorized_keys
   wc -l /root/.ssh/authorized_keys
   ```

3. **Check SSH logs for errors:**
   ```bash
   tail -50 /var/log/messages | grep sshd
   ```

4. **Try creating sshd_config from scratch:**
   ```bash
   cat > /etc/ssh/sshd_config << 'EOF'
   Port 22
   PermitRootLogin yes
   PasswordAuthentication yes
   PubkeyAuthentication yes
   AuthorizedKeysFile .ssh/authorized_keys
   ChallengeResponseAuthentication no
   UsePAM no
   Subsystem sftp /usr/lib/ssh/sftp-server
   EOF
   service sshd restart
   ```

### Option 3: Alternative VM Solution
Consider using **VirtualBox** instead of UTM:
- Better Alpine Linux support
- More reliable port forwarding
- Shared folders work better
- `brew install --cask virtualbox`

### Option 4: Use Docker Instead (Simplest)
Forget VMs entirely, use Docker:
```bash
docker run -it --rm -v $(pwd)/shared:/shared:ro alpine:latest sh
```
- No VM overhead
- Shared folders just work
- Much simpler
- Can still be isolated

## Files That Need Updating

All setup scripts assume things work that don't:

1. **setup_sandbox.sh** - Works fine
2. **create-vm.sh** - Needs Alpine virt ISO recommendation
3. **provision-vm.sh** - Needs debugging steps for broken SSH
4. **inspect.sh** - Can't work until SSH works
5. **README.md** - Too optimistic, needs troubleshooting
6. **ACTUAL-WORKING-SETUP.md** - Ironically, doesn't work

## The Fundamental Issues

1. **UTM + Alpine + Emulate mode = Pain**
   - Port forwarding unreliable
   - Shared folders don't work
   - UEFI boot issues

2. **Standard Alpine ISO is wrong choice**
   - No 9p/VirtFS support
   - Need alpine-virt ISO

3. **Too many manual steps**
   - Clipboard disabled = can't paste SSH key
   - Console-only access = nightmare
   - Should have automated more

4. **SSH is a house of cards**
   - One wrong config = locked out
   - Password and key auth both broken
   - Can't fix from outside

## Lessons Learned

1. ❌ Don't use standard Alpine ISO for VMs - use alpine-virt
2. ❌ Don't disable clipboard until AFTER setup is complete
3. ❌ Don't rely on UTM port forwarding in Emulate mode
4. ❌ Don't set prohibit-password until key auth is VERIFIED working
5. ✅ Test SSH works before isolating the network
6. ✅ Keep a way to recover (console access, password auth)
7. ✅ Consider simpler alternatives (Docker, VirtualBox)

## Recommended Path Forward

**When you're ready to try again:**

1. Use **alpine-virt ISO** (has 9p support)
2. Use **VirtualBox** instead of UTM (more reliable)
3. OR use **Docker** (simplest, no VMs)
4. Don't disable clipboard until confirmed working
5. Don't isolate network until SSH confirmed working
6. Test everything before locking down

## Current VM Can Be Salvaged?

**Maybe.** The VM console still works. You could:

1. Manually type in the SSH public key character by character (masochistic)
2. Boot from ISO again and access the installed system to fix configs
3. Or just nuke it and start over with a better approach

## Bottom Line

**This setup method is fundamentally broken.** It relies on too many things that don't work:
- VirtFS that isn't supported
- Port forwarding that's unreliable
- Manual steps that are error-prone

**Better approach:** Use alpine-virt ISO or switch to VirtualBox/Docker.

---

**Status:** Currently broken, need to start over with different approach.

**Mood:** Extremely frustrated (understandably)

**Next session:** Try alpine-virt ISO or VirtualBox instead
