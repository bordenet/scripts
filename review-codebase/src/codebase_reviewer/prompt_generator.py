"""Base prompt generator functionality."""

import json
from typing import List

from codebase_reviewer.models import (
    Prompt,
    PromptCollection,
    RepositoryAnalysis,
)
from codebase_reviewer.prompts.phase0 import Phase0Generator
from codebase_reviewer.prompts.phase1 import Phase1Generator
from codebase_reviewer.prompts.phase2 import Phase2Generator
from codebase_reviewer.prompts.phase3 import Phase3Generator
from codebase_reviewer.prompts.phase4 import Phase4Generator
from codebase_reviewer.prompts.export import PromptExporter


class PromptGenerator:
    """Generates structured prompts for AI code review and onboarding."""

    def __init__(self):
        self.phase0 = Phase0Generator()
        self.phase1 = Phase1Generator()
        self.phase2 = Phase2Generator()
        self.phase3 = Phase3Generator()
        self.phase4 = Phase4Generator()
        self.exporter = PromptExporter()

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
            phase0=self.phase0.generate(repo_analysis),
            phase1=self.phase1.generate(repo_analysis),
            phase2=self.phase2.generate(repo_analysis),
            phase3=self.phase3.generate(repo_analysis),
            phase4=self.phase4.generate(repo_analysis),
        )

    def export_prompts_markdown(self, prompts: PromptCollection) -> str:
        """Export prompts to markdown format."""
        return self.exporter.to_markdown(prompts)

    def export_prompts_json(self, prompts: PromptCollection) -> str:
        """Export prompts to JSON format."""
        return self.exporter.to_json(prompts)
