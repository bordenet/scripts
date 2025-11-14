"""Phase 2: Implementation Deep-Dive prompt generation."""

from typing import List

from codebase_reviewer.models import Prompt, RepositoryAnalysis, Severity


class Phase2Generator:
    """Generates Phase 2 prompts for implementation analysis."""

    def generate(self, analysis: RepositoryAnalysis) -> List[Prompt]:
        """Generate Phase 2 implementation deep-dive prompts."""
        prompts: List[Prompt] = []

        if not analysis.code:
            return prompts

        code = analysis.code
        quality_issues = code.quality_issues

        # Categorize issues
        todos = [i for i in quality_issues if "TODO" in i.title or "FIXME" in i.title]
        security_issues = [i for i in quality_issues if i.severity == Severity.HIGH]

        # Prompt 2.1: Code Quality Assessment
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
