# Common Mistakes

## What NOT to Do

### ❌ Don't Copy the Entire starter-kit/ Directory

**Wrong**:
```bash
cp -r starter-kit/ new-project/
```

**Why**: This creates a duplicate directory instead of distributing files to their proper locations.

**Right**: Follow the deployment workflow to distribute files appropriately.

### ❌ Don't Deploy Without Customization

**Wrong**:
```bash
cp starter-kit/SAFETY_NET.md docs/SAFETY_NET.md
git add docs/SAFETY_NET.md
git commit -m "Add safety net"
```

**Why**: File still contains "your-project" placeholders and unused sections.

**Right**: Customize before committing (see Customization Guidelines).

### ❌ Don't Overwrite Existing Files Without Merging

**Wrong**:
```bash
cp starter-kit/.gitignore.template .gitignore  # Overwrites existing!
```

**Why**: Destroys existing project-specific .gitignore rules.

**Right**: Merge the files:
```bash
cat starter-kit/.gitignore.template >> .gitignore
```

### ❌ Don't Skip Validation

**Wrong**:
```bash
# Deploy everything
git add .
git commit -m "Add starter-kit"
git push
```

**Why**: Deployed files may have errors or placeholders.

**Right**: Validate before committing:
```bash
./validate-monorepo.sh --all
```

### ❌ Don't Deploy Files You Don't Need

**Wrong**: Deploy all files even if project doesn't use them.

**Right**: Only deploy relevant files. For example, if not using Flutter, don't deploy Flutter-specific validation rules.

