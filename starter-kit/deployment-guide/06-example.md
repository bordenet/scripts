# Example Deployment Session

## Scenario

User: "I have a new Node.js project. Can you deploy the starter-kit?"

## AI Assistant Response

```
I'll deploy the starter-kit materials to your Node.js project. Here's what I'll do:

1. Create directory structure
2. Deploy core documentation (customized for Node.js)
3. Deploy templates (.gitignore, .env.example, common.sh)
4. Deploy setup scripts (macOS and Linux)
5. Deploy validation system
6. Set up pre-commit hooks

Let me start...
```

## Step-by-Step Execution

### 1. Create Directories

```bash
mkdir -p docs
mkdir -p scripts/lib
mkdir -p scripts/setup-components
mkdir -p .husky
```

### 2. Deploy and Customize SAFETY_NET.md

```bash
cp starter-kit/SAFETY_NET.md docs/SAFETY_NET.md
sed -i '' 's/your-project/my-nodejs-app/g' docs/SAFETY_NET.md
# Remove Flutter-specific sections
```

### 3. Deploy CLAUDE.md

```bash
cp starter-kit/DEVELOPMENT_PROTOCOLS.md CLAUDE.md
# Add Node.js-specific protocols
```

### 4. Deploy Templates

```bash
cp starter-kit/common.sh scripts/lib/common.sh
cat starter-kit/.gitignore.template >> .gitignore
cp starter-kit/.env.template .env.example
# Customize .env.example for Node.js project
```

### 5. Deploy Setup Scripts

```bash
cp starter-kit/setup-macos.sh scripts/setup-macos.sh
chmod +x scripts/setup-macos.sh
# Customize for Node.js dependencies
```

### 6. Deploy Validation

```bash
cp starter-kit/validate-monorepo.sh validate-monorepo.sh
chmod +x validate-monorepo.sh
# Customize for Node.js (npm test, npm run lint)
```

### 7. Set Up Pre-Commit Hooks

```bash
npm install --save-dev husky
npx husky install
# Create hooks
```

### 8. Validate

```bash
./validate-monorepo.sh --all
```

## AI Assistant Final Message

```
Deployment complete! I've:
✅ Created directory structure
✅ Deployed and customized documentation
✅ Set up .gitignore and .env.example
✅ Created setup scripts for macOS and Linux
✅ Configured validation system
✅ Installed pre-commit hooks

Next steps:
1. Review CLAUDE.md for project-specific protocols
2. Update .env.example with your actual environment variables
3. Test the setup script: ./scripts/setup-macos.sh
4. Run validation: ./validate-monorepo.sh --all
```

