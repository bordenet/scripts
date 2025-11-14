# Technical Design Specification: Codebase Review & Onboarding Assistant

## 1. System Architecture

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Web Interface (Flask)                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Repository│  │ Analysis │  │ Prompts  │  │ Reports  │   │
│  │Management│  │Dashboard │  │ Viewer   │  │ Export   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓ REST API
┌─────────────────────────────────────────────────────────────┐
│                    Application Core Layer                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Analysis Orchestrator                        │ │
│  │  • Task Queue Management                               │ │
│  │  • Phase Sequencing (Docs → Code → Validation)        │ │
│  │  • Progress Tracking                                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Analysis Engine Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │Documentation │  │   Code       │  │  Validation  │     │
│  │  Analyzer    │→ │  Analyzer    │→ │   Engine     │     │
│  │              │  │              │  │              │     │
│  │• README      │  │• Structure   │  │• Doc vs Code │     │
│  │• CONTRIBUTING│  │• Patterns    │  │• Drift Check │     │
│  │• API Docs    │  │• Quality     │  │• Gap Report  │     │
│  │• Architecture│  │• Dependencies│  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Prompt Generation Layer                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Prompt Template Engine                    │ │
│  │                                                        │ │
│  │  Phase 0: Documentation Review                        │ │
│  │  Phase 1: Architecture Analysis                       │ │
│  │  Phase 2: Implementation Deep-Dive                    │ │
│  │  Phase 3: Development Workflow                        │ │
│  │  Phase 4: Interactive Remediation                     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      Storage Layer                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Repository│  │ Analysis │  │ Prompts  │  │  Cache   │   │
│  │ Metadata │  │ Results  │  │          │  │          │   │
│  │ (SQLite) │  │  (JSON)  │  │  (JSON)  │  │  (Disk)  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Core Design Principles

1. **Documentation-First Analysis**: Always start with markdown/documentation analysis before code inspection
2. **Progressive Disclosure**: Layer information from high-level to detailed
3. **Decoupled Architecture**: Each analyzer is independent and pluggable
4. **Extensibility**: Plugin architecture for new languages and frameworks
5. **Stateless Analyzers**: Each analyzer can run independently
6. **Cacheable Results**: Analysis results are cached and reusable
7. **Incremental Analysis**: Only re-analyze changed components

## 2. Component Design

### 2.1 Documentation Analyzer (Phase 0 - PRIMARY)

**Purpose**: Analyze all markdown and documentation files BEFORE code analysis to understand project claims, architecture intentions, and setup instructions.

**Critical Flow**: Documentation → Claims Extraction → Code Validation

#### 2.1.1 Responsibilities
- Discover all documentation files (README, CONTRIBUTING, docs/, wikis)
- Extract claimed architecture patterns
- Parse setup/installation instructions
- Identify documented APIs and interfaces
- Extract coding standards and conventions
- Catalog TODOs and known issues in docs
- **PRIMARY OUTPUT**: "Claims Database" for validation against code

#### 2.1.2 Interface
```python
class DocumentationAnalyzer:
    """Analyzes project documentation and extracts verifiable claims."""

    def analyze(self, repo_path: str) -> DocumentationAnalysis:
        """
        Returns:
            DocumentationAnalysis containing:
            - discovered_docs: List[DocumentFile]
            - claimed_architecture: ArchitectureClaims
            - setup_instructions: SetupGuide
            - api_documentation: APISpec
            - coding_standards: CodingStandards
            - known_issues: List[Issue]
        """
        pass

    def extract_claims(self, doc_content: str) -> List[Claim]:
        """Extract testable claims from documentation."""
        pass

    def prioritize_documents(self, docs: List[str]) -> List[str]:
        """
        Order: README → CONTRIBUTING → ARCHITECTURE → API docs → Other
        """
        pass
```

#### 2.1.3 Documentation Discovery Rules
```python
DOCUMENTATION_PATTERNS = {
    'primary': ['README.md', 'README.rst', 'README.txt'],
    'contributing': ['CONTRIBUTING.md', 'CONTRIBUTING.rst', '.github/CONTRIBUTING.md'],
    'architecture': ['ARCHITECTURE.md', 'docs/architecture/*', 'ADR/*', 'docs/adr/*'],
    'api': ['API.md', 'docs/api/*', 'openapi.yaml', 'swagger.json'],
    'setup': ['INSTALL.md', 'SETUP.md', 'docs/setup/*'],
    'changelog': ['CHANGELOG.md', 'HISTORY.md', 'RELEASES.md'],
    'security': ['SECURITY.md', '.github/SECURITY.md'],
    'license': ['LICENSE', 'LICENSE.md', 'COPYING'],
    'code_of_conduct': ['CODE_OF_CONDUCT.md', '.github/CODE_OF_CONDUCT.md'],
    'wiki': ['docs/**/*.md', 'wiki/**/*.md'],
}
```

### 2.2 Code Analyzer

**Purpose**: Perform static analysis of codebase structure, patterns, and quality.

**Critical**: Receives "Claims Database" from DocumentationAnalyzer and validates against reality.

#### 2.2.1 Sub-Analyzers

```python
class StructureAnalyzer:
    """Analyzes repository structure and organization."""
    def analyze_directory_structure(self) -> DirectoryTree
    def identify_languages(self) -> Dict[str, float]  # language -> % of codebase
    def detect_frameworks(self) -> List[Framework]
    def find_entry_points(self) -> List[EntryPoint]
    def map_modules(self) -> ModuleGraph

class DependencyAnalyzer:
    """Analyzes project dependencies."""
    def extract_dependencies(self) -> DependencyGraph
    def identify_external_deps(self) -> List[ExternalDependency]
    def find_internal_deps(self) -> InternalDependencyGraph
    def detect_circular_deps(self) -> List[CircularDependency]
    def analyze_dependency_health(self) -> HealthReport

class PatternAnalyzer:
    """Detects design patterns and anti-patterns."""
    def detect_design_patterns(self) -> List[DesignPattern]
    def detect_anti_patterns(self) -> List[AntiPattern]
    def analyze_architecture_style(self) -> ArchitectureStyle
    def detect_layering_violations(self) -> List[Violation]

class QualityAnalyzer:
    """Analyzes code quality metrics."""
    def calculate_complexity(self) -> ComplexityMetrics
    def detect_code_smells(self) -> List[CodeSmell]
    def find_duplicates(self) -> List[Duplication]
    def analyze_test_coverage_indicators(self) -> CoverageEstimate
    def find_dead_code(self) -> List[DeadCode]

class SecurityAnalyzer:
    """Identifies security concerns."""
    def detect_vulnerabilities(self) -> List[Vulnerability]
    def find_security_patterns(self) -> List[SecurityPattern]
    def check_secrets_exposure(self) -> List[SecretExposure]
    def analyze_input_validation(self) -> ValidationReport

class ObservabilityAnalyzer:
    """Analyzes logging, monitoring, error tracking."""
    def detect_logging_patterns(self) -> LoggingAnalysis
    def find_monitoring_integration(self) -> MonitoringSetup
    def analyze_error_handling(self) -> ErrorHandlingReport
    def detect_performance_instrumentation(self) -> InstrumentationReport
```

### 2.3 Validation Engine (CRITICAL COMPONENT)

**Purpose**: Compare documentation claims against actual code implementation.

```python
class ValidationEngine:
    """Validates documentation claims against code reality."""

    def validate_architecture_claims(
        self,
        claimed: ArchitectureClaims,
        actual: CodeStructure
    ) -> List[ValidationResult]:
        """
        Compare documented architecture vs actual implementation.

        Checks:
        - Does claimed pattern match actual pattern?
        - Do documented modules exist?
        - Are documented APIs actually present?
        - Do data flows match documentation?
        """
        pass

    def validate_setup_instructions(
        self,
        instructions: SetupGuide,
        actual_config: ProjectConfig
    ) -> List[ValidationResult]:
        """
        Verify setup instructions are accurate.

        Checks:
        - Do documented dependencies match package files?
        - Are environment variables documented?
        - Do build steps match actual build configs?
        """
        pass

    def detect_documentation_drift(
        self,
        docs: DocumentationAnalysis,
        code: CodeAnalysis
    ) -> DriftReport:
        """
        Identify where docs and code have diverged.

        Examples:
        - README claims REST API but code is GraphQL
        - Docs say Python 3.8+ but setup.py requires 3.9+
        - Contributing guide references scripts that don't exist
        """
        pass

    def find_undocumented_features(
        self,
        code: CodeAnalysis,
        docs: DocumentationAnalysis
    ) -> List[UndocumentedFeature]:
        """Find significant code features not mentioned in docs."""
        pass
```

### 2.4 Prompt Generator

**Purpose**: Generate structured AI assistant prompts based on analysis results.

**Key Innovation**: Prompts follow Documentation → Code → Validation flow.

```python
class PromptGenerator:
    """Generates structured prompts for AI code review."""

    def generate_all_phases(
        self,
        repo_analysis: RepositoryAnalysis
    ) -> PromptCollection:
        """Generate complete prompt set for all phases."""
        return PromptCollection(
            phase0=self.generate_phase0_documentation(repo_analysis),
            phase1=self.generate_phase1_architecture(repo_analysis),
            phase2=self.generate_phase2_implementation(repo_analysis),
            phase3=self.generate_phase3_workflow(repo_analysis),
            phase4=self.generate_phase4_remediation(repo_analysis),
        )

    def generate_phase0_documentation(
        self,
        analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 0: Documentation Review (ALWAYS FIRST)

        Prompts guide AI to:
        1. Read README and extract key claims
        2. Review architecture documentation
        3. Understand documented setup process
        4. Catalog documented APIs/interfaces
        5. Note documented design decisions
        6. Extract documented conventions

        Output: Structured understanding of "what the project claims to be"
        """
        prompts = []

        # Prompt 0.1: README analysis
        prompts.append(Prompt(
            id="0.1",
            title="README Analysis & Claims Extraction",
            context=analysis.documentation.readme_content,
            objective="Extract and catalog all claims about project architecture, features, and setup",
            tasks=[
                "Identify stated project purpose and scope",
                "List claimed technologies and frameworks",
                "Extract documented architecture pattern",
                "Note all setup/installation claims",
                "Catalog documented features and capabilities",
                "Identify any architectural diagrams or descriptions",
            ],
            deliverable="Structured list of testable claims for validation"
        ))

        # Prompt 0.2: Setup documentation validation prep
        prompts.append(Prompt(
            id="0.2",
            title="Setup & Build Documentation Review",
            context=analysis.documentation.setup_guides,
            objective="Understand documented development workflow",
            tasks=[
                "Extract prerequisite requirements",
                "Document claimed build steps",
                "List environment variables mentioned",
                "Note deployment procedures described",
                "Identify testing instructions",
            ],
            deliverable="Development workflow checklist for validation"
        ))

        return prompts

    def generate_phase1_architecture(
        self,
        analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 1: Architecture Analysis & Validation

        Prompts guide AI to:
        1. Analyze actual code structure
        2. Compare with documented architecture
        3. Identify discrepancies
        4. Assess architectural quality
        """
        prompts = []

        # Prompt 1.1: Structure validation
        prompts.append(Prompt(
            id="1.1",
            title="Validate Documented Architecture Against Code",
            context={
                'claimed': analysis.documentation.architecture_claims,
                'actual': analysis.code.structure,
                'validation': analysis.validation.architecture_drift,
            },
            objective="Verify if actual code matches documented architecture",
            tasks=[
                "Compare claimed vs actual architectural pattern",
                "Verify documented modules/layers exist",
                "Check if data flows match documentation",
                "Identify undocumented components",
                "Flag documentation inaccuracies",
            ],
            critical_findings=analysis.validation.architecture_drift,
            deliverable="Architecture validation report with discrepancies highlighted"
        ))

        return prompts

    def generate_phase2_implementation(
        self,
        analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 2: Implementation Deep-Dive

        Focus on code quality, patterns, observability, etc.
        """
        pass

    def generate_phase3_workflow(
        self,
        analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 3: Development Workflow Validation

        Validate setup instructions, build process, testing
        """
        prompts = []

        prompts.append(Prompt(
            id="3.1",
            title="Validate Setup Instructions",
            context={
                'documented': analysis.documentation.setup_instructions,
                'actual_config': analysis.code.build_config,
                'validation': analysis.validation.setup_drift,
            },
            objective="Verify documented setup instructions are accurate and complete",
            tasks=[
                "Attempt to trace documented setup steps to actual config",
                "Identify missing prerequisites not documented",
                "Flag outdated version requirements",
                "Note environment variables used but not documented",
                "Identify undocumented build steps",
            ],
            deliverable="Setup documentation accuracy report with corrections needed"
        ))

        return prompts

    def generate_phase4_remediation(
        self,
        analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 4: Interactive Remediation Planning

        Dialog prompts for user to prioritize and plan fixes
        """
        pass
```

### 2.5 Analysis Orchestrator

```python
class AnalysisOrchestrator:
    """Coordinates multi-phase analysis workflow."""

    def __init__(self):
        self.doc_analyzer = DocumentationAnalyzer()
        self.code_analyzer = CodeAnalyzer()
        self.validation_engine = ValidationEngine()
        self.prompt_generator = PromptGenerator()

    def run_full_analysis(
        self,
        repo_path: str,
        progress_callback: Optional[Callable] = None
    ) -> RepositoryAnalysis:
        """
        Execute complete analysis pipeline.

        CRITICAL ORDER:
        1. Documentation Analysis (Phase 0)
        2. Code Analysis (Phase 1-2)
        3. Validation (Cross-check docs vs code)
        4. Prompt Generation (All phases)
        """

        # Step 1: ALWAYS analyze documentation first
        progress_callback("Phase 0: Analyzing documentation...")
        doc_analysis = self.doc_analyzer.analyze(repo_path)

        # Step 2: Analyze code structure and quality
        progress_callback("Phase 1-2: Analyzing code...")
        code_analysis = self.code_analyzer.analyze(repo_path)

        # Step 3: CRITICAL - Validate docs against code
        progress_callback("Validation: Comparing docs vs code...")
        validation_results = self.validation_engine.validate(
            docs=doc_analysis,
            code=code_analysis
        )

        # Step 4: Generate prompts incorporating validation findings
        progress_callback("Generating AI prompts...")
        prompts = self.prompt_generator.generate_all_phases(
            RepositoryAnalysis(
                documentation=doc_analysis,
                code=code_analysis,
                validation=validation_results,
            )
        )

        return RepositoryAnalysis(
            repository_path=repo_path,
            documentation=doc_analysis,
            code=code_analysis,
            validation=validation_results,
            prompts=prompts,
            timestamp=datetime.now(),
        )
```

## 3. Data Models

### 3.1 Core Models

```python
@dataclass
class DocumentFile:
    path: str
    type: str  # 'readme', 'contributing', 'architecture', etc.
    content: str
    priority: int  # 1=highest (README), 5=lowest
    last_modified: datetime

@dataclass
class Claim:
    """A testable claim from documentation."""
    source_doc: str
    claim_type: str  # 'architecture', 'setup', 'api', 'feature'
    description: str
    testable: bool
    validated: Optional[bool] = None
    validation_notes: Optional[str] = None

@dataclass
class ArchitectureClaims:
    """What the documentation says the architecture is."""
    pattern: Optional[str]  # "microservices", "monolith", "MVC", etc.
    layers: List[str]
    components: List[str]
    data_flow: Optional[str]
    documented_in: List[str]  # which files claim this

@dataclass
class DocumentationAnalysis:
    discovered_docs: List[DocumentFile]
    claimed_architecture: ArchitectureClaims
    setup_instructions: SetupGuide
    api_documentation: Optional[APISpec]
    coding_standards: Optional[CodingStandards]
    known_issues: List[Issue]
    completeness_score: float  # 0-100

@dataclass
class ValidationResult:
    claim: Claim
    validation_status: str  # 'valid', 'invalid', 'partial', 'untestable'
    severity: str  # 'critical', 'high', 'medium', 'low'
    evidence: str
    recommendation: str

@dataclass
class DriftReport:
    """Documentation vs code discrepancies."""
    architecture_drift: List[ValidationResult]
    setup_drift: List[ValidationResult]
    api_drift: List[ValidationResult]
    undocumented_features: List[str]
    outdated_documentation: List[str]
    drift_severity: str  # 'critical', 'high', 'medium', 'low'

@dataclass
class Prompt:
    id: str
    phase: int
    title: str
    context: Any  # Documentation, code snippets, validation results
    objective: str
    tasks: List[str]
    deliverable: str
    ai_model_hints: Dict[str, Any]  # Token estimates, complexity, etc.
    dependencies: List[str]  # IDs of prompts that should run first
```

## 4. Extensibility Architecture

### 4.1 Plugin System

```python
class AnalyzerPlugin(ABC):
    """Base class for all analyzer plugins."""

    @property
    @abstractmethod
    def name(self) -> str:
        pass

    @property
    @abstractmethod
    def supported_languages(self) -> List[str]:
        pass

    @abstractmethod
    def analyze(self, context: AnalysisContext) -> AnalysisResult:
        pass

class PluginRegistry:
    """Manages analyzer plugins."""

    def register(self, plugin: AnalyzerPlugin):
        """Register a new analyzer plugin."""
        pass

    def get_plugins_for_language(self, language: str) -> List[AnalyzerPlugin]:
        """Get all plugins supporting a language."""
        pass
```

### 4.2 Template System

```python
class PromptTemplate:
    """Jinja2-based prompt templates."""

    def __init__(self, template_dir: str):
        self.env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(template_dir)
        )

    def render(self, template_name: str, context: Dict) -> str:
        template = self.env.get_template(template_name)
        return template.render(**context)

# Example template structure:
# templates/
#   phase0/
#     readme_analysis.j2
#     architecture_docs.j2
#   phase1/
#     architecture_validation.j2
#     structure_analysis.j2
#   phase2/
#     ...
```

## 5. Web Interface Design

### 5.1 Technology Stack
- **Backend**: Flask 3.x
- **Frontend**: HTML5, Tailwind CSS, Alpine.js (lightweight reactivity)
- **Charts**: Chart.js
- **Diagrams**: Mermaid.js (for architecture visualization)

### 5.2 API Endpoints

```python
# Repository Management
POST   /api/repositories              # Add repository
GET    /api/repositories              # List repositories
GET    /api/repositories/<id>         # Get repository details
DELETE /api/repositories/<id>         # Remove repository
PUT    /api/repositories/<id>/update  # Update/re-clone repository

# Analysis
POST   /api/repositories/<id>/analyze # Start analysis
GET    /api/repositories/<id>/analysis # Get analysis results
GET    /api/repositories/<id>/analysis/status # Get analysis progress
DELETE /api/repositories/<id>/analysis # Cancel analysis

# Prompts
GET    /api/repositories/<id>/prompts # Get all prompts
GET    /api/repositories/<id>/prompts/<phase> # Get phase prompts
POST   /api/prompts/export            # Export prompts (format: json/md/txt)

# Reports
GET    /api/repositories/<id>/report  # Get comprehensive report
GET    /api/repositories/<id>/report/export # Export report (format: html/pdf/md)

# Validation
GET    /api/repositories/<id>/validation # Get validation results
GET    /api/repositories/<id>/drift      # Get drift report
```

### 5.3 Page Structure

```
/                          # Dashboard (repository list)
/repository/<id>           # Repository overview
/repository/<id>/analysis  # Analysis results dashboard
/repository/<id>/prompts   # Prompts viewer (by phase)
/repository/<id>/validation # Documentation validation results
/repository/<id>/report    # Comprehensive report view
/settings                  # Application settings
```

## 6. Implementation Phases

### Phase 1: Core Foundation (MVP)
- [ ] Documentation analyzer (basic)
- [ ] Structure analyzer
- [ ] Basic validation engine
- [ ] Prompt generator (Phase 0 & 1 only)
- [ ] CLI interface
- [ ] JSON output

### Phase 2: Web Interface
- [ ] Flask application
- [ ] Repository management UI
- [ ] Analysis dashboard
- [ ] Prompt viewer
- [ ] Basic visualizations

### Phase 3: Advanced Analysis
- [ ] Full code quality analysis
- [ ] Security analyzer
- [ ] Observability analyzer
- [ ] Advanced validation
- [ ] Complete prompt phases

### Phase 4: Polish & Extension
- [ ] Plugin system
- [ ] Custom templates
- [ ] Export formats
- [ ] Performance optimization

## 7. Testing Strategy

### 7.1 Test Repository Set
Use diverse real-world repositories:
- Small script collection (this repo)
- Medium Flask application
- Large microservices project
- Monorepo example

### 7.2 Test Coverage
- Unit tests: 80%+ coverage
- Integration tests for analyzer pipeline
- End-to-end tests for web interface
- Validation logic must be 100% tested

## 8. Performance Considerations

### 8.1 Optimization Strategies
- Parallel analyzer execution (ThreadPoolExecutor)
- Incremental analysis (only changed files)
- Result caching (pickle/JSON)
- Lazy loading for large repositories
- Stream processing for large files

### 8.2 Resource Limits
- Max file size for analysis: 10MB
- Max repository size: 1GB (warning at 500MB)
- Analysis timeout: 30 minutes
- Concurrent analyses: 3 (configurable)

## 9. Security Considerations

- No code execution (static analysis only)
- Path traversal prevention
- Secure credential storage (keyring library)
- Rate limiting on API endpoints
- Input sanitization
- CSRF protection
- XSS prevention (template escaping)

## 10. Configuration

```yaml
# config.yaml
analysis:
  max_file_size_mb: 10
  max_repo_size_gb: 1
  timeout_minutes: 30
  parallel_workers: 4

  # Documentation-first settings
  documentation_priority: true
  validate_claims: true
  strict_validation: false  # If true, fail on major drift

storage:
  cache_dir: ~/.codebase-reviewer/cache
  results_dir: ~/.codebase-reviewer/results
  db_path: ~/.codebase-reviewer/repositories.db

web:
  host: 127.0.0.1
  port: 5000
  debug: false

prompts:
  template_dir: ./templates/prompts
  default_model: claude-sonnet-4
  include_token_estimates: true
```

## 11. Future Enhancements

### 11.1 AI Model Integration
- Direct API calls to Claude/GPT/Gemini
- Automatic prompt execution
- Result aggregation
- Interactive sessions

### 11.2 Advanced Features
- Git history analysis (code evolution)
- Team contribution patterns
- Automated remediation PRs
- CI/CD integration (GitHub Actions)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Status**: Ready for Implementation
