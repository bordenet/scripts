"""Phase 1: Architecture Analysis prompt generation."""

from typing import List

from codebase_reviewer.models import Prompt, RepositoryAnalysis


class Phase1Generator:
    """Generates Phase 1 prompts for architecture analysis."""

    def generate(self, analysis: RepositoryAnalysis) -> List[Prompt]:
        """Generate Phase 1 architecture analysis prompts."""
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
