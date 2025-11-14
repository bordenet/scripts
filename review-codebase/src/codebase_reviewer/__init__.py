"""Codebase Reviewer - AI-powered codebase analysis and onboarding tool."""

__version__ = "1.0.0"
__author__ = "Engineering Excellence Team"

from codebase_reviewer.models import (
    DocumentFile,
    Claim,
    ArchitectureClaims,
    DocumentationAnalysis,
    ValidationResult,
    DriftReport,
    Prompt,
    RepositoryAnalysis,
)

__all__ = [
    "DocumentFile",
    "Claim",
    "ArchitectureClaims",
    "DocumentationAnalysis",
    "ValidationResult",
    "DriftReport",
    "Prompt",
    "RepositoryAnalysis",
]
