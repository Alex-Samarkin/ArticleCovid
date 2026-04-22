<#
.SYNOPSIS
    Converts Markdown files to LaTeX with a fixed preamble for GOST-compatible documents.
.DESCRIPTION
    Takes .md files and produces .tex files with the specified LaTeX preamble.
    Requires Pandoc to be installed.
.PARAMETER InputFiles
    One or more paths to .md files.
.EXAMPLE
    .\md2tex.ps1 "lecture.md"
.EXAMPLE
    .\md2tex.ps1 "file1.md", "file2.md"
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$InputFiles
)

# Check if Pandoc is available
if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Error "Pandoc not found. Install from https://pandoc.org/installing.html"
    exit 1
}

# LaTeX preamble (exactly as requested)
$latexPreamble = @'
%% !TEX program = xelatex
\documentclass[12pt]{article}

% Cyrillic and font support
\usepackage{fontspec}
\usepackage[russian]{babel}
\usepackage{csquotes}

\usepackage{tabularx}
\usepackage[table]{xcolor}

% Bibliography (GOST style)
\usepackage[backend=biber, style=gost-numeric]{biblatex}
\addbibresource{references.bib}

% GOST-compliant font
\setmainfont{Times New Roman}

% Page margins
\usepackage[a4paper, margin=2.5cm]{geometry}

% Section formatting
\usepackage{titlesec}
\titleformat{\section}{\normalfont\bfseries\large}{\thesection}{1em}{}
\titlespacing*{\section}{0pt}{12pt}{6pt}

\title{Title of the Scientific Article}
\author{Samarkin A.I.\\
        \small Scientific Organization, City}
\date{}

\begin{document}
'@

$latexPostamble = @'
\printbibliography[title={References}]
\end{document}
'@

foreach ($mdFile in $InputFiles) {
    if (-not (Test-Path $mdFile)) {
        Write-Warning "File not found: $mdFile"
        continue
    }

    $fullPath = Resolve-Path $mdFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fullPath.Path)
    $dirName = [System.IO.Path]::GetDirectoryName($fullPath.Path)
    $texFile = Join-Path $dirName "$baseName.tex"

    Write-Host "Processing: $mdFile -> $texFile" -ForegroundColor Cyan

    $tempBody = "$env:TEMP\pandoc_body_$([System.IO.Path]::GetRandomFileName()).tex"

    # ... предыдущая часть скрипта без изменений ...

try {
    # Читаем исходный файл как UTF-8
    $content = Get-Content "$fullPath" -Raw -Encoding UTF8

    # Создаём временный файл с BOM
    $tempMd = "$env:TEMP\pandoc_input_$([System.IO.Path]::GetRandomFileName()).md"
    [System.IO.File]::WriteAllText($tempMd, $content, [System.Text.UTF8Encoding]::new($true))

    # Запускаем Pandoc БЕЗ --encoding
    pandoc "$tempMd" -f markdown -t latex -o "$tempBody" --wrap=none

    # Удаляем временный .md
    Remove-Item $tempMd -Force

    if (-not (Test-Path $tempBody)) {
        throw "Pandoc failed to create output"
    }

    $finalContent = $latexPreamble + "`n" + (Get-Content $tempBody -Raw) + "`n" + $latexPostamble
    Set-Content -Path $texFile -Value $finalContent -Encoding UTF8

    Write-Host "✅ Success: $texFile" -ForegroundColor Green
}
catch {
    Write-Error "Error processing $mdFile`: $_"
}
finally {
    if (Test-Path $tempBody) {
        Remove-Item $tempBody -Force
    }
}
}
