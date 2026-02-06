# Build & Compilation Issues

## MANDATORY 5-Minute / 3-Attempt Escalation Policy

**When encountering build/compilation errors:**

1. **After 5 minutes OR 3 failed attempts**, STOP
2. **Generate Perplexity.ai prompt** with:
   - Exact error message
   - Environment details (Xcode version, OS version, tool versions)
   - Project structure (Flutter/React/Go/etc.)
   - Steps already attempted
   - Full dependency chain if applicable

3. **DO NOT continue troubleshooting** without external research
4. **Use Perplexity's findings** to guide solution

**Example Escalation**:

```
Perplexity.ai Query:

Xcode 16 build error with CocoaPods:

Error: "The file couldn't be opened because there is no such file"
Context:
- Xcode 16.0 on macOS 14.5
- Flutter 3.24.0
- CocoaPods 1.15.2
- Project: Flutter iOS app with Share Extension

Error occurs during:
`xcodebuild build -scheme Runner -configuration Debug`

Attempted fixes:
1. flutter clean && flutter pub get
2. cd ios && pod deintegrate && pod install
3. Deleted DerivedData

Full error:
[paste complete error trace]
```

**Why This Matters**: Build toolchain issues often have known solutions. Spending 30+ minutes on trial-and-error wastes time when a 2-minute search reveals the answer.

## Platform-Specific Build Rules

**iOS**:
- ❌ NEVER use `flutter build ios` (gets confused by multiple schemes)
- ✅ ALWAYS use `xcodebuild` directly
- ✅ Let Xcode build phases call Flutter compilation

**Android**:
- ❌ NEVER use `flutter build apk` for complex builds
- ✅ ALWAYS use `./gradlew assembleDebug` directly
- ✅ Use Gradle configurations (debug, release, profile)

**Go**:
- ✅ ALWAYS run `go build` after linting fixes
- ✅ Check for unused imports (common after removing functions)

## Build Hygiene

### CRITICAL: Never Modify Source Files In Place

**All build scripts MUST output to a separate `build/` or `dist/` directory.**

```bash
# ❌ WRONG: Modifies source files
./build.sh  # Writes to src/generated.ts

# ✅ CORRECT: Outputs to build directory
./build.sh  # Writes to build/generated.ts
```

**Why**: Prevents accidental source code corruption and ensures reproducible builds.

**If you detect this happening**:
1. IMMEDIATELY alert the user
2. Fix the build scripts (this is a critical error)
3. Work stoppage until fixed

