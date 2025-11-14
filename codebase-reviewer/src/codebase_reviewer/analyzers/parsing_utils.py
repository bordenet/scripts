"""Parsing utilities for analyzers."""

import re
from typing import List, Optional


def extract_section(content: str, keywords: List[str]) -> Optional[str]:
    """Extract section from markdown based on keywords."""
    lines = content.split("\n")
    in_section = False
    section_lines: List[str] = []
    current_level = 0

    for line in lines:
        # Check if this is a header
        header_match = re.match(r"^(#{1,6})\s+(.+)$", line)

        if header_match:
            level = len(header_match.group(1))
            title = header_match.group(2).lower()

            # Check if this header matches our keywords
            if any(keyword in title for keyword in keywords):
                in_section = True
                current_level = level
                section_lines = [line]
                continue

            # If we're in a section and hit a same/higher level header, stop
            if in_section and level <= current_level:
                break

        if in_section:
            section_lines.append(line)

    return "\n".join(section_lines) if section_lines else None


def extract_list_items(content: str) -> List[str]:
    """Extract list items from content."""
    items: List[str] = []
    pattern = r"^[\s]*[-*+]\s+(.+)$"

    for line in content.split("\n"):
        match = re.match(pattern, line)
        if match:
            items.append(match.group(1).strip())

    return items


def extract_code_blocks(content: str) -> List[str]:
    """Extract code blocks from markdown."""
    pattern = r"```(?:\w+)?\n(.*?)```"
    matches = re.findall(pattern, content, re.DOTALL)
    return [match.strip() for match in matches]


def detect_architecture_pattern(content: str) -> Optional[str]:
    """Detect architectural pattern from content."""
    content_lower = content.lower()

    patterns = {
        "microservices": ["microservice", "micro-service", "service mesh"],
        "monolith": ["monolithic", "monolith"],
        "mvc": ["model-view-controller", "mvc"],
        "mvvm": ["model-view-viewmodel", "mvvm"],
        "layered": ["layered architecture", "n-tier", "three-tier"],
        "event-driven": ["event-driven", "event sourcing", "cqrs"],
        "serverless": ["serverless", "lambda", "faas"],
        "hexagonal": ["hexagonal", "ports and adapters"],
    }

    for pattern_name, keywords in patterns.items():
        if any(keyword in content_lower for keyword in keywords):
            return pattern_name

    return None
