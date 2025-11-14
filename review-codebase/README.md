# Codebase Reviewer

AI-powered codebase analysis and onboarding tool that generates structured prompts for systematic code review.

## Overview

Codebase Reviewer analyzes repositories to help teams:
- **Onboard new engineers faster** with structured learning paths
- **Review large codebases systematically** using AI-optimized prompts
- **Identify technical debt and documentation drift** automatically
- **Generate actionable remediation plans** prioritized by impact

## Key Features

### Documentation-First Analysis
- Analyzes project documentation (README, architecture docs, setup guides) **before** code
- Extracts testable claims about architecture, setup, and features
- Validates documentation against actual code implementation
- Identifies drift, gaps, and outdated information

### Multi-Phase Prompt Generation
Generates AI prompts in 5 progressive phases:

1. **Phase 0: Documentation Review** - Extract claims from docs
2. **Phase 1: Architecture Analysis** - Validate architecture against code
3. **Phase 2: Implementation Deep-Dive** - Code quality, patterns, observability
4. **Phase 3: Development Workflow** - Setup validation, testing strategy
5. **Phase 4: Interactive Remediation** - Prioritized action planning

### Comprehensive Analysis
- Programming language and framework detection
- Dependency analysis and health checks
- Code quality assessment (TODOs, security issues, technical debt)
- Architecture pattern detection and validation
- Setup instruction validation

## Installation

```bash
# Clone the repository
cd review-codebase

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install in development mode
pip install -e .
```

## Usage

### Command-Line Interface

#### Basic Analysis
```bash
# Analyze a repository
python -m codebase_reviewer analyze /path/to/repo

# Analyze with output files
python -m codebase_reviewer analyze /path/to/repo \
    --output analysis.json \
    --prompts-output prompts.md

# Quiet mode (minimal output)
python -m codebase_reviewer analyze /path/to/repo --quiet
```

#### View Prompts
```bash
# Display all generated prompts
python -m codebase_reviewer prompts /path/to/repo

# Display specific phase only
python -m codebase_reviewer prompts /path/to/repo --phase 0
```

### Web Interface

#### Start Web Server
```bash
# Start web interface on default port (5000)
python -m codebase_reviewer web

# Specify custom host and port
python -m codebase_reviewer web --host 0.0.0.0 --port 8080

# Run in debug mode
python -m codebase_reviewer web --debug
```

Then open your browser to `http://127.0.0.1:5000`

**Features:**
- 🎨 Clean, modern interface
- 📊 Real-time analysis progress
- 📈 Visual metrics dashboard
- 💾 Download prompts (Markdown/JSON)
- 📁 Export analysis results

### Example Output

```
Codebase Reviewer - Analyzing: /home/user/my-project

  Phase 0: Analyzing documentation...
  Found 8 documentation files
  Extracted 12 testable claims
  Phase 1-2: Analyzing code structure...
  Detected 2 languages
  Detected 3 frameworks
  Found 45 quality issues
  Validation: Comparing documentation vs code...
  Found 3 documentation drift issues
  Drift severity: medium
  Generating AI prompts...
  Generated 11 AI prompts across 5 phases
  Analysis complete in 2.34 seconds

============================================================
ANALYSIS SUMMARY
============================================================

Documentation:
  Files found: 8
  Completeness: 75.0%
  Claims extracted: 12
  Architecture: microservices

Code Structure:
  Python: 85.3%
  Shell: 14.7%
  Frameworks: Flask, Docker
  Quality issues: 45

Validation:
  Drift severity: MEDIUM
  Drift issues: 3
  Undocumented features: 2

Generated Prompts:
  Total prompts: 11
  Phase 0 (Documentation Review): 3
  Phase 1 (Architecture Analysis): 2
  Phase 2 (Implementation Deep-Dive): 2
  Phase 3 (Development Workflow): 2
  Phase 4 (Interactive Remediation): 2

Completed in 2.34 seconds
```

## Architecture

### Core Components

```
┌─────────────────────────────────────────┐
│       Analysis Orchestrator              │
│  (Coordinates analysis pipeline)         │
└─────────────────────────────────────────┘
                   │
      ┌────────────┼────────────┐
      │            │            │
┌─────▼─────┐ ┌───▼────┐ ┌────▼──────┐
│   Docs    │ │  Code  │ │Validation │
│ Analyzer  │ │Analyzer│ │  Engine   │
└───────────┘ └────────┘ └───────────┘
      │            │            │
      └────────────┼────────────┘
                   │
           ┌───────▼────────┐
           │     Prompt     │
           │   Generator    │
           └────────────────┘
```

### Analysis Flow

1. **Documentation Analyzer**: Discovers and analyzes all markdown/documentation files
2. **Code Analyzer**: Analyzes repository structure, languages, frameworks, dependencies
3. **Validation Engine**: Cross-checks documentation claims against code reality
4. **Prompt Generator**: Creates structured AI prompts incorporating findings

## Generated Prompts

Prompts are designed to guide AI assistants (Claude, GPT-4, Gemini) through systematic code review:

### Phase 0: Documentation Review
- README analysis and claims extraction
- Architecture documentation review
- Setup and build documentation assessment

### Phase 1: Architecture Analysis
- Architecture validation against code
- Dependency analysis and health checks

### Phase 2: Implementation Deep-Dive
- Code quality and technical debt assessment
- Observability and operational maturity review

### Phase 3: Development Workflow
- Setup instruction validation
- Testing strategy assessment

### Phase 4: Interactive Remediation
- Issue prioritization and action planning

## Output Formats

### JSON Analysis Results
```json
{
  "repository_path": "/path/to/repo",
  "timestamp": "2025-11-14T10:30:00",
  "documentation": {
    "total_docs": 8,
    "completeness_score": 75.0,
    "claims_count": 12
  },
  "code": {
    "languages": [{"name": "Python", "percentage": 85.3}],
    "frameworks": ["Flask", "Docker"],
    "quality_issues_count": 45
  },
  "validation": {
    "drift_severity": "medium",
    "architecture_drift_count": 2,
    "setup_drift_count": 1
  }
}
```

### Markdown Prompts
```markdown
# AI Code Review Prompts

## Phase 0: Documentation Review

### Prompt 0.1: README Analysis & Claims Extraction

**Objective:** Extract and catalog all claims about project architecture...

**Tasks:**
- Identify the stated project purpose and scope
- List all claimed technologies and frameworks
- Extract documented architecture pattern
...
```

## Use Cases

### 1. New Team Member Onboarding
```bash
# Generate comprehensive onboarding prompts
python -m codebase_reviewer analyze /path/to/repo --prompts-output onboarding.md

# New team member uses prompts with AI assistant (Claude, GPT-4, etc.)
# AI walks through architecture, patterns, setup process
```

### 2. Technical Debt Assessment
```bash
# Analyze codebase for quality issues and drift
python -m codebase_reviewer analyze /path/to/repo --output assessment.json

# Review drift severity and quality issues
# Use Phase 4 prompts to prioritize remediation
```

### 3. Documentation Audit
```bash
# Check documentation completeness and accuracy
python -m codebase_reviewer analyze /path/to/repo

# Review documentation completeness score
# Identify undocumented features and drift
```

## Configuration

Default behavior can be customized by modifying analyzer classes:

- **DocumentationAnalyzer**: Add custom documentation patterns
- **CodeAnalyzer**: Extend language/framework detection
- **ValidationEngine**: Customize validation rules
- **PromptGenerator**: Modify prompt templates

## Development

### Running Tests
```bash
# Install development dependencies
pip install -e ".[dev]"

# Run tests
pytest tests/

# Run with coverage
pytest --cov=codebase_reviewer tests/
```

### Linting
```bash
# Run pylint
pylint src/codebase_reviewer

# Run mypy
mypy src/codebase_reviewer

# Format with black
black src/codebase_reviewer
```

## Project Structure

```
review-codebase/
├── src/
│   └── codebase_reviewer/
│       ├── __init__.py
│       ├── __main__.py
│       ├── cli.py                 # Command-line interface
│       ├── models.py              # Data models
│       ├── orchestrator.py        # Analysis orchestrator
│       ├── prompt_generator.py    # Prompt generation
│       └── analyzers/
│           ├── __init__.py
│           ├── documentation.py   # Documentation analyzer
│           ├── code.py            # Code analyzer
│           └── validation.py      # Validation engine
├── tests/                         # Test suite
├── requirements.txt               # Dependencies
├── setup.py                       # Package setup
├── PRD.md                         # Product requirements
├── DESIGN.md                      # Technical design
└── README.md                      # This file
```

## Design Philosophy

1. **Documentation-First**: Always analyze docs before code to understand claims
2. **Progressive Disclosure**: Layer information from high-level to detailed
3. **Validation-Centric**: Cross-check documentation against reality
4. **AI-Optimized**: Generate prompts designed for AI assistant workflows
5. **Actionable**: Produce prioritized, executable recommendations

## Limitations

- Static analysis only (no code execution)
- Best suited for repositories with documentation
- Initial release supports Python, JavaScript/TypeScript, Java, C#, Go, Ruby, Shell
- Large repositories (>1GB) may require significant processing time

## Future Enhancements

- Web interface for interactive analysis
- Direct AI model integration (API calls)
- Historical analysis (code evolution over time)
- Team contribution pattern analysis
- IDE integration (VS Code, JetBrains)
- Custom plugin system for analyzers

## Contributing

This tool is designed for extension:

1. **Add Language Support**: Extend `LANGUAGE_EXTENSIONS` in `code.py`
2. **Add Framework Detection**: Update `FRAMEWORK_PATTERNS` in `code.py`
3. **Add Documentation Patterns**: Modify `DOCUMENTATION_PATTERNS` in `documentation.py`
4. **Custom Validation Rules**: Extend `ValidationEngine` class
5. **Custom Prompts**: Modify `PromptGenerator` methods

## License

MIT License - see LICENSE file

## Authors

Engineering Excellence Team

---

**Built with high standards. Tested on real codebases.**

## Claude Skill

A Claude skill is available for interactive codebase review within Claude conversations.

**Location**: `~/.skills/codebase-review/skill.md`

**Usage**: Simply ask Claude to review a codebase, and the skill will guide a systematic multi-phase analysis:
- Phase 0: Documentation review and claims extraction
- Phase 1: Architecture validation against code
- Phase 2: Implementation analysis (quality, security, observability)  
- Phase 3: Development workflow validation
- Phase 4: Interactive remediation planning

The skill follows the same documentation-first methodology as this tool.
