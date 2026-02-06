# Environment Variable Security

## .env File Strategy

**File Hierarchy**:

```
.env.example          # Template (committed to git)
.env                  # Local dev (NEVER commit)
.env.production       # Production (stored in AWS Secrets Manager)
.env.test             # CI/CD (stored in GitHub Secrets)
```

## .env.example Template

```bash
# ------------------------------------------------------------------------------
# AWS Authentication
# - Use `aws configure` instead of setting here (more secure)
# ------------------------------------------------------------------------------
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=

# ------------------------------------------------------------------------------
# AWS Region & Account
# ------------------------------------------------------------------------------
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=your-account-id-here

# ------------------------------------------------------------------------------
# AWS S3 - Web App Hosting
# - CloudFront distribution for Flutter web app
# - Format: https://{CLOUDFRONT_ID}.cloudfront.net
# ------------------------------------------------------------------------------
S3_WEB_APP_BUCKET=your-s3-bucket-name
CLOUDFRONT_DISTRIBUTION_ID=your-cloudfront-id
WEB_APP_URL=https://your-cloudfront-id.cloudfront.net

# ------------------------------------------------------------------------------
# AWS Cognito - User Authentication
# - Find in AWS Console → Cognito → User Pools
# ------------------------------------------------------------------------------
COGNITO_USER_POOL_ID=us-west-2_XXXXXXXXX
COGNITO_APP_CLIENT_ID=your-app-client-id

# ------------------------------------------------------------------------------
# AWS S3 - Asset Storage
# - Use account-specific naming to avoid collisions
# ------------------------------------------------------------------------------
S3_RECIPE_STORAGE_BUCKET=recipearchive-storage-${AWS_ACCOUNT_ID}
S3_TEMP_BUCKET_NAME=recipearchive-temp-${AWS_ACCOUNT_ID}
S3_FAILED_PARSING_BUCKET_NAME=recipearchive-failed-${AWS_ACCOUNT_ID}

# ------------------------------------------------------------------------------
# Testing Credentials (for validate-monorepo.sh)
# - NEVER commit real credentials
# ------------------------------------------------------------------------------
RECIPE_USER_EMAIL=
RECIPE_USER_PASSWORD=
```

## Security Best Practices

**DO**:
- ✅ Use `.env.example` as documentation
- ✅ Add `.env` to `.gitignore`
- ✅ Use AWS Secrets Manager for production
- ✅ Rotate credentials regularly
- ✅ Use IAM roles instead of access keys (when possible)

**DON'T**:
- ❌ Commit `.env` files to git
- ❌ Hardcode credentials in source code
- ❌ Share `.env` files via Slack/email
- ❌ Use production credentials in development
- ❌ Store passwords in plain text

## Loading .env Files

**Shell Scripts**:

```bash
# scripts/load-env.sh
if [ -f ".env" ]; then
  export $(cat .env | grep -v '^#' | xargs)
else
  echo "❌ .env file not found. Copy .env.example to .env"
  exit 1
fi
```

**Node.js**:

```javascript
require('dotenv').config();

const apiUrl = process.env.API_BASE_URL;
if (!apiUrl) {
  throw new Error('API_BASE_URL not set in .env');
}
```

**Go**:

```go
import "github.com/joho/godotenv"

func init() {
  if err := godotenv.Load(); err != nil {
    log.Fatal("Error loading .env file")
  }

  bucketName := os.Getenv("S3_RECIPE_STORAGE_BUCKET")
  if bucketName == "" {
    log.Fatal("S3_RECIPE_STORAGE_BUCKET not set")
  }
}
```

