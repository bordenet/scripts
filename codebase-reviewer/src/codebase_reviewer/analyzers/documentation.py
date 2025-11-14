"""Documentation analyzer - analyzes markdown and documentation files."""

import os
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from codebase_reviewer.analyzers.constants import DOCUMENTATION_PATTERNS
from codebase_reviewer.analyzers.parsing_utils import (
    extract_section,
    extract_list_items,
    extract_code_blocks,
    detect_architecture_pattern,
)
from codebase_reviewer.models import (
    APISpec,
    ArchitectureClaims,
    Claim,
    ClaimType,
    CodingStandards,
    DocumentationAnalysis,
    DocumentFile,
    Issue,
    Severity,
    SetupGuide,
)


class DocumentationAnalyzer:
    """Analyzes project documentation and extracts verifiable claims."""

    def __init__(self):
        self.claims: List[Claim] = []

    def analyze(self, repo_path: str) -> DocumentationAnalysis:
        """
        Analyze all documentation in repository.

        Args:
            repo_path: Path to repository root

        Returns:
            DocumentationAnalysis with extracted information
        """
        discovered_docs = self._discover_documentation(repo_path)

        # Prioritize and analyze documents
        readme_docs = [d for d in discovered_docs if d.doc_type == "primary"]
        architecture_docs = [
            d for d in discovered_docs if d.doc_type == "architecture"
        ]
        setup_docs = [d for d in discovered_docs if d.doc_type in ["setup", "primary"]]

        # Extract architecture claims
        claimed_architecture = self._extract_architecture_claims(
            readme_docs + architecture_docs
        )

        # Extract setup instructions
        setup_instructions = self._extract_setup_guide(setup_docs)

        # Extract API documentation
        api_docs = [d for d in discovered_docs if d.doc_type == "api"]
        api_documentation = self._extract_api_spec(api_docs + readme_docs)

        # Extract coding standards
        contributing_docs = [
            d for d in discovered_docs if d.doc_type == "contributing"
        ]
        coding_standards = self._extract_coding_standards(contributing_docs)

        # Extract known issues
        known_issues = self._extract_known_issues(discovered_docs)

        # Calculate completeness score
        completeness_score = self._calculate_completeness(discovered_docs)

        return DocumentationAnalysis(
            discovered_docs=discovered_docs,
            claimed_architecture=claimed_architecture,
            setup_instructions=setup_instructions,
            api_documentation=api_documentation,
            coding_standards=coding_standards,
            known_issues=known_issues,
            claims=self.claims,
            completeness_score=completeness_score,
        )

    def _discover_documentation(self, repo_path: str) -> List[DocumentFile]:
        """Discover all documentation files in repository."""
        discovered = []
        repo_root = Path(repo_path)

        for doc_type, patterns in DOCUMENTATION_PATTERNS.items():
            for pattern in patterns:
                # Handle both exact matches and glob patterns
                if "**" in pattern or "*" in pattern:
                    # Glob pattern
                    for file_path in repo_root.glob(pattern):
                        if file_path.is_file():
                            discovered.append(
                                self._create_document_file(
                                    file_path, doc_type, repo_path
                                )
                            )
                else:
                    # Exact path
                    file_path = repo_root / pattern
                    if file_path.is_file():
                        discovered.append(
                            self._create_document_file(file_path, doc_type, repo_path)
                        )

        return self._prioritize_documents(discovered)

    def _create_document_file(
        self, file_path: Path, doc_type: str, repo_root: str
    ) -> DocumentFile:
        """Create DocumentFile object from path."""
        try:
            with open(file_path, "r", encoding="utf-8") as file:
                content = file.read()
        except (UnicodeDecodeError, PermissionError):
            content = ""

        stat = file_path.stat()

        return DocumentFile(
            path=str(file_path.relative_to(repo_root)),
            doc_type=doc_type,
            content=content,
            priority=self._get_priority(doc_type),
            last_modified=datetime.fromtimestamp(stat.st_mtime),
            size_bytes=stat.st_size,
        )

    def _get_priority(self, doc_type: str) -> int:
        """Get priority for document type (1=highest)."""
        priority_map = {
            "primary": 1,
            "architecture": 2,
            "contributing": 2,
            "setup": 2,
            "api": 3,
            "changelog": 4,
            "security": 3,
            "license": 5,
            "code_of_conduct": 5,
        }
        return priority_map.get(doc_type, 5)

    def _prioritize_documents(self, docs: List[DocumentFile]) -> List[DocumentFile]:
        """Sort documents by priority."""
        return sorted(docs, key=lambda d: (d.priority, d.path))

    def _extract_architecture_claims(
        self, docs: List[DocumentFile]
    ) -> ArchitectureClaims:
        """Extract architecture claims from documentation."""
        pattern = None
        layers: List[str] = []
        components: List[str] = []
        data_flow = None
        documented_in: List[str] = []

        for doc in docs:
            content_lower = doc.content.lower()

            # Detect architecture patterns
            if not pattern:
                pattern = detect_architecture_pattern(doc.content)
                if pattern:
                    documented_in.append(doc.path)
                    self.claims.append(
                        Claim(
                            source_doc=doc.path,
                            claim_type=ClaimType.ARCHITECTURE,
                            description=f"Architecture pattern: {pattern}",
                            testable=True,
                            severity=Severity.HIGH,
                        )
                    )

            # Extract layers
            layer_keywords = [
                "layer",
                "tier",
                "presentation layer",
                "business layer",
                "data layer",
                "controller",
                "service",
                "repository",
            ]
            for keyword in layer_keywords:
                if keyword in content_lower and keyword not in layers:
                    layers.append(keyword)

            # Extract components (sections that mention components)
            component_patterns = [
                r"(?:^|\n)#+\s*([A-Z][^\n]+?)\s+(?:Component|Module|Service)",
                r"(?:^|\n)[-*]\s+\*\*([A-Za-z]+?)\*\*\s*:",
            ]
            for pattern_regex in component_patterns:
                matches = re.finditer(pattern_regex, doc.content, re.MULTILINE)
                for match in matches:
                    component = match.group(1).strip()
                    if component not in components:
                        components.append(component)

        return ArchitectureClaims(
            pattern=pattern,
            layers=layers[:10],  # Limit to prevent noise
            components=components[:20],
            data_flow=data_flow,
            documented_in=documented_in,
        )

    def _extract_setup_guide(self, docs: List[DocumentFile]) -> SetupGuide:
        """Extract setup and installation instructions."""
        prerequisites: List[str] = []
        build_steps: List[str] = []
        environment_vars: List[str] = []
        deployment_steps: List[str] = []
        documented_in: List[str] = []

        for doc in docs:
            # Extract prerequisites
            prereq_section = extract_section(
                doc.content, ["prerequisite", "requirement", "dependencies"]
            )
            if prereq_section:
                prerequisites.extend(extract_list_items(prereq_section))
                documented_in.append(doc.path)

            # Extract build steps
            build_section = extract_section(
                doc.content, ["build", "installation", "install", "setup"]
            )
            if build_section:
                build_steps.extend(extract_list_items(build_section))
                build_steps.extend(extract_code_blocks(build_section))

            # Extract environment variables
            env_vars = re.findall(r"[A-Z_]{3,}=", doc.content)
            environment_vars.extend(set(env_vars))

            # Create claims for setup instructions
            if build_steps:
                self.claims.append(
                    Claim(
                        source_doc=doc.path,
                        claim_type=ClaimType.SETUP,
                        description=f"Build steps documented ({len(build_steps)} steps)",
                        testable=True,
                        severity=Severity.MEDIUM,
                    )
                )

        return SetupGuide(
            prerequisites=list(set(prerequisites))[:20],
            build_steps=build_steps[:30],
            environment_vars=list(set(environment_vars))[:50],
            deployment_steps=deployment_steps,
            documented_in=list(set(documented_in)),
        )

    def _extract_api_spec(self, docs: List[DocumentFile]) -> Optional[APISpec]:
        """Extract API documentation."""
        endpoints: List[Dict[str, str]] = []
        api_type = None
        documented_in: List[str] = []

        for doc in docs:
            content_lower = doc.content.lower()

            # Detect API type
            if "graphql" in content_lower:
                api_type = "GraphQL"
            elif "grpc" in content_lower:
                api_type = "gRPC"
            elif any(
                keyword in content_lower for keyword in ["rest", "api", "endpoint"]
            ):
                api_type = "REST"

            # Extract endpoint patterns
            # Look for HTTP methods and paths
            endpoint_patterns = [
                r"(GET|POST|PUT|DELETE|PATCH)\s+([/\w\-{}:]+)",
                r"`(GET|POST|PUT|DELETE|PATCH)\s+([/\w\-{}:]+)`",
            ]

            for pattern in endpoint_patterns:
                matches = re.finditer(pattern, doc.content)
                for match in matches:
                    endpoints.append(
                        {"method": match.group(1), "path": match.group(2)}
                    )

            if endpoints or api_type:
                documented_in.append(doc.path)

        if not api_type and not endpoints:
            return None

        if api_type:
            self.claims.append(
                Claim(
                    source_doc=documented_in[0] if documented_in else "unknown",
                    claim_type=ClaimType.API,
                    description=f"API type: {api_type}",
                    testable=True,
                    severity=Severity.MEDIUM,
                )
            )

        return APISpec(
            endpoints=endpoints[:50],  # Limit to prevent noise
            api_type=api_type,
            documented_in=documented_in,
        )

    def _extract_coding_standards(
        self, docs: List[DocumentFile]
    ) -> Optional[CodingStandards]:
        """Extract coding standards and conventions."""
        if not docs:
            return None

        style_guide = None
        linting_tools: List[str] = []
        naming_conventions: List[str] = []
        documented_in: List[str] = []

        for doc in docs:
            # Look for style guide mentions
            content_lower = doc.content.lower()
            if "style guide" in content_lower or "coding standard" in content_lower:
                style_guide = "Documented in " + doc.path
                documented_in.append(doc.path)

            # Detect linting tools
            tools = ["pylint", "eslint", "rubocop", "black", "prettier", "shellcheck"]
            for tool in tools:
                if tool in content_lower and tool not in linting_tools:
                    linting_tools.append(tool)

        return CodingStandards(
            style_guide=style_guide,
            linting_tools=linting_tools,
            naming_conventions=naming_conventions,
            documented_in=documented_in,
        )

    def _extract_known_issues(self, docs: List[DocumentFile]) -> List[Issue]:
        """Extract known issues from documentation."""
        issues: List[Issue] = []

        for doc in docs:
            # Look for known issues sections
            issues_section = extract_section(
                doc.content, ["known issue", "limitation", "bug", "todo"]
            )
            if issues_section:
                items = extract_list_items(issues_section)
                for item in items[:10]:  # Limit
                    issues.append(
                        Issue(
                            title=item[:100],
                            description=item,
                            severity=Severity.INFO,
                            source=doc.path,
                        )
                    )

        return issues

    def _calculate_completeness(self, docs: List[DocumentFile]) -> float:
        """Calculate documentation completeness score (0-100)."""
        score = 0.0
        max_score = 100.0

        # Check for essential documents
        doc_types = {d.doc_type for d in docs}

        weights = {
            "primary": 30,  # README
            "contributing": 15,
            "architecture": 20,
            "setup": 15,
            "api": 10,
            "changelog": 5,
            "license": 5,
        }

        for doc_type, weight in weights.items():
            if doc_type in doc_types:
                score += weight

        return min(score, max_score)
