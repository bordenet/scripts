"""Analysis orchestrator - coordinates multi-phase analysis workflow."""

import time
from datetime import datetime
from typing import Callable, Optional

from codebase_reviewer.analyzers import (
    CodeAnalyzer,
    DocumentationAnalyzer,
    ValidationEngine,
)
from codebase_reviewer.models import RepositoryAnalysis
from codebase_reviewer.prompt_generator import PromptGenerator


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
        progress_callback: Optional[Callable[[str], None]] = None,
    ) -> RepositoryAnalysis:
        """
        Execute complete analysis pipeline.

        CRITICAL ORDER:
        1. Documentation Analysis (Phase 0)
        2. Code Analysis (Phase 1-2)
        3. Validation (Cross-check docs vs code)
        4. Prompt Generation (All phases)

        Args:
            repo_path: Path to repository root
            progress_callback: Optional callback for progress updates

        Returns:
            Complete RepositoryAnalysis
        """
        start_time = time.time()

        def report_progress(message: str):
            if progress_callback:
                progress_callback(message)
            else:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] {message}")

        # Step 1: ALWAYS analyze documentation first
        report_progress("Phase 0: Analyzing documentation...")
        doc_analysis = self.doc_analyzer.analyze(repo_path)
        report_progress(
            f"  Found {len(doc_analysis.discovered_docs)} documentation files"
        )
        report_progress(
            f"  Extracted {len(doc_analysis.claims)} testable claims"
        )

        # Step 2: Analyze code structure and quality
        report_progress("Phase 1-2: Analyzing code structure...")
        code_analysis = self.code_analyzer.analyze(repo_path)
        if code_analysis.structure:
            report_progress(
                f"  Detected {len(code_analysis.structure.languages)} languages"
            )
            report_progress(
                f"  Detected {len(code_analysis.structure.frameworks)} frameworks"
            )
        report_progress(
            f"  Found {len(code_analysis.quality_issues)} quality issues"
        )

        # Step 3: CRITICAL - Validate docs against code
        report_progress("Validation: Comparing documentation vs code...")
        validation_results = self.validation_engine.validate(
            docs=doc_analysis, code=code_analysis
        )
        drift_count = (
            len(validation_results.architecture_drift)
            + len(validation_results.setup_drift)
            + len(validation_results.api_drift)
        )
        report_progress(
            f"  Found {drift_count} documentation drift issues"
        )
        report_progress(
            f"  Drift severity: {validation_results.drift_severity.value}"
        )

        # Step 4: Generate prompts incorporating validation findings
        report_progress("Generating AI prompts...")
        repo_analysis = RepositoryAnalysis(
            repository_path=repo_path,
            documentation=doc_analysis,
            code=code_analysis,
            validation=validation_results,
            prompts=None,
            timestamp=datetime.now(),
        )

        prompts = self.prompt_generator.generate_all_phases(repo_analysis)
        total_prompts = len(prompts.all_prompts())
        report_progress(f"  Generated {total_prompts} AI prompts across 5 phases")

        # Calculate duration
        duration = time.time() - start_time

        # Update analysis with prompts and duration
        repo_analysis.prompts = prompts
        repo_analysis.analysis_duration_seconds = duration

        report_progress(f"Analysis complete in {duration:.2f} seconds")

        return repo_analysis
