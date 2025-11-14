"""Prompt generator - generates AI prompts for code review and onboarding."""

import json
from typing import Any, Dict, List

from codebase_reviewer.models import (
    Prompt,
    PromptCollection,
    RepositoryAnalysis,
    Severity,
)


class PromptGenerator:
    """Generates structured prompts for AI code review and onboarding."""

    def generate_all_phases(
        self, repo_analysis: RepositoryAnalysis
    ) -> PromptCollection:
        """
        Generate complete prompt set for all phases.

        Args:
            repo_analysis: Complete repository analysis

        Returns:
            PromptCollection with prompts for all phases
        """
        return PromptCollection(
            phase0=self.generate_phase0_documentation(repo_analysis),
            phase1=self.generate_phase1_architecture(repo_analysis),
            phase2=self.generate_phase2_implementation(repo_analysis),
            phase3=self.generate_phase3_workflow(repo_analysis),
            phase4=self.generate_phase4_remediation(repo_analysis),
        )

    def generate_phase0_documentation(
        self, analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 0: Documentation Review (ALWAYS FIRST)

        Prompts guide AI to analyze documentation and extract claims.
        """
        prompts: List[Prompt] = []

        if not analysis.documentation:
            return prompts

        docs = analysis.documentation

        # Find README
        readme_docs = [d for d in docs.discovered_docs if d.doc_type == "primary"]
        readme_content = readme_docs[0].content if readme_docs else "No README found"

        # Prompt 0.1: README Analysis
        prompts.append(
            Prompt(
                prompt_id="0.1",
                phase=0,
                title="README Analysis & Claims Extraction",
                context={
                    "readme_content": readme_content[:5000],  # Limit size
                    "readme_path": readme_docs[0].path if readme_docs else "N/A",
                    "total_docs_found": len(docs.discovered_docs),
                },
                objective="Extract and catalog all claims about project architecture, features, and setup from the README",
                tasks=[
                    "Identify the stated project purpose and scope",
                    "List all claimed technologies and frameworks",
                    "Extract documented architecture pattern (if any)",
                    "Note all setup/installation claims",
                    "Catalog documented features and capabilities",
                    "Identify any architectural diagrams or descriptions",
                    "Note what version of languages/frameworks are claimed",
                ],
                deliverable="Structured list of testable claims with source locations for validation against code",
                ai_model_hints={
                    "estimated_tokens": len(readme_content) // 4,
                    "complexity": "medium",
                    "requires_code_analysis": False,
                },
                dependencies=[],
            )
        )

        # Prompt 0.2: Architecture Documentation Review
        arch_docs = [d for d in docs.discovered_docs if d.doc_type == "architecture"]
        if arch_docs:
            arch_content = "\n\n---\n\n".join(
                f"## {d.path}\n{d.content[:3000]}" for d in arch_docs[:3]
            )

            prompts.append(
                Prompt(
                    prompt_id="0.2",
                    phase=0,
                    title="Architecture Documentation Analysis",
                    context={
                        "architecture_docs": arch_content,
                        "doc_count": len(arch_docs),
                        "claimed_pattern": (
                            docs.claimed_architecture.pattern
                            if docs.claimed_architecture
                            else None
                        ),
                    },
                    objective="Understand the documented system architecture and design decisions",
                    tasks=[
                        "Identify the architectural style (monolith, microservices, etc.)",
                        "List all documented components and their responsibilities",
                        "Extract documented data flows and communication patterns",
                        "Note documented technology choices and rationale",
                        "Identify documented architectural constraints",
                        "Extract any documented architectural decision records (ADRs)",
                    ],
                    deliverable="Comprehensive architectural understanding for validation against actual code",
                    ai_model_hints={
                        "estimated_tokens": len(arch_content) // 4,
                        "complexity": "high",
                        "requires_domain_knowledge": True,
                    },
                    dependencies=["0.1"],
                )
            )

        # Prompt 0.3: Setup Documentation Review
        if docs.setup_instructions:
            setup = docs.setup_instructions

            prompts.append(
                Prompt(
                    prompt_id="0.3",
                    phase=0,
                    title="Setup & Build Documentation Review",
                    context={
                        "prerequisites": setup.prerequisites,
                        "build_steps": setup.build_steps,
                        "environment_vars": setup.environment_vars,
                        "documented_in": setup.documented_in,
                    },
                    objective="Understand the documented development workflow and prerequisites",
                    tasks=[
                        "List all documented prerequisite requirements (tools, versions, etc.)",
                        "Document the claimed build process step-by-step",
                        "Identify all mentioned environment variables and their purposes",
                        "Note deployment procedures if described",
                        "Identify testing instructions",
                        "Flag any missing or unclear setup steps",
                    ],
                    deliverable="Development workflow checklist for validation against actual config files",
                    ai_model_hints={
                        "estimated_tokens": 1500,
                        "complexity": "medium",
                        "requires_code_analysis": False,
                    },
                    dependencies=["0.1"],
                )
            )

        return prompts

    def generate_phase1_architecture(
        self, analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 1: Architecture Analysis & Validation

        Prompts guide AI to analyze code and validate against documentation.
        """
        prompts: List[Prompt] = []

        if not analysis.code or not analysis.documentation:
            return prompts

        code = analysis.code
        docs = analysis.documentation
        validation = analysis.validation

        # Prompt 1.1: Architecture Validation
        prompts.append(
            Prompt(
                prompt_id="1.1",
                phase=1,
                title="Validate Documented Architecture Against Actual Code",
                context={
                    "claimed_architecture": (
                        {
                            "pattern": docs.claimed_architecture.pattern,
                            "layers": docs.claimed_architecture.layers,
                            "components": docs.claimed_architecture.components,
                        }
                        if docs.claimed_architecture
                        else None
                    ),
                    "actual_structure": {
                        "languages": [
                            {"name": l.name, "percentage": l.percentage}
                            for l in (code.structure.languages if code.structure else [])
                        ],
                        "frameworks": [
                            f.name for f in (code.structure.frameworks if code.structure else [])
                        ],
                        "entry_points": [
                            ep.path for ep in (code.structure.entry_points if code.structure else [])
                        ],
                    },
                    "validation_results": (
                        [
                            {
                                "status": r.validation_status.value,
                                "evidence": r.evidence,
                                "recommendation": r.recommendation,
                            }
                            for r in validation.architecture_drift
                        ]
                        if validation
                        else []
                    ),
                },
                objective="Verify if actual code structure matches documented architecture claims",
                tasks=[
                    "Compare claimed architectural pattern vs actual implementation",
                    "Verify documented modules/layers exist in code",
                    "Check if technology stack matches documentation",
                    "Identify undocumented components or services",
                    "Flag any significant documentation inaccuracies",
                    "Assess overall architecture quality and appropriateness",
                ],
                deliverable="Architecture validation report with discrepancies highlighted and recommendations",
                ai_model_hints={
                    "estimated_tokens": 2000,
                    "complexity": "high",
                    "requires_code_analysis": True,
                },
                dependencies=["0.1", "0.2"],
                critical_findings=(
                    validation.architecture_drift if validation else None
                ),
            )
        )

        # Prompt 1.2: Dependency Analysis
        if code.dependencies:
            prompts.append(
                Prompt(
                    prompt_id="1.2",
                    phase=1,
                    title="Dependency Analysis and Health Check",
                    context={
                        "dependencies": [
                            {
                                "name": d.name,
                                "version": d.version,
                                "type": d.dependency_type,
                                "source": d.source_file,
                            }
                            for d in code.dependencies[:50]
                        ],
                        "total_count": len(code.dependencies),
                        "documented_prerequisites": (
                            docs.setup_instructions.prerequisites
                            if docs.setup_instructions
                            else []
                        ),
                    },
                    objective="Analyze project dependencies for health, security, and documentation accuracy",
                    tasks=[
                        "Review all external dependencies and their purposes",
                        "Identify any outdated or deprecated dependencies",
                        "Check for potential security concerns",
                        "Verify dependencies match documented prerequisites",
                        "Identify missing dependency documentation",
                        "Assess dependency management practices",
                    ],
                    deliverable="Dependency health report with recommendations for updates or documentation",
                    ai_model_hints={
                        "estimated_tokens": 1500,
                        "complexity": "medium",
                    },
                    dependencies=["0.3"],
                )
            )

        return prompts

    def generate_phase2_implementation(
        self, analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 2: Implementation Deep-Dive

        Prompts for code quality, patterns, and detailed analysis.
        """
        prompts: List[Prompt] = []

        if not analysis.code:
            return prompts

        code = analysis.code

        # Prompt 2.1: Code Quality Assessment
        quality_issues = code.quality_issues

        # Categorize issues
        todos = [i for i in quality_issues if "TODO" in i.title or "FIXME" in i.title]
        security_issues = [i for i in quality_issues if i.severity == Severity.HIGH]

        prompts.append(
            Prompt(
                prompt_id="2.1",
                phase=2,
                title="Code Quality and Technical Debt Assessment",
                context={
                    "todo_count": len(todos),
                    "sample_todos": [
                        {"title": t.title, "description": t.description}
                        for t in todos[:10]
                    ],
                    "security_issues_count": len(security_issues),
                    "sample_security_issues": [
                        {"title": s.title, "description": s.description}
                        for s in security_issues[:5]
                    ],
                },
                objective="Assess code quality, identify technical debt, and security concerns",
                tasks=[
                    "Review TODO/FIXME comments for patterns and urgency",
                    "Assess potential security issues (hardcoded secrets, etc.)",
                    "Identify areas with high technical debt",
                    "Evaluate error handling patterns",
                    "Assess code organization and modularity",
                    "Identify anti-patterns or code smells",
                ],
                deliverable="Code quality report with prioritized remediation recommendations",
                ai_model_hints={
                    "estimated_tokens": 2000,
                    "complexity": "high",
                    "requires_security_knowledge": True,
                },
                dependencies=["1.1"],
                critical_findings=security_issues if security_issues else None,
            )
        )

        # Prompt 2.2: Observability Assessment
        prompts.append(
            Prompt(
                prompt_id="2.2",
                phase=2,
                title="Observability and Operational Maturity",
                context={
                    "repository_path": analysis.repository_path,
                    "frameworks": (
                        [f.name for f in code.structure.frameworks]
                        if code.structure
                        else []
                    ),
                },
                objective="Assess logging, monitoring, and operational maturity of the codebase",
                tasks=[
                    "Evaluate logging practices (coverage, consistency, level usage)",
                    "Identify monitoring and metrics instrumentation",
                    "Check for error tracking integration (Sentry, etc.)",
                    "Assess configuration management approach",
                    "Identify deployment and infrastructure code",
                    "Evaluate operational readiness (health checks, etc.)",
                ],
                deliverable="Observability assessment with gaps and recommendations",
                ai_model_hints={
                    "estimated_tokens": 1500,
                    "complexity": "medium",
                    "requires_devops_knowledge": True,
                },
                dependencies=["1.1"],
            )
        )

        return prompts

    def generate_phase3_workflow(
        self, analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 3: Development Workflow Validation

        Prompts for setup, build, and testing validation.
        """
        prompts: List[Prompt] = []

        if not analysis.documentation or not analysis.validation:
            return prompts

        docs = analysis.documentation
        validation = analysis.validation

        # Prompt 3.1: Setup Validation
        prompts.append(
            Prompt(
                prompt_id="3.1",
                phase=3,
                title="Validate Setup and Build Instructions",
                context={
                    "documented_setup": (
                        {
                            "prerequisites": docs.setup_instructions.prerequisites,
                            "build_steps": docs.setup_instructions.build_steps,
                            "env_vars": docs.setup_instructions.environment_vars,
                        }
                        if docs.setup_instructions
                        else None
                    ),
                    "validation_results": (
                        [
                            {
                                "status": r.validation_status.value,
                                "evidence": r.evidence,
                                "recommendation": r.recommendation,
                            }
                            for r in validation.setup_drift
                        ]
                        if validation.setup_drift
                        else []
                    ),
                    "undocumented_features": validation.undocumented_features,
                },
                objective="Verify documented setup instructions are accurate and complete",
                tasks=[
                    "Trace documented setup steps to actual configuration files",
                    "Identify missing prerequisites not documented",
                    "Flag outdated version requirements",
                    "Note environment variables used but not documented",
                    "Identify undocumented build steps or scripts",
                    "Assess overall setup documentation quality",
                ],
                deliverable="Setup documentation accuracy report with specific corrections needed",
                ai_model_hints={
                    "estimated_tokens": 1800,
                    "complexity": "medium",
                },
                dependencies=["0.3", "1.2"],
            )
        )

        # Prompt 3.2: Testing Strategy Review
        prompts.append(
            Prompt(
                prompt_id="3.2",
                phase=3,
                title="Testing Strategy and Coverage Review",
                context={"repository_path": analysis.repository_path},
                objective="Assess testing practices, coverage, and quality",
                tasks=[
                    "Identify test types present (unit, integration, e2e)",
                    "Evaluate test organization and naming conventions",
                    "Assess test coverage (estimate based on test file count)",
                    "Identify testing framework and tools used",
                    "Evaluate test quality and maintainability",
                    "Identify gaps in test coverage",
                ],
                deliverable="Testing assessment with recommendations for improvement",
                ai_model_hints={
                    "estimated_tokens": 1500,
                    "complexity": "medium",
                    "requires_testing_expertise": True,
                },
                dependencies=["1.1"],
            )
        )

        return prompts

    def generate_phase4_remediation(
        self, analysis: RepositoryAnalysis
    ) -> List[Prompt]:
        """
        PHASE 4: Interactive Remediation Planning

        Prompts for user dialog to plan fixes.
        """
        prompts: List[Prompt] = []

        # Collect all issues
        all_issues: List[Dict[str, Any]] = []

        if analysis.validation:
            for drift in (
                analysis.validation.architecture_drift
                + analysis.validation.setup_drift
                + analysis.validation.api_drift
            ):
                all_issues.append(
                    {
                        "category": "Documentation Drift",
                        "severity": drift.severity.value,
                        "description": drift.evidence,
                        "recommendation": drift.recommendation,
                    }
                )

        if analysis.code and analysis.code.quality_issues:
            for issue in analysis.code.quality_issues[:20]:
                all_issues.append(
                    {
                        "category": "Code Quality",
                        "severity": issue.severity.value,
                        "description": issue.title,
                        "source": issue.source,
                    }
                )

        # Prompt 4.1: Prioritization Dialog
        prompts.append(
            Prompt(
                prompt_id="4.1",
                phase=4,
                title="Interactive Issue Prioritization",
                context={
                    "total_issues": len(all_issues),
                    "issues_by_severity": {
                        "critical": len([i for i in all_issues if i.get("severity") == "critical"]),
                        "high": len([i for i in all_issues if i.get("severity") == "high"]),
                        "medium": len([i for i in all_issues if i.get("severity") == "medium"]),
                        "low": len([i for i in all_issues if i.get("severity") == "low"]),
                    },
                    "top_issues": all_issues[:15],
                },
                objective="Work with user to prioritize identified issues for remediation",
                tasks=[
                    "Present all issues organized by severity and category",
                    "Ask user about their priorities (security, documentation, quality, etc.)",
                    "Discuss effort estimates for top issues",
                    "Help identify quick wins vs. major refactoring needs",
                    "Create prioritized action plan based on user input",
                    "Suggest grouping related issues into themes",
                ],
                deliverable="Prioritized, actionable remediation plan ready for execution",
                ai_model_hints={
                    "estimated_tokens": 2500,
                    "complexity": "medium",
                    "requires_user_interaction": True,
                },
                dependencies=["1.1", "2.1", "3.1"],
            )
        )

        return prompts

    def export_prompts_markdown(self, prompts: PromptCollection) -> str:
        """Export prompts to markdown format."""
        lines = ["# AI Code Review Prompts\n"]

        for phase_num in range(5):
            phase_prompts = getattr(prompts, f"phase{phase_num}")
            if not phase_prompts:
                continue

            phase_names = {
                0: "Documentation Review",
                1: "Architecture Analysis",
                2: "Implementation Deep-Dive",
                3: "Development Workflow",
                4: "Interactive Remediation",
            }

            lines.append(f"\n## Phase {phase_num}: {phase_names[phase_num]}\n")

            for prompt in phase_prompts:
                lines.append(f"\n### Prompt {prompt.prompt_id}: {prompt.title}\n")
                lines.append(f"\n**Objective:** {prompt.objective}\n")

                lines.append("\n**Tasks:**\n")
                for task in prompt.tasks:
                    lines.append(f"- {task}\n")

                lines.append(f"\n**Deliverable:** {prompt.deliverable}\n")

                if prompt.dependencies:
                    lines.append(
                        f"\n**Dependencies:** {', '.join(prompt.dependencies)}\n"
                    )

                lines.append("\n**Context:**\n```json\n")
                lines.append(json.dumps(prompt.context, indent=2))
                lines.append("\n```\n")

                lines.append("\n---\n")

        return "".join(lines)

    def export_prompts_json(self, prompts: PromptCollection) -> str:
        """Export prompts to JSON format."""
        data = {
            f"phase{i}": [
                {
                    "id": p.prompt_id,
                    "title": p.title,
                    "objective": p.objective,
                    "tasks": p.tasks,
                    "deliverable": p.deliverable,
                    "context": p.context,
                    "dependencies": p.dependencies,
                }
                for p in getattr(prompts, f"phase{i}")
            ]
            for i in range(5)
        }

        return json.dumps(data, indent=2)
