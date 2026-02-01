#!/usr/bin/env bash
# slop-detection-lib.sh - AI slop detection for README files
# Detects patterns that indicate low-quality AI-generated content
# Returns bullshit factor score (0-100)

# Lexical patterns - generic boosters and buzzwords
readonly SLOP_BOOSTERS='incredibly|extremely|highly|very|truly|remarkably|absolutely|undoubtedly'
readonly SLOP_BUZZWORDS='robust|seamless|comprehensive|elegant|powerful|innovative|cutting-edge|state-of-the-art|world-class|game-changing|transformative|revolutionize|leverage|synergy|holistic|paradigm'
readonly SLOP_FILLER="it's important to note|let's dive in|at the end of the day|without further ado|in order to|for all intents and purposes|needless to say|that being said"
readonly SLOP_HEDGE='obviously|clearly|generally speaking|potentially|arguably|essentially'
readonly SLOP_SYCOPHANT='great question|excellent question|happy to help|absolutely|certainly'
readonly SLOP_TRANSITION='furthermore|moreover|additionally|nevertheless|consequently'

# Structural patterns
readonly SLOP_STRUCTURAL='key benefits|in conclusion|to summarize|in summary|the following|as follows|here is|here are'

# Calculate bullshit factor for a file (0-100)
# Usage: calculate_bullshit_factor <file_path>
calculate_bullshit_factor() {
    local file_path="$1"
    local content
    local score=0
    local pattern_count=0
    
    if [[ ! -f "$file_path" ]]; then
        echo "0"
        return
    fi
    
    content=$(tr '[:upper:]' '[:lower:]' < "$file_path")
    
    # Count lexical patterns (40 points max)
    local booster_count structural_count
    booster_count=$(echo "$content" | grep -oEi "$SLOP_BOOSTERS|$SLOP_BUZZWORDS|$SLOP_FILLER|$SLOP_HEDGE|$SLOP_SYCOPHANT|$SLOP_TRANSITION" | wc -l | tr -d ' ')
    booster_count=${booster_count:-0}
    pattern_count=$((booster_count))
    
    # 2 points per pattern, capped at 40
    local lexical_score=$((pattern_count * 2))
    [[ $lexical_score -gt 40 ]] && lexical_score=40
    score=$((score + lexical_score))
    
    # Count structural patterns (25 points max)
    structural_count=$(echo "$content" | grep -oEi "$SLOP_STRUCTURAL" | wc -l | tr -d ' ')
    structural_count=${structural_count:-0}
    local structural_score=$((structural_count * 5))
    [[ $structural_score -gt 25 ]] && structural_score=25
    score=$((score + structural_score))
    
    # Check for symmetric coverage (20 points max)
    # Repetitive section lengths suggest AI generation
    local line_count
    line_count=$(wc -l < "$file_path")
    if [[ $line_count -gt 100 ]]; then
        # Check for "deep understanding" and "mastery" patterns
        local mastery_count
        mastery_count=$(echo "$content" | grep -oEi 'deep understanding|mastery|transform|empower' | wc -l | tr -d ' ')
        mastery_count=${mastery_count:-0}
        local semantic_score=$((mastery_count * 5))
        [[ $semantic_score -gt 20 ]] && semantic_score=20
        score=$((score + semantic_score))
    fi
    
    # Check stylometric flags (15 points max)
    # All paragraphs starting with "This" or "The" (3 points each, max 15)
    local para_starts=0
    para_starts=$(grep -c "^[#]*[ ]*\(This\|The\) " "$file_path" 2>/dev/null) || para_starts=0
    para_starts=$(printf '%d' "$para_starts" 2>/dev/null) || para_starts=0
    local style_score=$((para_starts * 5))
    [[ $style_score -gt 15 ]] && style_score=15
    score=$((score + style_score))
    
    echo "$score"
}

# Get verdict for a score
# Usage: get_verdict <score>
get_verdict() {
    local score="$1"
    if [[ $score -le 20 ]]; then
        echo "CLEAN"
    elif [[ $score -le 40 ]]; then
        echo "LIGHT"
    elif [[ $score -le 60 ]]; then
        echo "MODERATE"
    elif [[ $score -le 80 ]]; then
        echo "HEAVY"
    else
        echo "SEVERE"
    fi
}

# Check if score passes threshold
# Usage: score_passes <score> <threshold>
score_passes() {
    local score="$1"
    local threshold="${2:-40}"
    [[ $score -le $threshold ]]
}

# Get detailed breakdown of patterns found
# Usage: get_pattern_details <file_path>
get_pattern_details() {
    local file_path="$1"
    local content
    
    content=$(tr '[:upper:]' '[:lower:]' < "$file_path")
    
    echo "=== Pattern Details ==="
    echo "Boosters/Buzzwords:"
    echo "$content" | grep -oEi "$SLOP_BOOSTERS|$SLOP_BUZZWORDS" | sort | uniq -c | sort -rn | head -5
    echo ""
    echo "Filler phrases:"
    echo "$content" | grep -oEi "$SLOP_FILLER" | sort | uniq -c | sort -rn | head -5
    echo ""
    echo "Structural patterns:"
    echo "$content" | grep -oEi "$SLOP_STRUCTURAL" | sort | uniq -c | sort -rn | head -5
}

