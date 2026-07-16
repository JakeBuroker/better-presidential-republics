param(
	[string]$ModPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$issues = New-Object System.Collections.Generic.List[object]

function Add-Issue {
	param(
		[string]$Kind,
		[string]$Path,
		[int]$Line,
		[string]$Message
	)
	$issues.Add([pscustomobject]@{
		Kind = $Kind
		Path = $Path
		Line = $Line
		Message = $Message
	})
}

function Get-DisplayPath {
	param([string]$Path)
	$base = (Resolve-Path $ModPath).Path.TrimEnd('\') + '\'
	$full = (Resolve-Path $Path).Path
	if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
		return $full.Substring($base.Length)
	}
	return $full
}

function Test-Utf8Bom {
	param([string]$Path)
	$bytes = [System.IO.File]::ReadAllBytes($Path)
	return $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
}

$resolvedModPath = (Resolve-Path $ModPath).Path
if (-not (Test-Path (Join-Path $resolvedModPath "descriptor.mod"))) {
	throw "ModPath does not look like a Victoria 3 mod root: $resolvedModPath"
}

$bomTargets = New-Object System.Collections.Generic.List[object]
foreach ($relativeDir in @("common", "events", "music", "localization", "gui")) {
	$dir = Join-Path $resolvedModPath $relativeDir
	if (-not (Test-Path $dir)) {
		continue
	}
	Get-ChildItem -LiteralPath $dir -Recurse -File |
		Where-Object { $_.Extension -in @(".txt", ".yml", ".gui") } |
		ForEach-Object { $bomTargets.Add($_) }
}

foreach ($file in $bomTargets) {
	if (-not (Test-Utf8Bom $file.FullName)) {
		Add-Issue "encoding" (Get-DisplayPath $file.FullName) 0 "Missing UTF-8 BOM."
	}
}

$scanFiles = Get-ChildItem -LiteralPath $resolvedModPath -Recurse -File |
	Where-Object { $_.Extension -in @(".txt", ".yml", ".gui") }

$literalPatterns = @(
	@{ Kind = "placeholder-name"; Pattern = "ruler_title_firstname"; Message = "Raw ruler/heir placeholder token is present." },
	@{ Kind = "bad-name-token"; Pattern = "first_name\s*=\s*É"; Message = "Accented first_name token should be ASCII key plus localization." },
	@{ Kind = "bad-name-token"; Pattern = "first_name\s*=\s*Sebastián"; Message = "Accented first_name token should be ASCII key plus localization." },
	@{ Kind = "bad-name-token"; Pattern = 'first_name\s*=\s*"Louis-Mathieu"'; Message = "Hyphenated quoted first name should be ASCII key plus localization." },
	@{ Kind = "bad-name-token"; Pattern = '(first_name|last_name)\s*=\s*"Molé"'; Message = "Accented quoted name should be ASCII key plus localization." },
	@{ Kind = "usage-syntax"; Pattern = "^\s*[A-Za-z0-9_]+_usage\s*=\s*\("; Message = "Usage block opens with '(' instead of '{'." },
	@{ Kind = "fake-template"; Pattern = "^\s*REPLACE_OR_CREATE:(commander_usage|interest_group_leader_usage)\s*="; Message = "Usage block was turned into a fake character template." }
)

foreach ($file in $scanFiles) {
	$lines = [System.IO.File]::ReadAllLines($file.FullName)
	for ($i = 0; $i -lt $lines.Count; $i++) {
		foreach ($patternInfo in $literalPatterns) {
			if ($lines[$i] -match $patternInfo.Pattern) {
				Add-Issue $patternInfo.Kind (Get-DisplayPath $file.FullName) ($i + 1) $patternInfo.Message
			}
		}
	}
}

$templateDir = Join-Path $resolvedModPath "common\character_templates"
if (Test-Path $templateDir) {
	$templateFiles = Get-ChildItem -LiteralPath $templateDir -Recurse -File -Filter "*.txt"
	foreach ($file in $templateFiles) {
		$depth = 0
		$lines = [System.IO.File]::ReadAllLines($file.FullName)
		for ($i = 0; $i -lt $lines.Count; $i++) {
			$line = $lines[$i]
			$trimmed = $line.Trim()
			if ($line -match "\bwiki_bio_record_default\b") {
				Add-Issue "default-bio-trait" (Get-DisplayPath $file.FullName) ($i + 1) "Generic default characters should not receive the fallback bio trait."
			}
			if ($depth -eq 0 -and $trimmed -match "^(start_date|end_date|activation|country|chance|template|role)\s*=") {
				Add-Issue "orphan-usage-key" (Get-DisplayPath $file.FullName) ($i + 1) "Usage-window key appears at top level, outside a usage block."
			}
			$opens = ([regex]::Matches($line, "\{")).Count
			$closes = ([regex]::Matches($line, "\}")).Count
			$depth += $opens - $closes
			if ($depth -lt 0) {
				Add-Issue "brace-balance" (Get-DisplayPath $file.FullName) ($i + 1) "Closing brace appears before a matching opening brace."
				$depth = 0
			}
		}
		if ($depth -ne 0) {
			Add-Issue "brace-balance" (Get-DisplayPath $file.FullName) $lines.Count "File ends with unbalanced braces."
		}
	}
}

if ($issues.Count -eq 0) {
	Write-Host "Validation passed for $resolvedModPath"
	exit 0
}

Write-Host "Validation found $($issues.Count) issue(s) in $resolvedModPath"
$issues |
	Sort-Object Kind, Path, Line |
	Select-Object -First 80 |
	ForEach-Object {
		$lineText = if ($_.Line -gt 0) { ":$($_.Line)" } else { "" }
		Write-Host "[$($_.Kind)] $($_.Path)$lineText - $($_.Message)"
	}

if ($issues.Count -gt 80) {
	Write-Host "...and $($issues.Count - 80) more."
}

exit 1
