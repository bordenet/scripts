"""Prompt export functionality."""

import json
from typing import List

from codebase_reviewer.models import Prompt, PromptCollection


class PromptExporter:
    """Exports prompts to various formats."""

    def to_markdown(self, prompts: PromptCollection) -> str:
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

    def to_json(self, prompts: PromptCollection) -> str:
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
