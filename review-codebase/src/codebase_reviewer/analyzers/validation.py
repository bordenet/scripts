"""Validation engine - validates documentation claims against code reality."""

from typing import List

from codebase_reviewer.models import (
    ClaimType,
    CodeAnalysis,
    DocumentationAnalysis,
    DriftReport,
    Severity,
    ValidationResult,
    ValidationStatus,
)


class ValidationEngine:
    """Validates documentation claims against code implementation."""

    def validate(
        self, docs: DocumentationAnalysis, code: CodeAnalysis
    ) -> DriftReport:
        """
        Validate documentation against code.

        Args:
            docs: Documentation analysis results
            code: Code analysis results

        Returns:
            DriftReport with validation findings
        """
        architecture_drift = self._validate_architecture_claims(docs, code)
        setup_drift = self._validate_setup_instructions(docs, code)
        api_drift = self._validate_api_documentation(docs, code)
        undocumented_features = self._find_undocumented_features(docs, code)

        # Calculate overall drift severity
        drift_severity = self._calculate_drift_severity(
            architecture_drift, setup_drift, api_drift
        )

        return DriftReport(
            architecture_drift=architecture_drift,
            setup_drift=setup_drift,
            api_drift=api_drift,
            undocumented_features=undocumented_features,
            outdated_documentation=[],
            drift_severity=drift_severity,
        )

    def _validate_architecture_claims(
        self, docs: DocumentationAnalysis, code: CodeAnalysis
    ) -> List[ValidationResult]:
        """Validate architecture claims against actual code structure."""
        results: List[ValidationResult] = []

        if not docs.claimed_architecture or not code.structure:
            return results

        claimed_arch = docs.claimed_architecture
        actual_structure = code.structure

        # Validate architecture pattern
        if claimed_arch.pattern:
            pattern_claim = next(
                (
                    c
                    for c in docs.claims
                    if c.claim_type == ClaimType.ARCHITECTURE
                    and claimed_arch.pattern.lower() in c.description.lower()
                ),
                None,
            )

            if pattern_claim:
                # Check if claimed pattern matches detected frameworks
                pattern_valid = self._check_pattern_consistency(
                    claimed_arch.pattern, actual_structure.frameworks
                )

                results.append(
                    ValidationResult(
                        claim=pattern_claim,
                        validation_status=(
                            ValidationStatus.VALID
                            if pattern_valid
                            else ValidationStatus.PARTIAL
                        ),
                        severity=Severity.MEDIUM,
                        evidence=f"Detected frameworks: {[f.name for f in actual_structure.frameworks]}",
                        recommendation=(
                            "Architecture pattern appears consistent"
                            if pattern_valid
                            else "Verify claimed architecture matches implementation"
                        ),
                    )
                )

        # Validate claimed components exist
        if claimed_arch.components:
            # Check if entry points suggest component structure
            entry_point_paths = [ep.path for ep in actual_structure.entry_points]
            components_found = sum(
                1
                for component in claimed_arch.components
                if any(component.lower() in path.lower() for path in entry_point_paths)
            )

            if components_found < len(claimed_arch.components) * 0.5:
                # Less than 50% of claimed components found
                results.append(
                    ValidationResult(
                        claim=docs.claims[0]
                        if docs.claims
                        else None,  # type: ignore
                        validation_status=ValidationStatus.PARTIAL,
                        severity=Severity.MEDIUM,
                        evidence=f"Found {components_found}/{len(claimed_arch.components)} claimed components",
                        recommendation="Review documented component list for accuracy",
                    )
                )

        return results

    def _check_pattern_consistency(
        self, claimed_pattern: str, frameworks: List
    ) -> bool:
        """Check if claimed architecture pattern is consistent with frameworks."""
        pattern_lower = claimed_pattern.lower()

        # Pattern-framework consistency rules
        consistency_map = {
            "mvc": ["django", "rails", "spring"],
            "microservices": ["express", "flask", "spring boot"],
            "monolith": ["django", "rails"],
        }

        if pattern_lower in consistency_map:
            expected_frameworks = consistency_map[pattern_lower]
            framework_names = [f.name.lower() for f in frameworks]

            return any(
                any(exp in fname for exp in expected_frameworks)
                for fname in framework_names
            )

        # If we don't have rules, assume consistent
        return True

    def _validate_setup_instructions(
        self, docs: DocumentationAnalysis, code: CodeAnalysis
    ) -> List[ValidationResult]:
        """Validate setup instructions against actual configuration."""
        results: List[ValidationResult] = []

        if not docs.setup_instructions or not code.dependencies:
            return results

        setup = docs.setup_instructions

        # Check if documented dependencies match actual dependencies
        doc_deps = set(
            dep.lower()
            for dep in setup.prerequisites
            if len(dep) > 3  # Filter out short words
        )
        actual_deps = set(dep.name.lower() for dep in code.dependencies)

        # Find dependencies mentioned in docs but not in dependency files
        missing_deps = []
        for doc_dep in doc_deps:
            if not any(doc_dep in actual for actual in actual_deps):
                missing_deps.append(doc_dep)

        if missing_deps and len(missing_deps) > 2:
            # More than 2 discrepancies
            setup_claims = [
                c for c in docs.claims if c.claim_type == ClaimType.SETUP
            ]
            if setup_claims:
                results.append(
                    ValidationResult(
                        claim=setup_claims[0],
                        validation_status=ValidationStatus.PARTIAL,
                        severity=Severity.LOW,
                        evidence=f"Documented prerequisites may not match dependency files: {missing_deps[:5]}",
                        recommendation="Verify setup documentation matches actual requirements",
                    )
                )

        return results

    def _validate_api_documentation(
        self, docs: DocumentationAnalysis, code: CodeAnalysis
    ) -> List[ValidationResult]:
        """Validate API documentation against code."""
        results: List[ValidationResult] = []

        if not docs.api_documentation:
            return results

        api_doc = docs.api_documentation

        # Check if API type is consistent with frameworks
        if api_doc.api_type and code.structure:
            frameworks = code.structure.frameworks
            framework_names = [f.name.lower() for f in frameworks]

            api_consistent = True
            if api_doc.api_type.lower() == "graphql":
                # Check for GraphQL frameworks
                if not any("graphql" in fname for fname in framework_names):
                    api_consistent = False

            api_claims = [c for c in docs.claims if c.claim_type == ClaimType.API]
            if api_claims and not api_consistent:
                results.append(
                    ValidationResult(
                        claim=api_claims[0],
                        validation_status=ValidationStatus.PARTIAL,
                        severity=Severity.MEDIUM,
                        evidence=f"Claimed API type {api_doc.api_type} but no matching framework detected",
                        recommendation="Verify API type documentation",
                    )
                )

        return results

    def _find_undocumented_features(
        self, docs: DocumentationAnalysis, code: CodeAnalysis
    ) -> List[str]:
        """Find code features not mentioned in documentation."""
        undocumented: List[str] = []

        if not code.structure:
            return undocumented

        # Check if frameworks are documented
        detected_frameworks = {f.name for f in code.structure.frameworks}

        # Get all documentation content
        doc_content = " ".join(
            doc.content.lower() for doc in docs.discovered_docs
        )

        for framework in detected_frameworks:
            if framework.lower() not in doc_content:
                undocumented.append(f"Framework: {framework}")

        # Check if languages are documented
        if code.structure.languages:
            primary_lang = code.structure.languages[0].name
            if primary_lang.lower() not in doc_content:
                undocumented.append(f"Primary language: {primary_lang}")

        return undocumented[:10]  # Limit

    def _calculate_drift_severity(
        self,
        arch_drift: List[ValidationResult],
        setup_drift: List[ValidationResult],
        api_drift: List[ValidationResult],
    ) -> Severity:
        """Calculate overall drift severity."""
        all_results = arch_drift + setup_drift + api_drift

        if not all_results:
            return Severity.LOW

        # Count invalid/partial results
        invalid_count = sum(
            1
            for r in all_results
            if r.validation_status
            in [ValidationStatus.INVALID, ValidationStatus.PARTIAL]
        )

        # Check for critical/high severity issues
        critical_count = sum(
            1
            for r in all_results
            if r.severity in [Severity.CRITICAL, Severity.HIGH]
        )

        if critical_count > 0:
            return Severity.HIGH
        if invalid_count > 3:
            return Severity.MEDIUM

        return Severity.LOW
