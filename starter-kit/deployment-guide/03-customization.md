# Customization Guidelines

## Project Name Replacement

Replace all instances of "your-project" with the actual project name:

```bash
# In all deployed files
find docs scripts -type f -exec sed -i '' 's/your-project/actual-project-name/g' {} +
```

## SAFETY_NET.md Customization

1. **Replace project name** throughout
2. **Remove unused sections** (e.g., Flutter-specific if not using Flutter)
3. **Add project-specific safety nets** (custom validation rules)

## CLAUDE.md Customization

Extract relevant sections from `DEVELOPMENT_PROTOCOLS.md`:

1. **Git Workflow** - Keep as-is
2. **Build & Compilation** - Customize for your tech stack
3. **Code Quality Gates** - Add project-specific linters
4. **Token Conservation** - Keep as-is

Add project-specific sections:

```markdown
## Project-Specific Protocols

### Database Migrations

- Always create migration scripts
- Test migrations on staging first
- Never run migrations manually in production

### API Changes

- Update OpenAPI spec before implementation
- Run contract tests after changes
- Version breaking changes
```

## .gitignore Customization

Remove unused sections:

```bash
# If not using Flutter, remove:
.dart_tool/
*.g.dart

# If not using Go, remove:
vendor/
*.mod
```

Add project-specific patterns:

```gitignore
# Project-specific build artifacts
custom-build-output/
generated-files/
```

## .env.example Customization

Replace template variables with actual project variables:

```bash
# Template
API_KEY=your-api-key-here

# Customized
OPENAI_API_KEY=sk-...
STRIPE_API_KEY=sk_test_...
DATABASE_URL=postgresql://localhost:5432/mydb
```

## Setup Scripts Customization

Update `scripts/setup-components/60-project.sh`:

```bash
install_project_dependencies() {
  log_info "Installing project dependencies..."
  
  # Add your project-specific dependencies
  brew install postgresql
  brew install redis
  
  # Start services
  brew services start postgresql
  brew services start redis
  
  log_info "Project dependencies installed"
}
```

