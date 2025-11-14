# AI Code Review Prompts

## Phase 0: Documentation Review

### Prompt 0.1: README Analysis & Claims Extraction

**Objective:** Extract and catalog all claims about project architecture, features, and setup from the README

**Tasks:**
- Identify the stated project purpose and scope
- List all claimed technologies and frameworks
- Extract documented architecture pattern (if any)
- Note all setup/installation claims
- Catalog documented features and capabilities
- Identify any architectural diagrams or descriptions
- Note what version of languages/frameworks are claimed

**Deliverable:** Structured list of testable claims with source locations for validation against code

**Context:**
```json
{
  "readme_content": "# Codebase Reviewer\n\nAI-powered codebase analysis and onboarding tool that generates structured prompts for systematic code review.\n\n## Overview\n\nCodebase Reviewer analyzes repositories to help teams:\n- **Onboard new engineers faster** with structured learning paths\n- **Review large codebases systematically** using AI-optimized prompts\n- **Identify technical debt and documentation drift** automatically\n- **Generate actionable remediation plans** prioritized by impact\n\n## Key Features\n\n### Documentation-First Analysis\n- Analyzes project documentation (README, architecture docs, setup guides) **before** code\n- Extracts testable claims about architecture, setup, and features\n- Validates documentation against actual code implementation\n- Identifies drift, gaps, and outdated information\n\n### Multi-Phase Prompt Generation\nGenerates AI prompts in 5 progressive phases:\n\n1. **Phase 0: Documentation Review** - Extract claims from docs\n2. **Phase 1: Architecture Analysis** - Validate architecture against code\n3. **Phase 2: Implementation Deep-Dive** - Code quality, patterns, observability\n4. **Phase 3: Development Workflow** - Setup validation, testing strategy\n5. **Phase 4: Interactive Remediation** - Prioritized action planning\n\n### Comprehensive Analysis\n- Programming language and framework detection\n- Dependency analysis and health checks\n- Code quality assessment (TODOs, security issues, technical debt)\n- Architecture pattern detection and validation\n- Setup instruction validation\n\n## Installation\n\n```bash\n# Clone the repository\ncd codebase-reviewer\n\n# Create virtual environment\npython3 -m venv venv\nsource venv/bin/activate  # On Windows: venv\\Scripts\\activate\n\n# Install dependencies\npip install -r requirements.txt\n\n# Install in development mode\npip install -e .\n```\n\n## Usage\n\n### Command-Line Interface\n\n#### Basic Analysis\n```bash\n# Analyze a repository\npython -m codebase_reviewer analyze /path/to/repo\n\n# Analyze with output files\npython -m codebase_reviewer analyze /path/to/repo \\\n    --output analysis.json \\\n    --prompts-output prompts.md\n\n# Quiet mode (minimal output)\npython -m codebase_reviewer analyze /path/to/repo --quiet\n```\n\n#### View Prompts\n```bash\n# Display all generated prompts\npython -m codebase_reviewer prompts /path/to/repo\n\n# Display specific phase only\npython -m codebase_reviewer prompts /path/to/repo --phase 0\n```\n\n### Web Interface\n\n#### Start Web Server\n```bash\n# Start web interface on default port (5000)\npython -m codebase_reviewer web\n\n# Specify custom host and port\npython -m codebase_reviewer web --host 0.0.0.0 --port 8080\n\n# Run in debug mode\npython -m codebase_reviewer web --debug\n```\n\nThen open your browser to `http://127.0.0.1:5000`\n\n**Features:**\n- \ud83c\udfa8 Clean, modern interface\n- \ud83d\udcca Real-time analysis progress\n- \ud83d\udcc8 Visual metrics dashboard\n- \ud83d\udcbe Download prompts (Markdown/JSON)\n- \ud83d\udcc1 Export analysis results\n\n### Example Output\n\n```\nCodebase Reviewer - Analyzing: /home/user/my-project\n\n  Phase 0: Analyzing documentation...\n  Found 8 documentation files\n  Extracted 12 testable claims\n  Phase 1-2: Analyzing code structure...\n  Detected 2 languages\n  Detected 3 frameworks\n  Found 45 quality issues\n  Validation: Comparing documentation vs code...\n  Found 3 documentation drift issues\n  Drift severity: medium\n  Generating AI prompts...\n  Generated 11 AI prompts across 5 phases\n  Analysis complete in 2.34 seconds\n\n============================================================\nANALYSIS SUMMARY\n============================================================\n\nDocumentation:\n  Files found: 8\n  Completeness: 75.0%\n  Claims extracted: 12\n  Architecture: microservices\n\nCode Structure:\n  Python: 85.3%\n  Shell: 14.7%\n  Frameworks: Flask, Docker\n  Quality issues: 45\n\nValidation:\n  Drift severity: MEDIUM\n  Drift issues: 3\n  Undocumented features: 2\n\nGenerated Prompts:\n  Total prompts: 11\n  Phase 0 (Documentation Review): 3\n  Phase 1 (Architecture Analysis): 2\n  Phase 2 (Implementation Deep-Dive): 2\n  Phase 3 (Development Workflow): 2\n  Phase 4 (Interactive Remediation): 2\n\nCompleted in 2.34 seconds\n```\n\n## Architecture\n\n### Core Components\n\n```\n\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n\u2502       Analysis Orchestrator              \u2502\n\u2502  (Coordinates analysis pipeline)         \u2502\n\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n                   \u2502\n      \u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n      \u2502            \u2502            \u2502\n\u250c\u2500\u2500\u2500\u2500\u2500\u25bc\u2500\u2500\u2500\u2500\u2500\u2510 \u250c\u2500\u2500\u2500\u25bc\u2500\u2500\u2500\u2500\u2510 \u250c\u2500\u2500\u2500\u2500\u25bc\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n\u2502   Docs    \u2502 \u2502  Code  \u2502 \u2502Validation \u2502\n\u2502 Analyzer  \u2502 \u2502Analyzer\u2502 \u2502  Engine   \u2502\n\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518 \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518 \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n      \u2502            \u2502            \u2502\n      \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n                   \u2502\n           \u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u25bc\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n           \u2502     Prompt     \u2502\n           \u2502   Generator    \u2502\n           \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n```\n\n### Analysis Flow\n\n1. **Documentation Analyzer**: Discovers and analyzes all markdown/documentation files\n2. **Code Analyzer**: Analyzes repository structure, languages, frameworks, dependencies\n3. **Validation Engine**: Cross-checks documentation clai",
  "readme_path": "README.md",
  "total_docs_found": 1
}
```

---

### Prompt 0.3: Setup & Build Documentation Review

**Objective:** Understand the documented development workflow and prerequisites

**Tasks:**
- List all documented prerequisite requirements (tools, versions, etc.)
- Document the claimed build process step-by-step
- Identify all mentioned environment variables and their purposes
- Note deployment procedures if described
- Identify testing instructions
- Flag any missing or unclear setup steps

**Deliverable:** Development workflow checklist for validation against actual config files

**Dependencies:** 0.1

**Context:**
```json
{
  "prerequisites": [],
  "build_steps": [],
  "environment_vars": [],
  "documented_in": [
    "README.md"
  ]
}
```

---

## Phase 1: Architecture Analysis

### Prompt 1.1: Validate Documented Architecture Against Actual Code

**Objective:** Verify if actual code structure matches documented architecture claims

**Tasks:**
- Compare claimed architectural pattern vs actual implementation
- Verify documented modules/layers exist in code
- Check if technology stack matches documentation
- Identify undocumented components or services
- Flag any significant documentation inaccuracies
- Assess overall architecture quality and appropriateness

**Deliverable:** Architecture validation report with discrepancies highlighted and recommendations

**Dependencies:** 0.1, 0.2

**Context:**
```json
{
  "claimed_architecture": {
    "pattern": "microservices",
    "layers": [
      "layer",
      "service",
      "repository"
    ],
    "components": [
      "Core",
      "DocumentationAnalyzer",
      "CodeAnalyzer",
      "ValidationEngine",
      "PromptGenerator"
    ]
  },
  "actual_structure": {
    "languages": [
      {
        "name": "Python",
        "percentage": 100.0
      }
    ],
    "frameworks": [
      "Flask",
      "Django"
    ],
    "entry_points": []
  },
  "validation_results": [
    {
      "status": "valid",
      "evidence": "Detected frameworks: ['Flask', 'Django']",
      "recommendation": "Architecture pattern appears consistent"
    },
    {
      "status": "partial",
      "evidence": "Found 0/5 claimed components",
      "recommendation": "Review documented component list for accuracy"
    }
  ]
}
```

---

### Prompt 1.2: Dependency Analysis and Health Check

**Objective:** Analyze project dependencies for health, security, and documentation accuracy

**Tasks:**
- Review all external dependencies and their purposes
- Identify any outdated or deprecated dependencies
- Check for potential security concerns
- Verify dependencies match documented prerequisites
- Identify missing dependency documentation
- Assess dependency management practices

**Deliverable:** Dependency health report with recommendations for updates or documentation

**Dependencies:** 0.3

**Context:**
```json
{
  "dependencies": [
    {
      "name": "Flask",
      "version": "3.0.0",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "Jinja2",
      "version": "3.1.2",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "GitPython",
      "version": "3.1.40",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "PyYAML",
      "version": "6.0.1",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "click",
      "version": "8.1.7",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "pygments",
      "version": "2.17.2",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "chardet",
      "version": "5.2.0",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "pathspec",
      "version": "0.11.2",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "toml",
      "version": "0.10.2",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "python-dotenv",
      "version": "1.0.0",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "dataclasses-json",
      "version": "0.6.3",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "requests",
      "version": "2.31.0",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "pylint",
      "version": "3.0.3",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "pytest",
      "version": "7.4.3",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "pytest-cov",
      "version": "4.1.0",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "black",
      "version": "23.12.1",
      "type": "production",
      "source": "requirements.txt"
    },
    {
      "name": "mypy",
      "version": "1.7.1",
      "type": "production",
      "source": "requirements.txt"
    }
  ],
  "total_count": 17,
  "documented_prerequisites": []
}
```

---

## Phase 2: Implementation Deep-Dive

### Prompt 2.1: Code Quality and Technical Debt Assessment

**Objective:** Assess code quality, identify technical debt, and security concerns

**Tasks:**
- Review TODO/FIXME comments for patterns and urgency
- Assess potential security issues (hardcoded secrets, etc.)
- Identify areas with high technical debt
- Evaluate error handling patterns
- Assess code organization and modularity
- Identify anti-patterns or code smells

**Deliverable:** Code quality report with prioritized remediation recommendations

**Dependencies:** 1.1

**Context:**
```json
{
  "todo_count": 0,
  "sample_todos": [],
  "security_issues_count": 0,
  "sample_security_issues": []
}
```

---

### Prompt 2.2: Observability and Operational Maturity

**Objective:** Assess logging, monitoring, and operational maturity of the codebase

**Tasks:**
- Evaluate logging practices (coverage, consistency, level usage)
- Identify monitoring and metrics instrumentation
- Check for error tracking integration (Sentry, etc.)
- Assess configuration management approach
- Identify deployment and infrastructure code
- Evaluate operational readiness (health checks, etc.)

**Deliverable:** Observability assessment with gaps and recommendations

**Dependencies:** 1.1

**Context:**
```json
{
  "repository_path": "/home/user/scripts/codebase-reviewer",
  "frameworks": [
    "Flask",
    "Django"
  ]
}
```

---

## Phase 3: Development Workflow

### Prompt 3.1: Validate Setup and Build Instructions

**Objective:** Verify documented setup instructions are accurate and complete

**Tasks:**
- Trace documented setup steps to actual configuration files
- Identify missing prerequisites not documented
- Flag outdated version requirements
- Note environment variables used but not documented
- Identify undocumented build steps or scripts
- Assess overall setup documentation quality

**Deliverable:** Setup documentation accuracy report with specific corrections needed

**Dependencies:** 0.3, 1.2

**Context:**
```json
{
  "documented_setup": {
    "prerequisites": [],
    "build_steps": [],
    "env_vars": []
  },
  "validation_results": [],
  "undocumented_features": [
    "Framework: Django"
  ]
}
```

---

### Prompt 3.2: Testing Strategy and Coverage Review

**Objective:** Assess testing practices, coverage, and quality

**Tasks:**
- Identify test types present (unit, integration, e2e)
- Evaluate test organization and naming conventions
- Assess test coverage (estimate based on test file count)
- Identify testing framework and tools used
- Evaluate test quality and maintainability
- Identify gaps in test coverage

**Deliverable:** Testing assessment with recommendations for improvement

**Dependencies:** 1.1

**Context:**
```json
{
  "repository_path": "/home/user/scripts/codebase-reviewer"
}
```

---

## Phase 4: Interactive Remediation

### Prompt 4.1: Interactive Issue Prioritization

**Objective:** Work with user to prioritize identified issues for remediation

**Tasks:**
- Present all issues organized by severity and category
- Ask user about their priorities (security, documentation, quality, etc.)
- Discuss effort estimates for top issues
- Help identify quick wins vs. major refactoring needs
- Create prioritized action plan based on user input
- Suggest grouping related issues into themes

**Deliverable:** Prioritized, actionable remediation plan ready for execution

**Dependencies:** 1.1, 2.1, 3.1

**Context:**
```json
{
  "total_issues": 2,
  "issues_by_severity": {
    "critical": 0,
    "high": 0,
    "medium": 2,
    "low": 0
  },
  "top_issues": [
    {
      "category": "Documentation Drift",
      "severity": "medium",
      "description": "Detected frameworks: ['Flask', 'Django']",
      "recommendation": "Architecture pattern appears consistent"
    },
    {
      "category": "Documentation Drift",
      "severity": "medium",
      "description": "Found 0/5 claimed components",
      "recommendation": "Review documented component list for accuracy"
    }
  ]
}
```

---
