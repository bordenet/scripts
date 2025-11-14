"""Phase 0: Documentation Review prompt generation."""

from typing import List

from codebase_reviewer.models import Prompt, RepositoryAnalysis


class Phase0Generator:
    """Generates Phase 0 prompts for documentation review."""

    def generate(self, analysis: RepositoryAnalysis) -> List[Prompt]:
        """Generate Phase 0 documentation review prompts."""
        prompts: List[Prompt] = []

        if not analysis.documentation:
            return prompts

        docs = analysis.documentation

        # Prompt 0.1: README Analysis
        readme_docs = [d for d in docs.discovered_docs if d.doc_type == "primary"]
        readme_content = readme_docs[0].content if readme_docs else "No README found"

        prompts.append(
            Prompt(
                prompt_id="0.1",
                phase=0,
                title="README Analysis & Claims Extraction",
                context={
                    "readme_content": readme_content[:5000],
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
