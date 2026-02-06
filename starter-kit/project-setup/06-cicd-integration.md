# Phase 5: CI/CD Integration (30 minutes)

## 5.1 Create GitHub Actions Workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run P1 validation
      run: ./validate-monorepo.sh --p1
    
    - name: Run medium validation
      run: ./validate-monorepo.sh --med
    
    - name: Run full validation
      run: ./validate-monorepo.sh --all
```

## 5.2 Add Go Support (if applicable)

Add to `.github/workflows/ci.yml`:

```yaml
    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
    
    - name: Build Go code
      run: go build ./...
    
    - name: Test Go code
      run: go test ./...
```

## 5.3 Add Python Support (if applicable)

Add to `.github/workflows/ci.yml`:

```yaml
    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'
    
    - name: Install Python dependencies
      run: pip install -r requirements.txt
    
    - name: Run Python tests
      run: pytest
```

## 5.4 Create Deployment Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Deploy to AWS
      run: ./scripts/deploy.sh
```

## Verification

```bash
# Push to GitHub and check Actions tab
git add .github/workflows/
git commit -m "Add CI/CD workflows"
git push origin main

# Visit: https://github.com/YOUR_ORG/YOUR_REPO/actions
```

