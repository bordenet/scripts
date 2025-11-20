# fetch-github-projects.sh

Updates all Git repositories in a directory with minimal output.

## Features

- **Interactive menu** - Select specific repositories to update
- **Batch mode** - Update all repositories automatically with `--all`
- **Recursive search** - Use `...` to search all subdirectories
- **Live timer** - Shows elapsed time in top-right corner
- **Minimal output** - Clean, inline status updates
- **Self-update check** - Verifies script is up-to-date before running

## Usage

### Interactive Mode (Default)

```bash
# Select from menu of repositories in ~/GitHub
./fetch-github-projects.sh

# Select from menu in custom directory
./fetch-github-projects.sh /path/to/repos
```

### Batch Mode

```bash
# Update all repos in ~/GitHub (searches 2 levels deep)
./fetch-github-projects.sh --all

# Update all repos in custom directory
./fetch-github-projects.sh --all /path/to/repos
```

### Recursive Mode

```bash
# Recursively update all repos in current directory
./fetch-github-projects.sh ... .

# Recursively update all repos in custom directory
./fetch-github-projects.sh /path/to/repos ...
```

## Options

| Option | Description |
|--------|-------------|
| `--all` | Skip menu and update all repositories (2 levels deep) |
| `...` | Recursive mode: search all subdirectories |
| `-h, --help` | Display help message |

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `DIRECTORY` | Target directory containing Git repositories | `~/GitHub` |

## Examples

```bash
# Interactive menu for ~/GitHub
./fetch-github-projects.sh

# Update all repos in ~/GitHub (2 levels deep)
./fetch-github-projects.sh --all

# Update all repos in ~/Projects (2 levels deep)
./fetch-github-projects.sh --all ~/Projects

# Recursively update everything under ~/Code
./fetch-github-projects.sh ~/Code ...

# Recursively update current directory
./fetch-github-projects.sh ... .
```

## Output

The script provides minimal, clean output:

```
Checking for script updates...
✓ Script is up to date

Scanning for repositories...
Found 15 repositories

▶ Updating repo1                    [✓]
▶ Updating repo2                    [✓]
▶ Updating repo3                    [↻ Already up to date]

Summary:
  Updated: 2
  Skipped: 1
  Failed: 0

Total time: 00:15
```

## Platform Support

Cross-platform: macOS, Linux, WSL

## See Also

- [git-pull(1)](https://git-scm.com/docs/git-pull)
- [git-fetch(1)](https://git-scm.com/docs/git-fetch)

