"""Basic tests for codebase reviewer."""

import os
import tempfile
from pathlib import Path

from codebase_reviewer.analyzers.documentation import DocumentationAnalyzer
from codebase_reviewer.analyzers.code import CodeAnalyzer
from codebase_reviewer.analyzers.validation import ValidationEngine
from codebase_reviewer.orchestrator import AnalysisOrchestrator


def test_documentation_analyzer():
    """Test documentation analyzer."""
    analyzer = DocumentationAnalyzer()

    # Create a temporary directory with a README
    with tempfile.TemporaryDirectory() as tmpdir:
        readme_path = Path(tmpdir) / "README.md"
        readme_path.write_text("# Test Project\n\nThis is a microservices project.")

        analysis = analyzer.analyze(tmpdir)

        assert analysis is not None
        assert len(analysis.discovered_docs) > 0
        assert analysis.discovered_docs[0].doc_type == "primary"


def test_code_analyzer():
    """Test code analyzer."""
    analyzer = CodeAnalyzer()

    # Create a temporary directory with a Python file
    with tempfile.TemporaryDirectory() as tmpdir:
        py_file = Path(tmpdir) / "main.py"
        py_file.write_text("print('Hello, World!')")

        analysis = analyzer.analyze(tmpdir)

        assert analysis is not None
        assert analysis.structure is not None
        assert len(analysis.structure.languages) > 0
        assert analysis.structure.languages[0].name == "Python"


def test_validation_engine():
    """Test validation engine."""
    engine = ValidationEngine()

    # This is a basic test - just ensure it doesn't crash
    from codebase_reviewer.models import (
        DocumentationAnalysis,
        CodeAnalysis,
    )

    docs = DocumentationAnalysis()
    code = CodeAnalysis()

    result = engine.validate(docs, code)

    assert result is not None
    assert result.drift_severity is not None


def test_orchestrator():
    """Test full orchestration."""
    orchestrator = AnalysisOrchestrator()

    # Create a temporary directory with sample files
    with tempfile.TemporaryDirectory() as tmpdir:
        readme = Path(tmpdir) / "README.md"
        readme.write_text("# Test\nA Flask application.")

        py_file = Path(tmpdir) / "app.py"
        py_file.write_text("from flask import Flask\napp = Flask(__name__)")

        analysis = orchestrator.run_full_analysis(tmpdir)

        assert analysis is not None
        assert analysis.documentation is not None
        assert analysis.code is not None
        assert analysis.validation is not None
        assert analysis.prompts is not None
        assert len(analysis.prompts.all_prompts()) > 0


if __name__ == "__main__":
    print("Running tests...")
    test_documentation_analyzer()
    print("✓ Documentation analyzer test passed")

    test_code_analyzer()
    print("✓ Code analyzer test passed")

    test_validation_engine()
    print("✓ Validation engine test passed")

    test_orchestrator()
    print("✓ Orchestrator test passed")

    print("\n✓ All tests passed!")
