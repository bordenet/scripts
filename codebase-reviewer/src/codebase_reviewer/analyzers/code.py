"""Code analyzer - analyzes repository code structure and quality."""

import os
import re
from collections import Counter
from pathlib import Path
from typing import Dict, List, Optional

from codebase_reviewer.models import (
    CodeAnalysis,
    CodeStructure,
    DependencyInfo,
    DirectoryTree,
    EntryPoint,
    Framework,
    Issue,
    Language,
    Severity,
)


# Language file extensions
LANGUAGE_EXTENSIONS = {
    ".py": "Python",
    ".js": "JavaScript",
    ".ts": "TypeScript",
    ".jsx": "JavaScript",
    ".tsx": "TypeScript",
    ".java": "Java",
    ".cs": "C#",
    ".go": "Go",
    ".rb": "Ruby",
    ".php": "PHP",
    ".rs": "Rust",
    ".cpp": "C++",
    ".c": "C",
    ".h": "C/C++",
    ".hpp": "C++",
    ".sh": "Shell",
    ".bash": "Shell",
    ".sql": "SQL",
    ".kt": "Kotlin",
    ".swift": "Swift",
    ".m": "Objective-C",
    ".scala": "Scala",
}

# Framework detection patterns
FRAMEWORK_PATTERNS = {
    "Flask": [("requirements.txt", "Flask"), ("*.py", "from flask import")],
    "Django": [("requirements.txt", "Django"), ("*.py", "from django")],
    "Express": [("package.json", "express")],
    "React": [("package.json", "react")],
    "Vue": [("package.json", "vue")],
    "Angular": [("package.json", "@angular")],
    "Spring Boot": [("pom.xml", "spring-boot"), ("build.gradle", "spring-boot")],
    ".NET Core": [("*.csproj", "Microsoft.NET.Sdk")],
    "Rails": [("Gemfile", "rails")],
}

# Dependency file patterns
DEPENDENCY_FILES = {
    "Python": ["requirements.txt", "setup.py", "Pipfile", "pyproject.toml"],
    "JavaScript": ["package.json", "yarn.lock", "package-lock.json"],
    "Java": ["pom.xml", "build.gradle"],
    "C#": ["*.csproj", "packages.config"],
    "Go": ["go.mod", "go.sum"],
    "Ruby": ["Gemfile", "Gemfile.lock"],
    "Rust": ["Cargo.toml", "Cargo.lock"],
}


class CodeAnalyzer:
    """Analyzes repository code structure, patterns, and quality."""

    def analyze(self, repo_path: str) -> CodeAnalysis:
        """
        Analyze code in repository.

        Args:
            repo_path: Path to repository root

        Returns:
            CodeAnalysis with code metrics and findings
        """
        # Analyze structure
        structure = self._analyze_structure(repo_path)

        # Analyze dependencies
        dependencies = self._analyze_dependencies(repo_path, structure)

        # Basic quality metrics
        quality_issues = self._analyze_quality(repo_path)

        return CodeAnalysis(
            structure=structure,
            dependencies=dependencies,
            complexity_metrics={},
            quality_issues=quality_issues,
        )

    def _analyze_structure(self, repo_path: str) -> CodeStructure:
        """Analyze code structure."""
        # Detect languages
        languages = self._detect_languages(repo_path)

        # Detect frameworks
        frameworks = self._detect_frameworks(repo_path)

        # Find entry points
        entry_points = self._find_entry_points(repo_path, languages)

        # Build directory tree
        directory_tree = self._build_directory_tree(repo_path)

        return CodeStructure(
            languages=languages,
            frameworks=frameworks,
            entry_points=entry_points,
            directory_tree=directory_tree,
        )

    def _detect_languages(self, repo_path: str) -> List[Language]:
        """Detect programming languages in repository."""
        extension_counts: Counter = Counter()
        extension_lines: Dict[str, int] = {}

        for root, _, files in os.walk(repo_path):
            # Skip common ignore directories
            if any(
                skip in root
                for skip in [
                    ".git",
                    "node_modules",
                    "venv",
                    "__pycache__",
                    "build",
                    "dist",
                ]
            ):
                continue

            for file in files:
                ext = Path(file).suffix.lower()
                if ext in LANGUAGE_EXTENSIONS:
                    extension_counts[ext] += 1

                    # Count lines
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, "r", encoding="utf-8") as f_handle:
                            lines = sum(1 for _ in f_handle)
                            extension_lines[ext] = (
                                extension_lines.get(ext, 0) + lines
                            )
                    except (UnicodeDecodeError, PermissionError):
                        pass

        # Calculate percentages
        total_files = sum(extension_counts.values())
        if total_files == 0:
            return []

        languages: List[Language] = []
        for ext, count in extension_counts.most_common():
            lang_name = LANGUAGE_EXTENSIONS[ext]
            percentage = (count / total_files) * 100
            languages.append(
                Language(
                    name=lang_name,
                    percentage=percentage,
                    file_count=count,
                    line_count=extension_lines.get(ext, 0),
                )
            )

        return languages

    def _detect_frameworks(self, repo_path: str) -> List[Framework]:
        """Detect frameworks used in repository."""
        frameworks: List[Framework] = []

        for framework_name, patterns in FRAMEWORK_PATTERNS.items():
            for file_pattern, search_term in patterns:
                if self._search_for_pattern(repo_path, file_pattern, search_term):
                    frameworks.append(
                        Framework(name=framework_name, confidence=0.8)
                    )
                    break

        return frameworks

    def _search_for_pattern(
        self, repo_path: str, file_pattern: str, search_term: str
    ) -> bool:
        """Search for pattern in files."""
        repo_root = Path(repo_path)

        # Handle glob patterns
        if "*" in file_pattern:
            files = list(repo_root.glob(f"**/{file_pattern}"))
        else:
            # Check specific file
            file_path = repo_root / file_pattern
            files = [file_path] if file_path.exists() else []

        for file_path in files:
            if not file_path.is_file():
                continue

            try:
                with open(file_path, "r", encoding="utf-8") as f_handle:
                    content = f_handle.read()
                    if search_term.lower() in content.lower():
                        return True
            except (UnicodeDecodeError, PermissionError):
                continue

        return False

    def _find_entry_points(
        self, repo_path: str, languages: List[Language]
    ) -> List[EntryPoint]:
        """Find application entry points."""
        entry_points: List[EntryPoint] = []

        # Common entry point patterns
        entry_patterns = {
            "main.py": "Python main script",
            "app.py": "Python application",
            "server.py": "Python server",
            "index.js": "JavaScript entry point",
            "server.js": "JavaScript server",
            "main.js": "JavaScript main",
            "Main.java": "Java main class",
            "Program.cs": "C# program",
            "main.go": "Go main",
        }

        repo_root = Path(repo_path)

        for pattern, description in entry_patterns.items():
            for file_path in repo_root.glob(f"**/{pattern}"):
                if self._is_valid_source_path(file_path):
                    entry_points.append(
                        EntryPoint(
                            path=str(file_path.relative_to(repo_root)),
                            entry_type="main",
                            description=description,
                        )
                    )

        return entry_points[:10]  # Limit results

    def _is_valid_source_path(self, path: Path) -> bool:
        """Check if path is in valid source directory."""
        path_str = str(path)
        excluded = [
            "node_modules",
            "venv",
            ".git",
            "__pycache__",
            "build",
            "dist",
            "test",
        ]
        return not any(exc in path_str for exc in excluded)

    def _build_directory_tree(self, repo_path: str) -> DirectoryTree:
        """Build directory structure representation."""
        total_files = 0
        total_dirs = 0

        for root, dirs, files in os.walk(repo_path):
            # Skip ignored directories
            dirs[:] = [
                d
                for d in dirs
                if d not in [".git", "node_modules", "venv", "__pycache__"]
            ]
            total_dirs += len(dirs)
            total_files += len(files)

        return DirectoryTree(
            root=repo_path,
            structure={},  # Simplified for MVP
            total_files=total_files,
            total_dirs=total_dirs,
        )

    def _analyze_dependencies(
        self, repo_path: str, structure: CodeStructure
    ) -> List[DependencyInfo]:
        """Analyze project dependencies."""
        dependencies: List[DependencyInfo] = []

        # Extract primary language
        if not structure.languages:
            return dependencies

        primary_lang = structure.languages[0].name

        # Get dependency files for this language
        dep_files = DEPENDENCY_FILES.get(primary_lang, [])

        repo_root = Path(repo_path)

        for dep_file_pattern in dep_files:
            if "*" in dep_file_pattern:
                files = list(repo_root.glob(f"**/{dep_file_pattern}"))
            else:
                file_path = repo_root / dep_file_pattern
                files = [file_path] if file_path.exists() else []

            for file_path in files:
                if file_path.is_file():
                    deps = self._parse_dependency_file(file_path, primary_lang)
                    dependencies.extend(deps)

        return dependencies

    def _parse_dependency_file(
        self, file_path: Path, language: str
    ) -> List[DependencyInfo]:
        """Parse dependency file."""
        dependencies: List[DependencyInfo] = []

        try:
            with open(file_path, "r", encoding="utf-8") as f_handle:
                content = f_handle.read()

            if file_path.name == "requirements.txt":
                # Parse Python requirements
                for line in content.split("\n"):
                    line = line.strip()
                    if line and not line.startswith("#"):
                        # Simple parsing
                        match = re.match(r"([a-zA-Z0-9\-_]+)(==|>=|<=)?(.+)?", line)
                        if match:
                            name = match.group(1)
                            version = match.group(3) if match.group(3) else None
                            dependencies.append(
                                DependencyInfo(
                                    name=name,
                                    version=version,
                                    dependency_type="production",
                                    source_file=str(file_path.name),
                                )
                            )

            elif file_path.name == "package.json":
                # Parse JavaScript package.json (basic)
                import json

                try:
                    data = json.loads(content)
                    for dep_type in ["dependencies", "devDependencies"]:
                        if dep_type in data:
                            for name, version in data[dep_type].items():
                                dependencies.append(
                                    DependencyInfo(
                                        name=name,
                                        version=version,
                                        dependency_type=(
                                            "production"
                                            if dep_type == "dependencies"
                                            else "development"
                                        ),
                                        source_file=str(file_path.name),
                                    )
                                )
                except json.JSONDecodeError:
                    pass

        except (UnicodeDecodeError, PermissionError):
            pass

        return dependencies

    def _analyze_quality(self, repo_path: str) -> List[Issue]:
        """Perform basic code quality analysis."""
        issues: List[Issue] = []

        # Check for common issues
        issues.extend(self._check_for_todos(repo_path))
        issues.extend(self._check_for_security_issues(repo_path))

        return issues

    def _check_for_todos(self, repo_path: str) -> List[Issue]:
        """Find TODO/FIXME/HACK comments."""
        issues: List[Issue] = []
        todo_pattern = re.compile(r"#\s*(TODO|FIXME|HACK|XXX):\s*(.+)", re.IGNORECASE)

        for root, _, files in os.walk(repo_path):
            if any(skip in root for skip in [".git", "node_modules", "venv"]):
                continue

            for file in files:
                if Path(file).suffix in LANGUAGE_EXTENSIONS:
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, "r", encoding="utf-8") as f_handle:
                            for line_num, line in enumerate(f_handle, 1):
                                match = todo_pattern.search(line)
                                if match:
                                    todo_type = match.group(1)
                                    description = match.group(2).strip()
                                    relative_path = os.path.relpath(
                                        file_path, repo_path
                                    )
                                    issues.append(
                                        Issue(
                                            title=f"{todo_type} in {relative_path}:{line_num}",
                                            description=description,
                                            severity=Severity.LOW,
                                            source=relative_path,
                                        )
                                    )
                                    if len(issues) >= 100:  # Limit
                                        return issues
                    except (UnicodeDecodeError, PermissionError):
                        continue

        return issues

    def _check_for_security_issues(self, repo_path: str) -> List[Issue]:
        """Basic security issue detection."""
        issues: List[Issue] = []

        # Check for exposed secrets patterns
        secret_patterns = [
            (r"password\s*=\s*['\"](.+)['\"]", "Hardcoded password"),
            (r"api[_-]?key\s*=\s*['\"](.+)['\"]", "Hardcoded API key"),
            (r"secret\s*=\s*['\"](.+)['\"]", "Hardcoded secret"),
        ]

        for root, _, files in os.walk(repo_path):
            if any(skip in root for skip in [".git", "node_modules", "venv"]):
                continue

            for file in files:
                if Path(file).suffix in LANGUAGE_EXTENSIONS:
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, "r", encoding="utf-8") as f_handle:
                            content = f_handle.read()

                            for pattern, description in secret_patterns:
                                if re.search(pattern, content, re.IGNORECASE):
                                    relative_path = os.path.relpath(
                                        file_path, repo_path
                                    )
                                    issues.append(
                                        Issue(
                                            title=f"Potential {description}",
                                            description=f"Found in {relative_path}",
                                            severity=Severity.HIGH,
                                            source=relative_path,
                                        )
                                    )
                                    if len(issues) >= 20:  # Limit
                                        return issues
                    except (UnicodeDecodeError, PermissionError):
                        continue

        return issues
