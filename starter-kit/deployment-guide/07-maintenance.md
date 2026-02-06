# Maintenance

## Keeping Deployed Materials Up-to-Date

### When Starter-Kit Updates

If the starter-kit is updated in the source repository, you may need to update deployed materials.

**Check for updates**:
```bash
# Compare deployed files with starter-kit
diff docs/SAFETY_NET.md starter-kit/SAFETY_NET.md
diff scripts/lib/common.sh starter-kit/common.sh
```

**Update process**:
1. Review changes in starter-kit
2. Merge relevant changes into deployed files
3. Re-run validation
4. Commit updates

### Regular Maintenance Tasks

**Monthly**:
- [ ] Review .gitignore for new artifact patterns
- [ ] Update .env.example for new environment variables
- [ ] Check for deprecated validation rules

**Quarterly**:
- [ ] Test setup scripts on fresh VM
- [ ] Review and update CLAUDE.md protocols
- [ ] Audit pre-commit hooks effectiveness

## Questions to Ask

When deploying or maintaining starter-kit materials, ask the user:

1. **"What tech stack are you using?"** - Determines which sections to deploy/customize
2. **"Do you have existing .gitignore or .env files?"** - Determines merge vs. copy strategy
3. **"What's your deployment target?"** - Affects setup script customization
4. **"Are there project-specific safety nets needed?"** - Identifies custom validation rules

