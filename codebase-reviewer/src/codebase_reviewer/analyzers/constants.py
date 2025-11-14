"""Constants for analyzers."""

# Documentation file patterns by priority
DOCUMENTATION_PATTERNS = {
    "primary": ["README.md", "README.rst", "README.txt", "README"],
    "contributing": [
        "CONTRIBUTING.md",
        "CONTRIBUTING.rst",
        ".github/CONTRIBUTING.md",
    ],
    "architecture": [
        "ARCHITECTURE.md",
        "docs/architecture.md",
        "docs/architecture/**/*.md",
        "ADR/*.md",
        "docs/adr/**/*.md",
    ],
    "api": ["API.md", "docs/api/**/*.md", "openapi.yaml", "swagger.json"],
    "setup": ["INSTALL.md", "SETUP.md", "docs/setup/**/*.md"],
    "changelog": ["CHANGELOG.md", "HISTORY.md", "RELEASES.md"],
    "security": ["SECURITY.md", ".github/SECURITY.md"],
    "license": ["LICENSE", "LICENSE.md", "COPYING"],
    "code_of_conduct": ["CODE_OF_CONDUCT.md", ".github/CODE_OF_CONDUCT.md"],
}

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
