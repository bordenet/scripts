"""Command-line interface for Codebase Reviewer."""

import json
import sys
from pathlib import Path

import click

from codebase_reviewer.orchestrator import AnalysisOrchestrator
from codebase_reviewer.prompt_generator import PromptGenerator


@click.group()
@click.version_option(version="1.0.0")
def cli():
    """Codebase Reviewer - AI-powered codebase analysis and onboarding tool."""


@cli.command()
@click.argument("repo_path", type=click.Path(exists=True))
@click.option(
    "--output",
    "-o",
    type=click.Path(),
    help="Output file for analysis results (JSON)",
)
@click.option(
    "--prompts-output",
    "-p",
    type=click.Path(),
    help="Output file for generated prompts (Markdown)",
)
@click.option(
    "--format",
    "-f",
    type=click.Choice(["json", "markdown", "both"]),
    default="both",
    help="Output format for prompts",
)
@click.option("--quiet", "-q", is_flag=True, help="Suppress progress output")
def analyze(repo_path, output, prompts_output, format, quiet):  # pylint: disable=redefined-builtin
    """Analyze a codebase and generate AI review prompts."""
    try:
        # Resolve absolute path
        repo_path = str(Path(repo_path).resolve())

        if not quiet:
            click.echo(
                click.style(
                    f"\nCodebase Reviewer - Analyzing: {repo_path}\n",
                    fg="cyan",
                    bold=True,
                )
            )

        # Run analysis
        orchestrator = AnalysisOrchestrator()

        def progress_callback(message):
            if not quiet:
                click.echo(f"  {message}")

        analysis = orchestrator.run_full_analysis(
            repo_path, progress_callback=progress_callback
        )

        # Save analysis results if requested
        if output:
            output_data = {
                "repository_path": analysis.repository_path,
                "timestamp": analysis.timestamp.isoformat(),
                "duration_seconds": analysis.analysis_duration_seconds,
                "documentation": {
                    "total_docs": len(analysis.documentation.discovered_docs)
                    if analysis.documentation
                    else 0,
                    "completeness_score": (
                        analysis.documentation.completeness_score
                        if analysis.documentation
                        else 0
                    ),
                    "claims_count": (
                        len(analysis.documentation.claims)
                        if analysis.documentation
                        else 0
                    ),
                },
                "code": {
                    "languages": [
                        {"name": l.name, "percentage": l.percentage}
                        for l in (
                            analysis.code.structure.languages
                            if analysis.code and analysis.code.structure
                            else []
                        )
                    ],
                    "frameworks": [
                        f.name
                        for f in (
                            analysis.code.structure.frameworks
                            if analysis.code and analysis.code.structure
                            else []
                        )
                    ],
                    "quality_issues_count": (
                        len(analysis.code.quality_issues) if analysis.code else 0
                    ),
                },
                "validation": {
                    "drift_severity": (
                        analysis.validation.drift_severity.value
                        if analysis.validation
                        else "unknown"
                    ),
                    "architecture_drift_count": (
                        len(analysis.validation.architecture_drift)
                        if analysis.validation
                        else 0
                    ),
                    "setup_drift_count": (
                        len(analysis.validation.setup_drift)
                        if analysis.validation
                        else 0
                    ),
                },
                "prompts": {
                    "total_count": (
                        len(analysis.prompts.all_prompts()) if analysis.prompts else 0
                    ),
                    "by_phase": {
                        f"phase{i}": (
                            len(getattr(analysis.prompts, f"phase{i}"))
                            if analysis.prompts
                            else 0
                        )
                        for i in range(5)
                    },
                },
            }

            with open(output, "w", encoding="utf-8") as f:
                json.dump(output_data, f, indent=2)

            if not quiet:
                click.echo(
                    click.style(
                        f"\n✓ Analysis results saved to: {output}", fg="green"
                    )
                )

        # Save prompts
        if analysis.prompts:
            prompt_gen = PromptGenerator()

            # Determine output file
            if not prompts_output:
                prompts_output = "prompts.md" if format != "json" else "prompts.json"

            if format in ["markdown", "both"]:
                md_output = (
                    prompts_output if prompts_output.endswith(".md") else f"{prompts_output}.md"
                )
                markdown_content = prompt_gen.export_prompts_markdown(
                    analysis.prompts
                )
                with open(md_output, "w", encoding="utf-8") as f:
                    f.write(markdown_content)

                if not quiet:
                    click.echo(
                        click.style(
                            f"✓ Prompts saved to: {md_output}", fg="green"
                        )
                    )

            if format in ["json", "both"]:
                json_output = (
                    prompts_output
                    if prompts_output.endswith(".json")
                    else f"{prompts_output}.json"
                )
                json_content = prompt_gen.export_prompts_json(analysis.prompts)
                with open(json_output, "w", encoding="utf-8") as f:
                    f.write(json_content)

                if not quiet:
                    click.echo(
                        click.style(
                            f"✓ Prompts saved to: {json_output}", fg="green"
                        )
                    )

        # Display summary
        if not quiet:
            display_summary(analysis)

    except Exception as e:  # pylint: disable=broad-except
        click.echo(click.style(f"\n✗ Error: {str(e)}", fg="red"), err=True)
        if not quiet:
            import traceback

            traceback.print_exc()
        sys.exit(1)


def display_summary(analysis):
    """Display analysis summary."""
    click.echo(
        click.style("\n" + "=" * 60, fg="cyan")
    )
    click.echo(click.style("ANALYSIS SUMMARY", fg="cyan", bold=True))
    click.echo(click.style("=" * 60, fg="cyan"))

    # Documentation
    if analysis.documentation:
        click.echo(click.style("\nDocumentation:", fg="yellow", bold=True))
        click.echo(
            f"  Files found: {len(analysis.documentation.discovered_docs)}"
        )
        click.echo(
            f"  Completeness: {analysis.documentation.completeness_score:.1f}%"
        )
        click.echo(f"  Claims extracted: {len(analysis.documentation.claims)}")

        if analysis.documentation.claimed_architecture:
            arch = analysis.documentation.claimed_architecture
            if arch.pattern:
                click.echo(f"  Architecture: {arch.pattern}")

    # Code
    if analysis.code and analysis.code.structure:
        click.echo(click.style("\nCode Structure:", fg="yellow", bold=True))
        for lang in analysis.code.structure.languages[:5]:
            click.echo(f"  {lang.name}: {lang.percentage:.1f}%")

        if analysis.code.structure.frameworks:
            click.echo(
                f"  Frameworks: {', '.join(f.name for f in analysis.code.structure.frameworks)}"
            )

        if analysis.code.quality_issues:
            click.echo(
                f"  Quality issues: {len(analysis.code.quality_issues)}"
            )

    # Validation
    if analysis.validation:
        click.echo(click.style("\nValidation:", fg="yellow", bold=True))
        click.echo(
            f"  Drift severity: {analysis.validation.drift_severity.value.upper()}"
        )
        drift_total = (
            len(analysis.validation.architecture_drift)
            + len(analysis.validation.setup_drift)
            + len(analysis.validation.api_drift)
        )
        click.echo(f"  Drift issues: {drift_total}")

        if analysis.validation.undocumented_features:
            click.echo(
                f"  Undocumented features: {len(analysis.validation.undocumented_features)}"
            )

    # Prompts
    if analysis.prompts:
        click.echo(click.style("\nGenerated Prompts:", fg="yellow", bold=True))
        total = len(analysis.prompts.all_prompts())
        click.echo(f"  Total prompts: {total}")
        for phase in range(5):
            count = len(getattr(analysis.prompts, f"phase{phase}"))
            if count > 0:
                phase_names = {
                    0: "Documentation Review",
                    1: "Architecture Analysis",
                    2: "Implementation Deep-Dive",
                    3: "Development Workflow",
                    4: "Interactive Remediation",
                }
                click.echo(f"  Phase {phase} ({phase_names[phase]}): {count}")

    click.echo(
        click.style(
            f"\nCompleted in {analysis.analysis_duration_seconds:.2f} seconds\n",
            fg="green",
        )
    )


@cli.command()
@click.argument("repo_path", type=click.Path(exists=True))
@click.option(
    "--phase",
    "-p",
    type=click.IntRange(0, 4),
    help="Show only specific phase (0-4)",
)
def prompts(repo_path, phase):
    """Generate and display prompts for a repository."""
    try:
        repo_path = str(Path(repo_path).resolve())

        click.echo(
            click.style(
                f"\nGenerating prompts for: {repo_path}\n", fg="cyan", bold=True
            )
        )

        orchestrator = AnalysisOrchestrator()
        analysis = orchestrator.run_full_analysis(repo_path)

        if not analysis.prompts:
            click.echo(click.style("No prompts generated", fg="red"), err=True)
            sys.exit(1)

        # Display prompts
        phases_to_show = [phase] if phase is not None else range(5)

        for phase_num in phases_to_show:
            phase_prompts = getattr(analysis.prompts, f"phase{phase_num}")
            if not phase_prompts:
                continue

            phase_names = {
                0: "Documentation Review",
                1: "Architecture Analysis",
                2: "Implementation Deep-Dive",
                3: "Development Workflow",
                4: "Interactive Remediation",
            }

            click.echo(
                click.style(
                    f"\n{'=' * 60}\n"
                    f"PHASE {phase_num}: {phase_names[phase_num]}\n"
                    f"{'=' * 60}\n",
                    fg="cyan",
                    bold=True,
                )
            )

            for prompt in phase_prompts:
                click.echo(
                    click.style(f"\n[{prompt.prompt_id}] {prompt.title}", bold=True)
                )
                click.echo(f"\nObjective: {prompt.objective}\n")
                click.echo("Tasks:")
                for task in prompt.tasks:
                    click.echo(f"  • {task}")
                click.echo(f"\nDeliverable: {prompt.deliverable}\n")
                click.echo("-" * 60)

    except Exception as e:  # pylint: disable=broad-except
        click.echo(click.style(f"\n✗ Error: {str(e)}", fg="red"), err=True)
        sys.exit(1)


@cli.command()
@click.option(
    "--host",
    "-h",
    default="127.0.0.1",
    help="Host to bind to (default: 127.0.0.1)",
)
@click.option(
    "--port",
    "-p",
    default=5000,
    type=int,
    help="Port to bind to (default: 5000)",
)
@click.option("--debug", is_flag=True, help="Run in debug mode")
def web(host, port, debug):
    """Start the web interface."""
    try:
        from codebase_reviewer.web import run_server

        run_server(host=host, port=port, debug=debug)
    except ImportError as e:
        click.echo(
            click.style(f"\n✗ Error: {str(e)}", fg="red"), err=True
        )
        click.echo("\nMake sure Flask is installed: pip install Flask")
        sys.exit(1)
    except Exception as e:  # pylint: disable=broad-except
        click.echo(click.style(f"\n✗ Error: {str(e)}", fg="red"), err=True)
        sys.exit(1)


def main():
    """Main entry point."""
    cli()


if __name__ == "__main__":
    main()
