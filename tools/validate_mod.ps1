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

function Remove-InlineComment {
	param([string]$Line)
	$commentIndex = $Line.IndexOf("#")
	if ($commentIndex -ge 0) {
		return $Line.Substring(0, $commentIndex)
	}
	return $Line
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

$descriptorPath = Join-Path $resolvedModPath "descriptor.mod"
$descriptorText = [System.IO.File]::ReadAllText($descriptorPath)
foreach ($field in @("name", "version", "supported_version", "path")) {
	if ($descriptorText -notmatch "(?m)^\s*$field\s*=") {
		Add-Issue "descriptor" "descriptor.mod" 0 "Missing descriptor field '$field'."
	}
}
if ($descriptorText -match '(?m)^\s*version\s*=\s*"([^"]+)"') {
	$descriptorVersion = $matches[1]
	$changelogPath = Join-Path $resolvedModPath "CHANGELOG.md"
	if ((Test-Path $changelogPath) -and (([System.IO.File]::ReadAllText($changelogPath)) -notmatch "(?m)^##\s+$([regex]::Escape($descriptorVersion))\b")) {
		Add-Issue "version-docs" "CHANGELOG.md" 0 "CHANGELOG.md does not contain an entry for descriptor version $descriptorVersion."
	}
}

$literalPatterns = @(
	@{ Kind = "placeholder-name"; Pattern = "ruler_title_firstname"; Message = "Raw ruler/heir placeholder token is present." },
	@{ Kind = "debug-token"; Pattern = "\bcodex_"; Message = "Raw codex_ debug/personal namespace token is present." },
	@{ Kind = "debug-token"; Pattern = "\bTODO_DEBUG\b|\bTEMP_DEBUG\b"; Message = "Raw temporary debug token is present." },
	@{ Kind = "donor-mod-template"; Pattern = "\b(ecchi_|joi_)"; Message = "Standalone mod should not reference donor-mod character template namespaces." },
	@{ Kind = "bad-name-token"; Pattern = "first_name\s*=\s*É"; Message = "Accented first_name token should be ASCII key plus localization." },
	@{ Kind = "bad-name-token"; Pattern = "first_name\s*=\s*Sebastián"; Message = "Accented first_name token should be ASCII key plus localization." },
	@{ Kind = "bad-name-token"; Pattern = 'first_name\s*=\s*"Louis-Mathieu"'; Message = "Hyphenated quoted first name should be ASCII key plus localization." },
	@{ Kind = "bad-name-token"; Pattern = '(first_name|last_name)\s*=\s*"Molé"'; Message = "Accented quoted name should be ASCII key plus localization." },
	@{ Kind = "usage-syntax"; Pattern = "^\s*[A-Za-z0-9_]+_usage\s*=\s*\("; Message = "Usage block opens with '(' instead of '{'." },
	@{ Kind = "fake-template"; Pattern = "^\s*REPLACE_OR_CREATE:(commander_usage|interest_group_leader_usage)\s*="; Message = "Usage block was turned into a fake character template." }
)

foreach ($file in $scanFiles) {
	$lines = [System.IO.File]::ReadAllLines($file.FullName)
	$displayPath = Get-DisplayPath $file.FullName
	for ($i = 0; $i -lt $lines.Count; $i++) {
		foreach ($patternInfo in $literalPatterns) {
			if ($lines[$i] -match $patternInfo.Pattern) {
				Add-Issue $patternInfo.Kind $displayPath ($i + 1) $patternInfo.Message
			}
		}
		if ($displayPath -match '^(common|gui|localization)\\' -and $lines[$i] -match '(?i)\bpresident-elect\b') {
			Add-Issue "future-feature-text" $displayPath ($i + 1) "President-elect text is present in script, GUI, or localization, but delayed handoff is not implemented."
		}
		if ($displayPath -match '^(common|gui|localization)\\' -and $lines[$i] -match '\b(PLACEHOLDER|UNRESOLVED|FIXME)\b') {
			Add-Issue "placeholder-text" $displayPath ($i + 1) "Obvious unresolved placeholder text is present."
		}
		if ($displayPath -match '^common\\scripted_effects\\' -and $lines[$i] -match '\bhas_template\s*=\s*vptl_|\bTEMPLATE\s*=\s*vptl_') {
			Add-Issue "fallback-template-target" $displayPath ($i + 1) "Active scripted effects should not target BPR-owned character templates; use vanilla templates or generic eligibility."
		}
	}
}

$braceFiles = $scanFiles | Where-Object { $_.Extension -in @(".txt", ".gui") }
foreach ($file in $braceFiles) {
	$depth = 0
	$lines = [System.IO.File]::ReadAllLines($file.FullName)
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = Remove-InlineComment $lines[$i]
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

$localizationKeys = @{}
$localizationFiles = $scanFiles | Where-Object { $_.Extension -eq ".yml" }
foreach ($file in $localizationFiles) {
	$lines = [System.IO.File]::ReadAllLines($file.FullName)
	for ($i = 0; $i -lt $lines.Count; $i++) {
		if ($lines[$i] -match '^\s*([A-Za-z0-9_.-]+):\d+\s+') {
			$key = $matches[1]
			if ($localizationKeys.ContainsKey($key)) {
				$first = $localizationKeys[$key]
				Add-Issue "duplicate-localization" (Get-DisplayPath $file.FullName) ($i + 1) "Duplicate localization key '$key'; first seen at $($first.Path):$($first.Line)."
			}
			else {
				$localizationKeys[$key] = [pscustomobject]@{
					Path = Get-DisplayPath $file.FullName
					Line = $i + 1
				}
			}
		}
	}
}

function Test-LocalizedKey {
	param(
		[string]$Key,
		[string]$Kind,
		[string]$Path,
		[int]$Line
	)
	if (-not $localizationKeys.ContainsKey($Key)) {
		Add-Issue $Kind $Path $Line "Visible key '$Key' has no English localization."
	}
}

function Get-TopLevelDefinitions {
	param([string]$RelativeDir)
	$dir = Join-Path $resolvedModPath $RelativeDir
	if (-not (Test-Path $dir)) {
		return
	}
	Get-ChildItem -LiteralPath $dir -Recurse -File -Filter "*.txt" | ForEach-Object {
		$file = $_
		$depth = 0
		$lines = [System.IO.File]::ReadAllLines($file.FullName)
		for ($i = 0; $i -lt $lines.Count; $i++) {
			$line = Remove-InlineComment $lines[$i]
			if ($depth -eq 0 -and $line -match '^\s*([A-Za-z0-9_]+)\s*=\s*\{') {
				[pscustomobject]@{
					Name = $matches[1]
					Path = Get-DisplayPath $file.FullName
					Line = $i + 1
				}
			}
			$depth += ([regex]::Matches($line, "\{")).Count - ([regex]::Matches($line, "\}")).Count
			if ($depth -lt 0) {
				$depth = 0
			}
		}
	}
}

# Heuristic localization coverage for visible vptl_ assets. This intentionally avoids internal variables/effects.
foreach ($definition in Get-TopLevelDefinitions "common\character_traits") {
	if ($definition.Name -match '^vptl_') {
		Test-LocalizedKey $definition.Name "missing-localization" $definition.Path $definition.Line
		Test-LocalizedKey "$($definition.Name)_desc" "missing-localization" $definition.Path $definition.Line
	}
}
foreach ($definition in Get-TopLevelDefinitions "common\static_modifiers") {
	if ($definition.Name -match '^modifier_vptl_') {
		Test-LocalizedKey $definition.Name "missing-localization" $definition.Path $definition.Line
		Test-LocalizedKey "$($definition.Name)_desc" "missing-localization" $definition.Path $definition.Line
	}
}
foreach ($definition in Get-TopLevelDefinitions "common\character_roles") {
	if ($definition.Name -match '^character_role_vptl_') {
		Test-LocalizedKey $definition.Name "missing-localization" $definition.Path $definition.Line
		Test-LocalizedKey "$($definition.Name)_title" "missing-localization" $definition.Path $definition.Line
	}
}
foreach ($definition in Get-TopLevelDefinitions "common\messages") {
	if ($definition.Name -match '^vptl_') {
		Test-LocalizedKey "notification_$($definition.Name)_name" "missing-localization" $definition.Path $definition.Line
		Test-LocalizedKey "notification_$($definition.Name)_desc" "missing-localization" $definition.Path $definition.Line
	}
}
foreach ($file in $scanFiles | Where-Object { (Get-DisplayPath $_.FullName) -match '^(common\\customizable_localization|gui)\\' }) {
	$displayPath = Get-DisplayPath $file.FullName
	$lines = [System.IO.File]::ReadAllLines($file.FullName)
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = Remove-InlineComment $lines[$i]
		foreach ($match in [regex]::Matches($line, '(?:localization_key|text|tooltip)\s*=\s*"?((?:vptl|character_role_vptl)_[A-Za-z0-9_]+)"?')) {
			Test-LocalizedKey $match.Groups[1].Value "missing-localization" $displayPath ($i + 1)
		}
	}
}

$scriptedDefinitionDirs = @("common\scripted_effects", "common\scripted_triggers", "common\customizable_localization")
foreach ($relativeDir in $scriptedDefinitionDirs) {
	$dir = Join-Path $resolvedModPath $relativeDir
	if (-not (Test-Path $dir)) {
		continue
	}
	$definitions = @{}
	Get-ChildItem -LiteralPath $dir -Recurse -File -Filter "*.txt" | ForEach-Object {
		$file = $_
		$depth = 0
		$lines = [System.IO.File]::ReadAllLines($file.FullName)
		for ($i = 0; $i -lt $lines.Count; $i++) {
			$line = Remove-InlineComment $lines[$i]
			if ($depth -eq 0 -and $line -match '^\s*([A-Za-z0-9_]+)\s*=\s*\{') {
				$name = $matches[1]
				if ($name -notmatch '^(vptl_|character_role_vptl_)') {
					Add-Issue "namespace" (Get-DisplayPath $file.FullName) ($i + 1) "Top-level scripted identifier '$name' should use the vptl_ prefix."
				}
				if ($definitions.ContainsKey($name)) {
					$first = $definitions[$name]
					Add-Issue "duplicate-scripted-identifier" (Get-DisplayPath $file.FullName) ($i + 1) "Duplicate top-level scripted identifier '$name'; first seen at $($first.Path):$($first.Line)."
				}
				else {
					$definitions[$name] = [pscustomobject]@{
						Path = Get-DisplayPath $file.FullName
						Line = $i + 1
					}
				}
			}
			$depth += ([regex]::Matches($line, "\{")).Count - ([regex]::Matches($line, "\}")).Count
			if ($depth -lt 0) {
				$depth = 0
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
