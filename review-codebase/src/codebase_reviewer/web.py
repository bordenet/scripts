"""Web interface for Codebase Reviewer."""

import os
import tempfile

from flask import Flask, render_template, request, jsonify, send_file

from codebase_reviewer.orchestrator import AnalysisOrchestrator
from codebase_reviewer.prompt_generator import PromptGenerator

# Get template directory
template_dir = os.path.join(os.path.dirname(__file__), "templates")
app = Flask(__name__, template_folder=template_dir)

# Store analysis results in memory (for MVP)
analysis_cache = {}


@app.route("/")
def index():
    """Render main page."""
    return render_template("index.html")


@app.route("/api/analyze", methods=["POST"])
def analyze():
    """Analyze a repository."""
    try:
        data = request.get_json()
        repo_path = data.get("repo_path")

        if not repo_path:
            return jsonify({"error": "repo_path is required"}), 400

        if not os.path.exists(repo_path):
            return jsonify({"error": f"Path does not exist: {repo_path}"}), 400

        # Run analysis
        orchestrator = AnalysisOrchestrator()
        analysis = orchestrator.run_full_analysis(repo_path)

        # Cache analysis
        analysis_cache[repo_path] = analysis

        # Prepare response
        response = {
            "repository_path": analysis.repository_path,
            "timestamp": analysis.timestamp.isoformat(),
            "duration_seconds": analysis.analysis_duration_seconds,
            "documentation": {
                "total_docs": (
                    len(analysis.documentation.discovered_docs)
                    if analysis.documentation
                    else 0
                ),
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

        return jsonify(response)

    except Exception as e:  # pylint: disable=broad-except
        import traceback

        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/download-prompts")
def download_prompts():
    """Download generated prompts."""
    repo_path = request.args.get("repo")
    format_type = request.args.get("format", "markdown")

    if not repo_path or repo_path not in analysis_cache:
        return jsonify({"error": "No analysis found for this repository"}), 404

    analysis = analysis_cache[repo_path]
    if not analysis.prompts:
        return jsonify({"error": "No prompts generated"}), 404

    prompt_gen = PromptGenerator()

    if format_type == "markdown":
        content = prompt_gen.export_prompts_markdown(analysis.prompts)
        mimetype = "text/markdown"
        filename = "prompts.md"
    else:  # json
        content = prompt_gen.export_prompts_json(analysis.prompts)
        mimetype = "application/json"
        filename = "prompts.json"

    # Create temporary file
    fd, path = tempfile.mkstemp(suffix=f".{filename.split('.')[-1]}")
    with os.fdopen(fd, "w") as f:
        f.write(content)

    return send_file(
        path, mimetype=mimetype, as_attachment=True, download_name=filename
    )


def run_server(host="127.0.0.1", port=5000, debug=False):
    """Run the web server."""
    print(f"\n🚀 Codebase Reviewer Web Interface")
    print(f"   Starting server at http://{host}:{port}")
    print(f"   Press Ctrl+C to stop\n")

    app.run(host=host, port=port, debug=debug)


if __name__ == "__main__":
    run_server(debug=True)
