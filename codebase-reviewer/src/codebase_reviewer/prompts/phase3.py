"""Phase 3: Development Workflow prompt generation."""

from typing import List

from codebase_reviewer.models import Prompt, RepositoryAnalysis


class Phase3Generator:
    """Generates Phase 3 prompts for development workflow validation."""

    def generate(self, analysis: RepositoryAnalysis) -> List[Prompt]:
        """Generate Phase 3 development workflow prompts."""
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
