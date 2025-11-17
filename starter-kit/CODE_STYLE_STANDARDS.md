# Code Style Standards - Cross-Language Guide

**Purpose**: Consolidated coding standards for all languages, ensuring consistent style across the entire codebase.

**Scope**: Go, JavaScript/TypeScript, Dart/Flutter, Swift, Kotlin, Shell Scripts

---

## Core Principles

1. **Consistency over cleverness** - Code should be readable and maintainable
2. **Explicit over implicit** - Make intentions clear
3. **Fail fast** - Validate inputs early, handle errors explicitly
4. **Document the "why"** - Code shows "what", comments explain "why"

---

## Go

### Style Guide

**Import Organization**:

```go
import (
    // Standard library
    "context"
    "encoding/json"
    "fmt"

    // Third-party packages
    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-sdk-go-v2/aws"

    // Local packages
    "yourproject/internal/db"
    "yourproject/pkg/models"
)
```

**Naming Conventions**:

```go
// ✅ Good
var bucketName string           // Unexported: camelCase
var userID string               // Acronyms: all caps
func FetchRecipe()              // Exported: PascalCase
const MaxRetries = 3            // Exported constant

// ❌ Bad
var bucket_name string          // No underscores
var UserId string               // Acronyms should be all caps
func fetchRecipe()              // Exported should be PascalCase
```

**Error Handling**:

```go
// ✅ Good - wrapped errors with context
if err != nil {
    return fmt.Errorf("failed to fetch recipe %s: %w", recipeID, err)
}

// ❌ Bad - lost error context
if err != nil {
    return err
}
```

**Structured Logging** (use `log/slog`):

```go
import "log/slog"

var logger *slog.Logger

func init() {
    logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    }))
}

// ✅ Good - structured fields
logger.Info("recipe created",
    "recipeID", recipeID,
    "userID", userID,
    "duration", duration,
)

// ❌ Bad - string formatting
log.Printf("Recipe %s created by user %s", recipeID, userID)
```

### Compilation Protocol

**MANDATORY**: Always run `go build` after linting fixes

```bash
# 1. Fix linting errors
golangci-lint run ./...

# 2. CRITICAL: Check compilation
go build

# 3. Only declare work complete after BOTH pass
```

---

## JavaScript/TypeScript

### Quote Style

**MANDATORY**: Always use double quotes

```javascript
// ✅ Correct
console.log("Starting authentication");
const url = "https://example.com";

// ❌ Wrong
console.log('Starting authentication');
const url = 'https://example.com';
```

**Enforcement**:

```bash
# Always run after editing JavaScript files
npm run lint -- --fix
```

### Naming Conventions

```javascript
// ✅ Good
const accessToken = "...";                // Variables: camelCase
function extractRecipeData() {}           // Functions: camelCase
class CognitoAuthManager {}               // Classes: PascalCase
const API_ENDPOINT = "https://...";       // Constants: UPPER_SNAKE_CASE

// ❌ Bad
const access_token = "...";               // No underscores
function ExtractRecipeData() {}           // Functions should be camelCase
class cognitoAuthManager {}               // Classes should be PascalCase
```

### Async/Await

```javascript
// ✅ Good - Clear async/await
async function extractRecipe() {
  try {
    const html = await fetchHTML(url);
    const recipe = await parseRecipe(html);
    return recipe;
  } catch (error) {
    console.error("❌ Recipe extraction failed:", error);
    throw error;
  }
}

// ❌ Avoid - Promise chains harder to read
function extractRecipe() {
  return fetchHTML(url)
    .then(html => parseRecipe(html))
    .catch(error => {
      console.error("❌ Recipe extraction failed:", error);
      throw error;
    });
}
```

### Error Handling

```javascript
// ✅ Good - Comprehensive error handling
async function authenticateUser(username, password) {
  try {
    const tokens = await cognito.signIn(username, password);
    await storeTokens(tokens);
    return { success: true };
  } catch (error) {
    console.error("❌ Authentication failed:", error);
    return {
      success: false,
      error: error.message || "Authentication failed"
    };
  }
}
```

### Logging (Browser Extensions)

```javascript
// ✅ Good - Uses emojis for visual distinction in DevTools
console.log("🎯 your-project content script starting...");
console.log("✅ Recipe extraction completed");
console.error("❌ Failed to authenticate:", error);
console.warn("⚠️ Token validation failed");
```

---

## Dart/Flutter

### Structured Logging

**ALWAYS use `AppLogger` for all Dart/Flutter code**

```dart
import "package:recipe_archive/utils/app_logger.dart";

// ✅ Good - Structured logging with metadata
AppLogger.auth.info("User signed in", metadata: {
  "userId": AppLogger.auth.redact(user.id),
  "email": AppLogger.auth.redact(user.email),
});

// ❌ Bad - Using print() for production logging
print("User signed in: ${user.email}");
```

**Log Levels**:
- `debug()` - Development-only verbose output
- `info()` - Normal operations
- `warning()` - Recoverable errors
- `error()` - Critical failures (include `error` and `stackTrace` parameters)

**Privacy Controls**:

```dart
// ✅ Good - Redacted sensitive data
AppLogger.network.error("API request failed",
  metadata: {
    "url": AppLogger.network.redact(url),
    "statusCode": response.statusCode,
  },
  error: error,
  stackTrace: stackTrace,
);

// ❌ Bad - Exposed sensitive data
AppLogger.network.error("API error: $url");  // NEVER log URLs without redaction
```

**Always Redact**:
- Email addresses
- User IDs
- Recipe titles
- URLs (may contain auth tokens)
- Authentication tokens

**Never Log** (even redacted):
- Passwords
- API keys
- Session data

---

## Swift

### Structured Logging

**Use Apple's native `os.Logger`**

```swift
import os

enum AppLogger {
    static let shareExtension = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ShareExtension")
    static let webView = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WebView")
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Network")
}

// ✅ Good - Privacy annotation
logger.error("Network request failed",
    url: "\(url, privacy: .private)",
    statusCode: statusCode,
    error: "\(error.localizedDescription)"
)

// ❌ Bad - No privacy annotation
logger.error("Network request failed: \(url)")
```

**Privacy Levels**:
- **Public**: Operation types, counts, durations
- **Private** (default): URLs, recipe titles, user identifiers
- **Sensitive**: Authentication tokens, passwords (never logged)

**Log Levels**:
- **Debug**: Development-only verbose output
- **Info**: Normal operations
- **Notice**: Significant events (cache miss, fallback)
- **Warning**: Recoverable errors
- **Error**: Critical failures
- **Fault**: Unrecoverable errors

---

## Kotlin

### Naming Conventions

```kotlin
// ✅ Good
class RecipeParser                  // Classes: PascalCase
fun parseRecipe()                   // Functions: camelCase
val maxRetries = 3                  // Variables: camelCase
const val API_ENDPOINT = "..."      // Constants: UPPER_SNAKE_CASE

// ❌ Bad
class recipeParser                  // Wrong
fun ParseRecipe()                   // Wrong
val MAX_RETRIES = 3                 // val should be camelCase
```

### Null Safety

```kotlin
// ✅ Good - Safe null handling
val recipe: Recipe? = getRecipe(id)
recipe?.let {
    processRecipe(it)
}

// ❌ Bad - Force unwrap
val recipe: Recipe? = getRecipe(id)
processRecipe(recipe!!)  // Will crash if null
```

---

## Shell Scripts

### Header Template

```bash
#!/usr/bin/env bash

################################################################################
# ProjectName <Script Purpose>
################################################################################
# PURPOSE: <One sentence description>
#
# USAGE:
#   ./<script-name> [options]
#
# EXAMPLES:
#   ./<script-name> --option value
#
# DEPENDENCIES:
#   - Tool 1 (install command)
################################################################################

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
init_script

# Script-specific variables
readonly SCRIPT_NAME="$(basename "$0")"
readonly REPO_ROOT="$(get_repo_root)"
```

### Logging Functions

```bash
# ✅ Good - Use common library functions
log_info "Starting deployment"
log_success "Deployment complete"
log_warning "No .env file found"
log_error "Deployment failed"
die "AWS credentials not found"

# ❌ Bad - Raw echo
echo "Starting deployment"
echo -e "\033[0;32m✓\033[0m Deployment complete"
```

### Variable Naming

```bash
# ✅ Good
readonly SCRIPT_NAME="deploy.sh"     # Constants: UPPERCASE
readonly MAX_RETRIES=3               # Constants: UPPERCASE
BUILD_MODE="debug"                   # Config: UPPERCASE
local build_output="/tmp/build"      # Local: lowercase

# ❌ Bad
script_name="deploy.sh"              # Constants should be UPPERCASE
Max_Retries=3                        # Inconsistent
buildMode="debug"                    # Should be UPPERCASE
local BUILD_OUTPUT="/tmp/build"      # Local should be lowercase
```

### Error Handling

```bash
# ✅ Good - Fail fast with clear messages
if ! aws s3 ls "s3://$BUCKET" &> /dev/null; then
    die "S3 bucket not found: $BUCKET"
fi

# ❌ Bad - Silent failures
aws s3 ls "s3://$BUCKET" || true
```

---

## Common Patterns Across All Languages

### Structured Logging Best Practices

**DO**:
- ✅ Use dedicated logging libraries (not `print`/`console.log` for production)
- ✅ Include context fields (userID, requestID, operation type)
- ✅ Add performance tracking (duration, latency)
- ✅ Redact sensitive data (emails, URLs, user IDs)
- ✅ Use appropriate log levels

**DON'T**:
- ❌ Log authentication tokens, passwords, API keys
- ❌ Log in tight loops (impacts performance)
- ❌ Use string interpolation without privacy controls
- ❌ Mix user-facing and operational logging

### Privacy-First Logging

**Always redact**:
- Email addresses
- User IDs / UUIDs
- Recipe titles (may contain personal information)
- URLs (may contain query parameters or tokens)
- IP addresses
- Session tokens

**Never log** (even redacted):
- Passwords
- API keys
- OAuth tokens
- Credit card numbers
- Social security numbers

### Error Handling

**All languages should**:
1. Validate inputs early
2. Provide context in error messages
3. Include relevant identifiers (IDs, names)
4. Log errors with structured data
5. Never swallow errors silently

### Performance Logging

**Always include timing for**:
- API requests (HTTP calls)
- Database operations (S3, DynamoDB)
- External service calls (OpenAI, Cognito)
- Heavy computations (recipe parsing, normalization)
- User-visible operations (sign in, recipe save)

**Example pattern** (all languages):
```
1. Record start time
2. Perform operation
3. Calculate duration
4. Log with duration metadata
```

---

## Language-Specific Tools

### Go

```bash
# Formatting
gofmt -w .
goimports -w .

# Linting
golangci-lint run ./...

# Testing
go test ./...
```

### JavaScript/TypeScript

```bash
# Linting
npm run lint
npm run lint -- --fix

# Testing
npm test

# Type checking (TypeScript)
npx tsc --noEmit
```

### Dart/Flutter

```bash
# Formatting
dart format .

# Linting
dart analyze

# Testing
flutter test
```

### Swift

```bash
# Formatting (SwiftFormat)
swiftformat .

# Linting (SwiftLint)
swiftlint

# Testing
xcodebuild test -scheme YourScheme
```

### Kotlin

```bash
# Formatting (ktlint)
ktlint -F

# Linting
./gradlew ktlintCheck

# Testing
./gradlew test
```

### Shell Scripts

```bash
# Formatting (shfmt)
shfmt -i 4 -w scripts/*.sh

# Linting (shellcheck)
shellcheck scripts/*.sh
```

---

## Validation Checklist

Before declaring work complete:

### Go
- [ ] `gofmt -w .` (no changes)
- [ ] `golangci-lint run ./...` (pass)
- [ ] `go build` (pass)
- [ ] `go test ./...` (pass)

### JavaScript/TypeScript
- [ ] `npm run lint -- --fix` (no errors)
- [ ] `npm test` (pass)
- [ ] All strings use double quotes

### Dart/Flutter
- [ ] `dart analyze` (pass)
- [ ] `flutter test` (pass)
- [ ] Using `AppLogger` (not `print()`)

### Swift
- [ ] `swiftlint` (pass)
- [ ] Using `os.Logger` (not `print()`)
- [ ] Privacy annotations on sensitive data

### Kotlin
- [ ] `ktlint` (pass)
- [ ] `./gradlew test` (pass)
- [ ] Null safety used correctly

### Shell Scripts
- [ ] Uses `source lib/common.sh`
- [ ] Uses `log_*` functions (not raw `echo`)
- [ ] Has `--help` flag
- [ ] Works from any directory

---

## Customization for Your Project

**To adopt for your project**:

1. Copy this file to `docs/CODING_STANDARDS.md`
2. Remove languages you don't use
3. Add project-specific conventions
4. Add to linter configurations
5. Reference in code reviews

**Project-Specific Extensions**:

```markdown
## ProjectName Conventions

### API Naming
- REST endpoints: `/api/v1/resource-name`
- GraphQL queries: `camelCase`
- Database tables: `snake_case`

### File Naming
- Components: `PascalCase.tsx`
- Utilities: `camelCase.ts`
- Tests: `*.test.ts`
```

---

## Related Documentation

- [DEVELOPMENT_PROTOCOLS.md](DEVELOPMENT_PROTOCOLS.md) - AI-assisted development
- [SHELL_SCRIPT_STANDARDS.md](SHELL_SCRIPT_STANDARDS.md) - Shell script guide
- [SAFETY_NET.md](SAFETY_NET.md) - Automated quality gates

---

**Remember**: Consistent code style reduces cognitive load and makes code reviews faster.
