"""Phase 4: Interactive Remediation prompt generation."""

from typing import Any, Dict, List

from codebase_reviewer.models import Prompt, RepositoryAnalysis


class Phase4Generator:
    """Generates Phase 4 prompts for interactive remediation."""

    def generate(self, analysis: RepositoryAnalysis) -> List[Prompt]:
        """Generate Phase 4 interactive remediation prompts."""
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
                        "critical": len(
                            [i for i in all_issues if i.get("severity") == "critical"]
                        ),
                        "high": len(
                            [i for i in all_issues if i.get("severity") == "high"]
                        ),
                        "medium": len(
                            [i for i in all_issues if i.get("severity") == "medium"]
                        ),
                        "low": len(
                            [i for i in all_issues if i.get("severity") == "low"]
                        ),
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
