# Repo-Documenter

Repo-Documenter is a PowerShell script that generates comprehensive documentation for a repository, including a tree view of the repository structure and the contents of specified files.

## Features

- Generates a tree view of the repository structure
- Aggregates content from specified files
- Outputs a single Markdown file containing the repository documentation
- Configurable via a simple configuration file

## Prerequisites

- PowerShell 5.1 or later

## Installation

1. Clone this repository or download the `Repo-Documenter.ps1` script.
2. Ensure that PowerShell execution policy allows running scripts.

## Usage

1. Create a `repo_documenter.config` file in the root of the repository you want to document.
2. Add patterns to the `repo_documenter.config` file to specify which files and directories to include.
3. Run the script with the following command:

```powershell
.\Repo-Documenter.ps1 -RepoPath <path_to_your_repository> [-OutputFile <output_file_name>]
```

If no output file is specified, the script will create a Markdown file named after the repository in the current directory.

## Configuration

Create a `repo_documenter.config` file in the root of your repository. Each line in this file should contain a pattern for files or directories to include. For example:

```
*.md
src/*
docs/*.txt
```

This configuration will include all Markdown files, everything in the `src` directory, and all text files in the `docs` directory.

## Output

The script generates a Markdown file containing:

1. A tree view of the repository structure (based on the configuration)
2. The contents of all included files

## License

[MIT License](LICENSE)