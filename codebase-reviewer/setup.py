"""Setup configuration for Codebase Reviewer."""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="codebase-reviewer",
    version="1.0.0",
    author="Engineering Excellence Team",
    author_email="engineering@example.com",
    description="AI-powered codebase analysis and onboarding tool",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/bordenet/scripts",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Quality Assurance",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.9",
    install_requires=[
        "Flask>=3.0.0",
        "Jinja2>=3.1.2",
        "GitPython>=3.1.40",
        "PyYAML>=6.0.1",
        "click>=8.1.7",
        "pygments>=2.17.2",
        "chardet>=5.2.0",
        "pathspec>=0.11.2",
        "toml>=0.10.2",
        "python-dotenv>=1.0.0",
        "dataclasses-json>=0.6.3",
        "requests>=2.31.0",
    ],
    extras_require={
        "dev": [
            "pylint>=3.0.3",
            "pytest>=7.4.3",
            "pytest-cov>=4.1.0",
            "black>=23.12.1",
            "mypy>=1.7.1",
        ],
    },
    entry_points={
        "console_scripts": [
            "codebase-reviewer=codebase_reviewer.cli:main",
        ],
    },
)
