"""Web interface for Codebase Reviewer."""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

from flask import (
    Flask,
    render_template_string,
    request,
    jsonify,
    send_file,
)

from codebase_reviewer.orchestrator import AnalysisOrchestrator
from codebase_reviewer.prompt_generator import PromptGenerator

app = Flask(__name__)

# Store analysis results in memory (for MVP)
analysis_cache: Dict[str, any] = {}


# HTML Templates
MAIN_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Codebase Reviewer</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 0;
            margin-bottom: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { font-size: 2.5em; margin-bottom: 10px; }
        .subtitle { font-size: 1.1em; opacity: 0.9; }
        .card {
            background: white;
            border-radius: 8px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            font-weight: 600;
            margin-bottom: 8px;
            color: #555;
        }
        input[type="text"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 4px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 14px 32px;
            font-size: 16px;
            border-radius: 4px;
            cursor: pointer;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        .progress {
            display: none;
            margin-top: 20px;
        }
        .progress-bar {
            width: 100%;
            height: 30px;
            background: #e0e0e0;
            border-radius: 15px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            width: 0%;
            transition: width 0.3s;
        }
        .status {
            margin-top: 10px;
            font-style: italic;
            color: #666;
        }
        .results {
            display: none;
            margin-top: 30px;
        }
        .metric {
            display: inline-block;
            background: #f8f9fa;
            padding: 15px 20px;
            border-radius: 6px;
            margin: 10px 10px 10px 0;
            border-left: 4px solid #667eea;
        }
        .metric-label {
            display: block;
            font-size: 0.85em;
            color: #666;
            margin-bottom: 5px;
        }
        .metric-value {
            display: block;
            font-size: 1.5em;
            font-weight: 700;
            color: #333;
        }
        .phase-section {
            margin-top: 20px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 6px;
        }
        .phase-title {
            font-size: 1.2em;
            font-weight: 600;
            margin-bottom: 15px;
            color: #667eea;
        }
        .prompt {
            background: white;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 4px;
            border-left: 3px solid #764ba2;
        }
        .prompt-title {
            font-weight: 600;
            margin-bottom: 8px;
        }
        .prompt-objective {
            color: #666;
            font-size: 0.95em;
        }
        .download-btn {
            background: #28a745;
            margin-right: 10px;
            margin-top: 10px;
        }
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 4px;
            margin-top: 20px;
            border-left: 4px solid #f5c6cb;
        }
        .info-box {
            background: #d1ecf1;
            color: #0c5460;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 20px;
            border-left: 4px solid #bee5eb;
        }
    </style>
</head>
<body>
    <header>
        <div class="container">
            <h1>🔍 Codebase Reviewer</h1>
            <p class="subtitle">AI-powered codebase analysis and onboarding tool</p>
        </div>
    </header>

    <div class="container">
        <div class="card">
            <h2 style="margin-bottom: 20px;">Analyze Repository</h2>

            <div class="info-box">
                <strong>Documentation-First Analysis:</strong> This tool analyzes project documentation before code,
                extracts testable claims, and validates them against actual implementation.
            </div>

            <form id="analyzeForm">
                <div class="form-group">
                    <label for="repoPath">Repository Path (absolute path)</label>
                    <input
                        type="text"
                        id="repoPath"
                        placeholder="/home/user/my-project"
                        value="{{ default_path }}"
                        required
                    >
                </div>

                <button type="submit" id="analyzeBtn">🚀 Analyze Repository</button>
            </form>

            <div class="progress" id="progress">
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <p class="status" id="status">Initializing...</p>
            </div>

            <div id="error" class="error" style="display: none;"></div>
        </div>

        <div class="results" id="results">
            <div class="card">
                <h2 style="margin-bottom: 20px;">Analysis Results</h2>

                <div id="metrics"></div>

                <div style="margin-top: 30px;">
                    <button class="download-btn" onclick="downloadPrompts('markdown')">
                        📄 Download Prompts (Markdown)
                    </button>
                    <button class="download-btn" onclick="downloadPrompts('json')">
                        📋 Download Prompts (JSON)
                    </button>
                    <button class="download-btn" onclick="downloadAnalysis()">
                        💾 Download Analysis (JSON)
                    </button>
                </div>

                <div id="prompts"></div>
            </div>
        </div>
    </div>

    <script>
        let currentAnalysis = null;

        document.getElementById('analyzeForm').addEventListener('submit', async (e) => {
            e.preventDefault();

            const repoPath = document.getElementById('repoPath').value.trim();
            const analyzeBtn = document.getElementById('analyzeBtn');
            const progress = document.getElementById('progress');
            const status = document.getElementById('status');
            const progressFill = document.getElementById('progressFill');
            const results = document.getElementById('results');
            const error = document.getElementById('error');

            // Reset UI
            results.style.display = 'none';
            error.style.display = 'none';
            progress.style.display = 'block';
            analyzeBtn.disabled = true;

            status.textContent = 'Starting analysis...';
            progressFill.style.width = '10%';

            try {
                const response = await fetch('/api/analyze', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ repo_path: repoPath })
                });

                if (!response.ok) {
                    throw new Error(await response.text());
                }

                const data = await response.json();
                currentAnalysis = data;

                progressFill.style.width = '100%';
                status.textContent = 'Analysis complete!';

                setTimeout(() => {
                    progress.style.display = 'none';
                    displayResults(data);
                }, 500);

            } catch (err) {
                progress.style.display = 'none';
                error.style.display = 'block';
                error.textContent = '❌ Error: ' + err.message;
            } finally {
                analyzeBtn.disabled = false;
            }
        });

        function displayResults(data) {
            const results = document.getElementById('results');
            const metrics = document.getElementById('metrics');
            const prompts = document.getElementById('prompts');

            // Display metrics
            metrics.innerHTML = `
                <div class="metric">
                    <span class="metric-label">Documentation Files</span>
                    <span class="metric-value">${data.documentation.total_docs}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Completeness</span>
                    <span class="metric-value">${data.documentation.completeness_score.toFixed(1)}%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Claims Extracted</span>
                    <span class="metric-value">${data.documentation.claims_count}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Quality Issues</span>
                    <span class="metric-value">${data.code.quality_issues_count}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Drift Severity</span>
                    <span class="metric-value">${data.validation.drift_severity.toUpperCase()}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Total Prompts</span>
                    <span class="metric-value">${data.prompts.total_count}</span>
                </div>
            `;

            // Display prompts by phase
            let promptsHTML = '<h3 style="margin-top: 30px; margin-bottom: 20px;">Generated AI Prompts</h3>';

            const phaseNames = {
                phase0: 'Documentation Review',
                phase1: 'Architecture Analysis',
                phase2: 'Implementation Deep-Dive',
                phase3: 'Development Workflow',
                phase4: 'Interactive Remediation'
            };

            for (const [phaseKey, phaseName] of Object.entries(phaseNames)) {
                const count = data.prompts.by_phase[phaseKey];
                if (count > 0) {
                    promptsHTML += `
                        <div class="phase-section">
                            <div class="phase-title">${phaseName} (${count} prompts)</div>
                            <p style="color: #666; margin-bottom: 15px;">
                                Click "Download Prompts" above to get detailed prompts for your AI assistant.
                            </p>
                        </div>
                    `;
                }
            }

            prompts.innerHTML = promptsHTML;
            results.style.display = 'block';
        }

        async function downloadPrompts(format) {
            if (!currentAnalysis) return;

            const response = await fetch(`/api/download-prompts?format=${format}&repo=${encodeURIComponent(currentAnalysis.repository_path)}`);
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `prompts.${format === 'markdown' ? 'md' : 'json'}`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
        }

        async function downloadAnalysis() {
            if (!currentAnalysis) return;

            const blob = new Blob([JSON.stringify(currentAnalysis, null, 2)], { type: 'application/json' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'analysis.json';
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
        }
    </script>
</body>
</html>
"""


@app.route("/")
def index():
    """Render main page."""
    # Default to current directory or user's home
    default_path = os.getcwd()
    return render_template_string(MAIN_TEMPLATE, default_path=default_path)


@app.route("/api/analyze", methods=["POST"])
def analyze():
    """Analyze a repository."""
    try:
        data = request.get_json()
        repo_path = data.get("repo_path")

        if not repo_path:
            return jsonify({"error": "repo_path is required"}), 400

        # Validate path exists
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
    import tempfile

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
