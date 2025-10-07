# PKI Security - How Keys Are Managed

## Overview

This project uses a **secure PKI management system** where cryptographic keys are:
- ✅ **Stored in .env** (single source of truth)
- ✅ **Never committed to git**
- ✅ **Auto-generated on setup**
- ✅ **Extracted to temporary files as needed**

## Security Model

### .env as Single Source of Truth

All PKI assets are stored in `.env`:
```bash
SSH_PRIVATE_KEY_B64="<base64-encoded-private-key>"
SSH_PUBLIC_KEY="ssh-rsa AAAA..."
```

**Why Base64 encoding?**
- Prevents issues with newlines and special characters
- Makes the key safe to store as a single-line environment variable
- Easy to extract when needed

### Files in .gitignore

The following files are **NEVER committed to git**:
```
.env              # Contains the actual keys (single source of truth)
id_rsa            # Temporary runtime file (extracted from .env)
id_rsa.pub        # Temporary runtime file (extracted from .env)
```

### How It Works

1. **Initial Setup:**
   ```bash
   ./setup_sandbox.sh
   ```
   - Creates `.env` from `.env.example` template
   - Generates fresh SSH key pair
   - Stores private key in `.env` as Base64
   - Stores public key in `.env` as plaintext
   - Extracts keys to temporary files (`id_rsa`, `id_rsa.pub`)

2. **Subsequent Runs:**
   ```bash
   ./setup_sandbox.sh
   ```
   - Checks if keys exist in `.env`
   - If found: extracts to temporary files
   - If not found: generates new keys and stores in `.env`

3. **Runtime Usage:**
   - Scripts load keys from `.env`
   - Extract to temporary files as needed
   - Use temporary files for SSH operations
   - Temporary files persist but are gitignored

## For Repository Cloners

When you clone this repo:

1. **Run setup:**
   ```bash
   cd inspection-sandbox
   ./setup_sandbox.sh
   ```

2. **What happens:**
   - `.env` is created (not in repo)
   - Fresh SSH keys are generated
   - Keys are stored in `.env`
   - You're ready to build the VM

3. **Your keys are unique:**
   - Each clone gets its own keys
   - No shared credentials across users
   - Secure by default

## For Contributors

### Adding New Secrets

If you need to add new credentials:

1. **Add to .env:**
   ```bash
   NEW_SECRET="value"
   ```

2. **Add to .env.example:**
   ```bash
   NEW_SECRET=""
   ```

3. **Add to .gitignore if it's a file:**
   ```
   new_secret_file.key
   ```

### Verification Checklist

Before committing:
- [ ] Run `git status` - ensure no PKI files are staged
- [ ] Check `.gitignore` - ensure sensitive files are listed
- [ ] Verify `.env` is NOT in the repo
- [ ] Confirm `.env.example` has no actual secrets

## Security Best Practices

### ✅ DO:
- Store credentials in `.env`
- Add sensitive files to `.gitignore`
- Use `.env.example` as a template
- Rotate keys regularly
- Keep `.env` out of version control

### ❌ DON'T:
- Commit `.env` to git
- Share your `.env` file
- Store plaintext secrets in code
- Use the same keys across environments
- Commit PKI files (id_rsa, id_rsa.pub, etc.)

## Troubleshooting

### Keys Not Working?

1. **Check .env exists:**
   ```bash
   ls -la .env
   ```

2. **Verify keys are in .env:**
   ```bash
   grep SSH_PRIVATE_KEY_B64 .env
   grep SSH_PUBLIC_KEY .env
   ```

3. **Regenerate if corrupted:**
   ```bash
   rm .env id_rsa id_rsa.pub
   ./setup_sandbox.sh
   ```

### Accidentally Committed Keys?

1. **Remove from git:**
   ```bash
   git rm --cached id_rsa id_rsa.pub
   git commit -m "Remove accidentally committed PKI files"
   ```

2. **Rotate keys:**
   ```bash
   rm .env id_rsa id_rsa.pub
   ./setup_sandbox.sh
   ```

3. **Update VM:**
   - Copy new public key to VM
   - Test SSH connection
   - Verify old key no longer works

## Architecture

```
Repository (git)
├── .env.example          ✅ Committed (template only)
├── .gitignore            ✅ Committed (protects secrets)
├── setup_sandbox.sh      ✅ Committed (key generation logic)
└── [other files]         ✅ Committed

Local Directory (gitignored)
├── .env                  ❌ NOT committed (contains actual keys)
├── id_rsa                ❌ NOT committed (temporary runtime file)
├── id_rsa.pub            ❌ NOT committed (temporary runtime file)
└── shared/
    └── id_rsa.pub        ❌ NOT committed (copied for VM access)
```

## Why This Approach?

**Traditional approach (BAD):**
- Keys stored as files
- Easily committed by mistake
- Shared across users
- Hard to rotate

**Our approach (GOOD):**
- Keys in `.env` (gitignored)
- Impossible to commit accidentally
- Unique per user/environment
- Easy to regenerate

**Benefits:**
1. **Security:** Keys never enter git history
2. **Convenience:** Auto-generated on setup
3. **Simplicity:** One command to get started
4. **Scalability:** Easy to add more secrets
5. **Auditability:** Clear separation of secrets and code

## Summary

- 🔐 **PKI assets are in .env only**
- 🚫 **Never committed to git**
- 🤖 **Auto-generated and managed by scripts**
- 📁 **Temporary files are gitignored**
- ✅ **Secure by default**

This ensures that cryptographic material stays private while making the setup process seamless for all users.
