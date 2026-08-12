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
	@{ Kind = "fake-template"; Pattern = "^\s*REPLACE_OR_CREATE:(commander_usage|interest_group_leader_usage)\s*="; Message = "Usage block was turned into a fake character template." },
	@{ Kind = "unknown-effect"; Pattern = "^\s*send_message\s*="; Message = "Victoria 3 does not support the send_message effect; use post_notification." }
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
foreach ($definition in Get-TopLevelDefinitions "common\journal_entries") {
	if ($definition.Name -match '^je_vptl_') {
		Test-LocalizedKey $definition.Name "missing-localization" $definition.Path $definition.Line
		Test-LocalizedKey "$($definition.Name)_reason" "missing-localization" $definition.Path $definition.Line
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

function Get-TopLevelBlockText {
	param(
		[string]$Path,
		[string]$Name
	)
	$lines = [System.IO.File]::ReadAllLines($Path)
	$capturing = $false
	$depth = 0
	$captured = New-Object System.Collections.Generic.List[string]
	foreach ($line in $lines) {
		$scriptLine = Remove-InlineComment $line
		if (-not $capturing -and $scriptLine -match "^\s*$([regex]::Escape($Name))\s*=\s*\{") {
			$capturing = $true
		}
		if ($capturing) {
			$captured.Add($line)
			$depth += ([regex]::Matches($scriptLine, "\{")).Count - ([regex]::Matches($scriptLine, "\}")).Count
			if ($depth -eq 0) {
				break
			}
		}
	}
	return ($captured -join "`n")
}

$presidentialEffectsPath = Join-Path $resolvedModPath "common\scripted_effects\zzz_vptl_term_limits.txt"
$presidentialOnActionsPath = Join-Path $resolvedModPath "common\on_actions\zzz_vptl_term_limits.txt"
if ((Test-Path $presidentialEffectsPath) -and (Test-Path $presidentialOnActionsPath)) {
	$settlementBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_settle_presidential_election"
	if ([string]::IsNullOrWhiteSpace($settlementBlock)) {
		Add-Issue "election-settlement" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Missing the bounded presidential election settlement effect."
	}
	else {
		if ($settlementBlock -match '\bvptl_post_presidential_transition_notification\s*=') {
			Add-Issue "election-notification" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Normal election settlement must not post the BPR transition notification."
		}
		$certifyIndex = $settlementBlock.IndexOf("vptl_certify_presidential_election = yes")
		$clearIndex = $settlementBlock.IndexOf("remove_variable = vptl_presidential_ticket_candidate")
		if ($certifyIndex -lt 0 -or $clearIndex -lt 0 -or $clearIndex -lt $certifyIndex) {
			Add-Issue "election-settlement-order" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Campaign ticket variables must be cleared only after the final ticket is certified."
		}
		if ($settlementBlock -match '\b(vptl_record_presidential_term_for_current_ruler|vptl_record_vice_presidential_term_for_current_successor|set_character_as_ruler)\s*=') {
			Add-Issue "election-certification-only" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Election settlement must certify the ticket without installing it or recording terms."
		}
	}

	$certificationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_certify_presidential_election"
	$inaugurationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_inaugurate_president_elect"
	$schedulingBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_schedule_presidential_inauguration"
	$cleanupBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_clear_presidential_transition_variables"
	$cleanupWrapperBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_cleanup_presidential_inauguration_transition"
	$journalBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_ensure_presidential_transition_journal"
	$maintenanceBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_maintain_presidential_inauguration_transition"
	foreach ($required in @('vptl_president_elect', 'vptl_presidential_inauguration_pending', 'vptl_presidential_certification_complete', 'vptl_schedule_presidential_inauguration', 'vptl_finish_presidential_election_ruler_notification_suppression')) {
		if ($certificationBlock -notmatch "\b$([regex]::Escape($required))\b") {
			Add-Issue "election-certification" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Certification is missing required state or routing '$required'."
		}
	}
	if ($certificationBlock -match '\b(vptl_record_presidential_term_for_current_ruler|vptl_record_vice_presidential_term_for_current_successor|set_character_as_ruler)\s*=') {
		Add-Issue "election-certification-only" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Certification must not install the winner or record elected service."
	}
	foreach ($guard in @('vptl_presidential_inauguration_pending', 'vptl_presidential_inauguration_is_due', 'vptl_presidential_inauguration_in_progress', 'vptl_presidential_inauguration_completed')) {
		if ($inaugurationBlock -notmatch "\b$([regex]::Escape($guard))\b") {
			Add-Issue "inauguration-guard" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Inauguration is missing guard '$guard'."
		}
	}
	$allEffectText = [System.IO.File]::ReadAllText($presidentialEffectsPath)
	foreach ($termEffect in @('vptl_record_presidential_term_for_current_ruler', 'vptl_record_vice_presidential_term_for_current_successor')) {
		if (([regex]::Matches($inaugurationBlock, "\b$termEffect\s*=\s*yes")).Count -ne 1) {
			Add-Issue "inauguration-term-recording" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Inauguration must call '$termEffect' exactly once."
		}
		if (([regex]::Matches($allEffectText, "(?m)^\s+$termEffect\s*=\s*yes\s*$")).Count -ne 1) {
			Add-Issue "inauguration-term-recording" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "'$termEffect' must have inauguration as its sole call site."
		}
	}
	if ($schedulingBlock -notmatch '(?s)else\s*=\s*\{.*set_variable\s*=\s*vptl_presidential_inauguration_due.*vptl_inaugurate_president_elect\s*=\s*yes') {
		Add-Issue "instant-inauguration" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Rule 0 must mark the pending inauguration due and invoke the common inauguration effect synchronously."
	}
	if ($schedulingBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_inauguration_schedule_initialized\s*\}' -or
		$schedulingBlock -notmatch 'set_variable\s*=\s*vptl_presidential_inauguration_schedule_initialized' -or
		$schedulingBlock -notmatch 'vptl_presidential_inauguration_journal_generation\s+value\s*=\s*1' -or
		$schedulingBlock -notmatch 'vptl_presidential_inauguration_journal_generation\s+value\s*=\s*2' -or
		$schedulingBlock -notmatch 'set_variable\s*=\s*vptl_presidential_inauguration_journal_generation_assigned') {
		Add-Issue "inauguration-journal-generation" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Scheduling must be latched and assign exactly one alternating journal generation for a fresh delayed transition."
	}
	if ($maintenanceBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_inauguration_schedule_initialized\s*\}' -or
		$maintenanceBlock -notmatch 'set_variable\s*=\s*vptl_presidential_inauguration_legacy_transition' -or
		$maintenanceBlock -notmatch 'vptl_presidential_inauguration_journal_generation\s+value\s*=\s*1') {
		Add-Issue "inauguration-legacy-migration" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Maintenance must adopt an existing pending transition without resetting its authoritative timer."
	}
	if ($maintenanceBlock -match 'vptl_presidential_inauguration_timer\s+days\s*=|remove_variable\s*=\s*vptl_presidential_inauguration_timer') {
		Add-Issue "inauguration-timer-reset" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Maintenance must never reset or remove an existing pending inauguration timer."
	}
	foreach ($state in @('vptl_president_elect', 'vptl_vice_president_elect', 'vptl_presidential_inauguration_pending', 'vptl_presidential_inauguration_timer', 'vptl_presidential_inauguration_due', 'vptl_presidential_inauguration_completed', 'vptl_presidential_certification_complete', 'vptl_presidential_transition_outgoing_ruler', 'vptl_presidential_transition_winning_party', 'vptl_presidential_transition_winning_ig', 'vptl_presidential_transition_losing_candidate', 'vptl_presidential_transition_losing_running_mate', 'vptl_presidential_transition_incumbent_reelected', 'vptl_presidential_transition_lame_duck', 'vptl_presidential_inauguration_in_progress', 'vptl_presidential_transition_unusual_notification_posted', 'vptl_presidential_final_elected_ruler', 'vptl_presidential_final_running_mate', 'vptl_presidential_winning_ticket_side', 'vptl_presidential_inauguration_schedule_initialized', 'vptl_presidential_inauguration_journal_generation_assigned', 'vptl_presidential_inauguration_journal_created', 'vptl_presidential_inauguration_legacy_transition', 'vptl_presidential_pending_death_handling')) {
		if ($cleanupBlock -notmatch "remove_variable\s*=\s*$([regex]::Escape($state))") {
			Add-Issue "inauguration-cleanup" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition cleanup does not remove '$state'."
		}
	}
	if ($cleanupBlock -match 'remove_variable\s*=\s*vptl_presidential_inauguration_journal_generation(?:\s|$)') {
		Add-Issue "inauguration-journal-generation" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Cleanup must preserve the persistent journal generation so the next transition alternates."
	}
	foreach ($cleanupAction in @('remove_modifier\s*=\s*modifier_vptl_lame_duck_administration', 'vptl_refresh_presidential_elect_roles\s*=\s*yes', 'vptl_finish_presidential_election_ruler_notification_suppression\s*=\s*yes')) {
		if ($cleanupWrapperBlock -notmatch $cleanupAction) {
			Add-Issue "inauguration-cleanup" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition cleanup is missing a required role, modifier, or suppression cleanup action."
		}
	}
	foreach ($days in @(30, 60, 90, 120)) {
		foreach ($generation in @('a', 'b')) {
			$entryName = "je_vptl_presidential_transition_$($days)_$generation"
			if (([regex]::Matches($journalBlock, "add_journal_entry\s*=\s*\{\s*type\s*=\s*$entryName\s*\}")).Count -ne 1) {
				Add-Issue "inauguration-journal-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "The $days-day generation $generation configuration must schedule exactly one matching journal variant."
			}
		}
		if ($journalBlock -match "add_journal_entry\s*=\s*\{\s*type\s*=\s*je_vptl_presidential_transition_$days\s*\}") {
			Add-Issue "inauguration-journal-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Fresh transitions must not schedule the legacy $days-day journal."
		}
	}

	$effectLines = [System.IO.File]::ReadAllLines($presidentialEffectsPath)
	for ($i = 0; $i -lt $effectLines.Count; $i++) {
		if ($effectLines[$i] -match '\bvar:vptl_presidential_winning_ticket_side\s*=') {
			$windowStart = [Math]::Max(0, $i - 4)
			$guardWindow = ($effectLines[$windowStart..$i] -join "`n")
			if ($guardWindow -notmatch 'has_variable\s*=\s*vptl_presidential_winning_ticket_side') {
				Add-Issue "winning-side-guard" "common\scripted_effects\zzz_vptl_term_limits.txt" ($i + 1) "Winning-ticket-side comparisons must be guarded when ambiguous settlement leaves the variable unset."
			}
		}
	}
	$onActionText = [System.IO.File]::ReadAllText($presidentialOnActionsPath)
	$electionEndBlock = Get-TopLevelBlockText $presidentialOnActionsPath "vptl_presidential_term_limits_election_end"
	$campaignPreparationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_prepare_presidential_term_limits_for_campaign"
	if ($campaignPreparationBlock -notmatch '\bvptl_begin_presidential_election_ruler_notification_suppression\s*=\s*yes') {
		Add-Issue "election-notification" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Campaign preparation must suppress vanilla's temporary election-ruler notification before election resolution."
	}
	$actualRulerCaptureIndex = $campaignPreparationBlock.IndexOf("set_variable = { name = vptl_presidential_transition_outgoing_ruler value = ruler }")
	$trackedRulerCaptureIndex = $campaignPreparationBlock.IndexOf("set_variable = { name = vptl_presidential_transition_outgoing_ruler value = var:vptl_presidential_current_ruler }")
	$syncRulerIndex = $campaignPreparationBlock.IndexOf("vptl_sync_presidential_current_ruler = yes")
	if ($actualRulerCaptureIndex -lt 0 -or $trackedRulerCaptureIndex -lt 0 -or
		$actualRulerCaptureIndex -gt $trackedRulerCaptureIndex -or
		$syncRulerIndex -lt 0 -or $syncRulerIndex -gt $actualRulerCaptureIndex) {
		Add-Issue "campaign-outgoing-ruler" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Campaign preparation must synchronize and capture the actual living ruler before using the tracked-ruler fallback."
	}
	if ($electionEndBlock -notmatch '\bvptl_settle_presidential_election\s*=\s*yes') {
		Add-Issue "election-settlement" "common\on_actions\zzz_vptl_term_limits.txt" 0 "Election end must enter the single settlement effect."
	}
	if ($electionEndBlock -match '\bvptl_post_presidential_transition_notification\s*=') {
		Add-Issue "election-notification" "common\on_actions\zzz_vptl_term_limits.txt" 0 "Election end must not post a separate BPR transition notification."
	}

	$initializationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_initialize_presidential_term_limits"
	if ($initializationBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_initial_term_seeded\s*\}' -or
		$initializationBlock -notmatch 'set_variable\s*=\s*\{\s*name\s*=\s*vptl_presidential_terms_served\s+value\s*=\s*1\s*\}') {
		Add-Issue "initial-term-seed" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Initial presidential term credit must be guarded and seed one term without repeated increments."
	}
	if ($initializationBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_initial_successor_term_seeded\s*\}' -or
		$initializationBlock -notmatch 'set_variable\s*=\s*vptl_presidential_initial_successor_term_seeded') {
		Add-Issue "initial-successor-seed" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Initial successor term credit must use a country guard that is set only after a valid successor exists."
	}
}

$presidentialTriggersPath = Join-Path $resolvedModPath "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt"
$presidentialGuiPath = Join-Path $resolvedModPath "common\scripted_guis\zzz_vptl_term_limits.txt"
$electionPanelGuiPath = Join-Path $resolvedModPath "gui\election_panel.gui"
if ((Test-Path $presidentialTriggersPath) -and (Test-Path $presidentialGuiPath) -and (Test-Path $presidentialEffectsPath)) {
	$candidateEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_candidate_eligible"
	$newSuccessorEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_new_successor_candidate_eligible"
	$existingCampaignRunningMateEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_existing_campaign_running_mate_eligible"
	$partyExistingRunningMateEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_party_existing_running_mate_eligible"
	$certifiedRunningMateEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_certified_running_mate_eligible"
	$certifiedOutgoingVicePresidentElectEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_certified_outgoing_vice_president_elect_eligible"
	$sittingSuccessorEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_sitting_successor_handoff_eligible"
	$ticketValidationBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_campaign_ticket_valid"
	$partyTicketGuiBlock = Get-TopLevelBlockText $presidentialGuiPath "vptl_show_presidential_party_ticket_sgui"
	$partyCandidateGuiBlock = Get-TopLevelBlockText $presidentialGuiPath "vptl_show_presidential_party_ticket_candidate_sgui"
	$partyRunningMateGuiBlock = Get-TopLevelBlockText $presidentialGuiPath "vptl_show_presidential_party_ticket_running_mate_sgui"
	$replacementPresidentBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_transition_replacement_candidate_eligible"
	$replacementVicePresidentBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_transition_replacement_running_mate_eligible"
	$transitionSuccessorBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_transition_sitting_successor_replacement_eligible"
	$winningSideIdentificationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_identify_presidential_winning_ticket_side"
	$finalRunningMateSelectionBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_select_final_running_mate_from_winning_ticket"
	$replacementVicePresidentSelectionBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_select_transition_replacement_vice_president_elect"
	$electTicketRepairBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_repair_presidential_elect_ticket"
	$ticketPruneBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_prune_invalid_presidential_campaign_ticket_slots"
	$ticketUpdateBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_update_presidential_ticket_candidates"
	$partyTicketMaintenanceBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_maintain_presidential_party_ticket"
	$partyRegistryBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_refresh_presidential_campaign_party_registry"
	$partyTicketCleanupBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_clear_presidential_campaign_party_tickets"
	$losingTicketMarkerBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_mark_losing_presidential_party_tickets"
	$campaignRepairBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_repair_presidential_campaign_ticket_if_needed"
	$legacyMigrationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_migrate_legacy_presidential_campaign_tickets"
	$inaugurationInstallBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_inaugurate_president_elect"
	$electionPanelGuiText = if (Test-Path $electionPanelGuiPath) { [System.IO.File]::ReadAllText($electionPanelGuiPath) } else { '' }

	if ([string]::IsNullOrWhiteSpace($candidateEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($newSuccessorEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($existingCampaignRunningMateEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($partyExistingRunningMateEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($certifiedRunningMateEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($certifiedOutgoingVicePresidentElectEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($sittingSuccessorEligibilityBlock)) {
		Add-Issue "eligibility-layers" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Separate presidential-candidate, new-successor, legacy and party saved-running-mate, certified-running-mate, outgoing-VP-elect, and sitting-successor eligibility triggers are required."
	}
	if ($candidateEligibilityBlock -match 'vptl_vice_presidential_terms_served|character_role_vptl_former_president') {
		Add-Issue "presidential-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Presidential candidates must not be blocked by successor-term count or former-president history."
	}
	if ($newSuccessorEligibilityBlock -notmatch 'vptl_vice_presidential_terms_served' -or
		$newSuccessorEligibilityBlock -notmatch 'character_role_vptl_former_president') {
		Add-Issue "successor-selection-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "New successor selection must cap recorded successor terms and block former presidents."
	}
	foreach ($required in @(
		'vptl_presidential_new_successor_candidate_eligible',
		'is_ruler_of_own_country\s*=\s*yes',
		'vptl_presidential_election_transition',
		'vptl_presidential_death_succession_lock',
		'owner\.var:vptl_presidential_death_successor\s*\?=\s*this',
		'owner\.var:vptl_presidential_ticket_running_mate\s*\?=\s*this',
		'owner\.var:vptl_presidential_opposition_running_mate\s*\?=\s*this',
		'character_role_vptl_former_president',
		'vptl_vice_presidential_terms_served'
	)) {
		if ($existingCampaignRunningMateEligibilityBlock -notmatch $required) {
			Add-Issue "campaign-running-mate-ruler" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "An existing campaign running mate may remain ruler only through the recorded campaign death-succession exception."
			break
		}
	}
	foreach ($required in @(
		'vptl_presidential_basic_eligibility',
		'is_character_alive',
		'has_role_of_type\s*=\s*politician',
		'is_heir_of_own_country\s*=\s*no',
		'character_role_vptl_former_president',
		'vptl_vice_presidential_terms_served',
		'owner\.var:vptl_presidential_final_elected_ruler',
		'owner\.var:vptl_president_elect'
	)) {
		if ($certifiedRunningMateEligibilityBlock -notmatch $required) {
			Add-Issue "certified-running-mate-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Certified running mates must retain every substantive successor eligibility restriction."
			break
		}
	}
	if ($certifiedRunningMateEligibilityBlock -notmatch 'is_ruler_of_own_country\s*=\s*no' -or
		$certifiedRunningMateEligibilityBlock -notmatch 'is_ruler_of_own_country\s*=\s*yes' -or
		$certifiedRunningMateEligibilityBlock -notmatch 'vptl_presidential_election_settlement_in_progress' -or
		$certifiedRunningMateEligibilityBlock -notmatch 'owner\.var:vptl_presidential_vanilla_selected_ruler\s*\?=\s*this') {
		Add-Issue "certified-running-mate-temporary-ruler" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "The temporary-ruler exception must require active settlement and equality with the vanilla-selected ruler."
	}
	if ($certifiedRunningMateEligibilityBlock -notmatch 'vptl_presidential_death_succession_lock' -or
		$certifiedRunningMateEligibilityBlock -notmatch 'owner\.var:vptl_presidential_death_successor\s*\?=\s*this' -or
		$certifiedRunningMateEligibilityBlock -notmatch 'owner\.var:vptl_presidential_winning_ticket_party' -or
		$certifiedRunningMateEligibilityBlock -notmatch 'vptl_presidential_party_ticket_running_mate') {
		Add-Issue "certified-running-mate-death-successor" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Certification must retain the winning party's exact saved running mate after recorded campaign death succession."
	}
	if (([regex]::Matches($finalRunningMateSelectionBlock, '\bvptl_presidential_certified_running_mate_eligible\s*=\s*yes')).Count -ne 1) {
		Add-Issue "certified-running-mate-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "The authoritative party-owned running mate must use certified-running-mate eligibility exactly once."
	}
	if (([regex]::Matches($finalRunningMateSelectionBlock, '\bvptl_presidential_new_successor_candidate_eligible\s*=\s*yes')).Count -ne 2) {
		Add-Issue "certified-running-mate-fallback" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Party fallback searches must retain normal new-successor eligibility."
	}
	$directCandidateIndex = $winningSideIdentificationBlock.IndexOf('vptl_presidential_party_ticket_candidate')
	$deathSuccessorIndex = $winningSideIdentificationBlock.IndexOf('vptl_presidential_death_succession_lock')
	$partyFallbackIndex = $winningSideIdentificationBlock.IndexOf('vptl_presidential_vanilla_selected_party')
	$igFallbackIndex = $winningSideIdentificationBlock.IndexOf('vptl_presidential_vanilla_selected_ig')
	if ($directCandidateIndex -lt 0 -or $deathSuccessorIndex -lt 0 -or $partyFallbackIndex -lt 0 -or $igFallbackIndex -lt 0 -or
		$deathSuccessorIndex -le $directCandidateIndex -or $deathSuccessorIndex -ge $partyFallbackIndex -or $partyFallbackIndex -ge $igFallbackIndex -or
		$winningSideIdentificationBlock -notmatch 'vptl_presidential_party_ticket_running_mate' -or
		$winningSideIdentificationBlock -notmatch 'owner\.var:vptl_presidential_death_successor\s*\?=\s*this') {
		Add-Issue "multi-party-winner-order" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Winner identification must check exact party candidate, exact death-successor running mate, party, and unique IG in that order."
	}
	if ($sittingSuccessorEligibilityBlock -match 'vptl_vice_presidential_terms_served|character_role_vptl_former_president') {
		Add-Issue "successor-handoff-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Sitting successor handoff must not apply new-term or former-president selection restrictions."
	}
	foreach ($block in @($partyRunningMateGuiBlock, $partyTicketMaintenanceBlock)) {
		if ($block -notmatch '\bvptl_presidential_party_existing_running_mate_eligible\s*=\s*yes') {
			Add-Issue "running-mate-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Party-ticket maintenance and GUI visibility must preserve only an eligible existing running mate."
			break
		}
	}
	if ($ticketUpdateBlock -match '\bvptl_presidential_existing_campaign_running_mate_eligible\s*=\s*yes') {
		Add-Issue "campaign-running-mate-selection" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "The saved-running-mate exception must never be used to select a new running mate."
	}
	if ($partyTicketMaintenanceBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_party_ticket_candidate\s*\}' -or
		$partyTicketMaintenanceBlock -notmatch 'is_member_of_party\s*=\s*scope:vptl_presidential_campaign_party') {
		Add-Issue "campaign-ticket-head-preservation" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "A party nominee must remain stable and be replaced only when its slot is vacant or party membership is lost."
	}
	foreach ($required in @('every_active_party', 'vptl_presidential_campaign_parties', 'vptl_presidential_party_ticket_generation_current', 'add_to_variable_list')) {
		if ($partyRegistryBlock -notmatch $required) {
			Add-Issue "multi-party-registry" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Campaign maintenance must register every active party and enforce the current ticket generation."
			break
		}
	}
	foreach ($required in @('vptl_presidential_party_ticket_system_active', 'vptl_presidential_campaign_ticket_generation\s+value\s*=\s*1', 'vptl_presidential_campaign_ticket_generation\s+value\s*=\s*2', 'vptl_migrate_legacy_presidential_campaign_tickets', 'every_in_list', 'vptl_maintain_presidential_party_ticket')) {
		if ($ticketUpdateBlock -notmatch $required) {
			Add-Issue "multi-party-generation" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Party tickets must initialize once per campaign, alternate generation, migrate legacy slots, and maintain every registered party."
			break
		}
	}
	if ($campaignRepairBlock -match 'NOT\s*=\s*\{\s*vptl_presidential_campaign_ticket_valid' -or
		$campaignRepairBlock -notmatch 'vptl_update_presidential_ticket_candidates\s*=\s*yes') {
		Add-Issue "multi-party-refresh" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Existing campaigns must refresh the active-party registry on each guarded election maintenance pulse."
	}
	if ($campaignPreparationBlock -notmatch 'vptl_clear_presidential_campaign_party_tickets\s*=\s*yes') {
		Add-Issue "multi-party-new-campaign-cleanup" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Campaign preparation must retire any interrupted prior generation before creating new party tickets."
	}
	foreach ($legacyState in @('vptl_presidential_ticket_candidate', 'vptl_presidential_ticket_running_mate', 'vptl_presidential_opposition_candidate', 'vptl_presidential_opposition_running_mate')) {
		if ($legacyMigrationBlock -notmatch $legacyState) {
			Add-Issue "multi-party-legacy-migration" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Legacy active campaigns must migrate all four historical ticket slots into party-owned state."
			break
		}
		if ($legacyMigrationBlock -notmatch "remove_variable\s*=\s*$([regex]::Escape($legacyState))") {
			Add-Issue "multi-party-legacy-retirement" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "All four legacy ticket slots must be retired immediately after one-time migration."
			break
		}
	}
	if ($settlementBlock -notmatch 'vptl_identify_presidential_winning_ticket_side\s*=\s*yes' -or
		$settlementBlock -notmatch 'vptl_clear_presidential_campaign_party_tickets\s*=\s*yes' -or
		$certificationBlock -notmatch 'vptl_mark_losing_presidential_party_tickets\s*=\s*yes') {
		Add-Issue "multi-party-settlement" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Settlement must certify party-owned state, mark losing tickets temporarily, and then clear campaign party tickets."
	}
	if ($replacementPresidentBlock -notmatch 'vptl_presidential_transition_losing_ticket_exclusion' -or
		$replacementVicePresidentBlock -notmatch 'vptl_presidential_transition_losing_ticket_exclusion' -or
		$cleanupBlock -notmatch 'vptl_presidential_transition_losing_ticket_exclusion') {
		Add-Issue "multi-party-losing-exclusions" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "All losing party-ticket characters must be excluded only during the current transition and cleared afterward."
	}
	foreach ($required in @('scope\s*=\s*party', 'vptl_presidential_party_ticket_generation_current', 'vptl_presidential_party_ticket_candidate')) {
		if ($partyCandidateGuiBlock -notmatch $required) {
			Add-Issue "multi-party-gui-scope" "common\scripted_guis\zzz_vptl_term_limits.txt" 0 "Party candidate visibility must be driven by current party-owned ticket state."
			break
		}
	}
	if ($electionPanelGuiText -notmatch 'datamodel\s*=\s*"?\[Election\.GetParties\]' -or
		$electionPanelGuiText -notmatch "Party\.MakeScope\.Var\('vptl_presidential_party_ticket_candidate'\)" -or
		$electionPanelGuiText -notmatch "Party\.MakeScope\.Var\('vptl_presidential_party_ticket_running_mate'\)" -or
		$electionPanelGuiText -match '(?m)^\s*vptl_presidential_candidates_election_panel\s*=\s*\{\}\s*$') {
		Add-Issue "multi-party-election-panel" "gui\election_panel.gui" 0 "The election panel must show party-owned nominees inside Election.GetParties rows and must not instantiate the legacy two-ticket strip."
	}
	if ($ticketValidationBlock -match 'every_active_party\s*=') {
		Add-Issue "unsupported-trigger-party-iteration" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Scripted triggers must not use every_active_party; party iteration is an effect-only operation."
	}
	if ($partyRegistryBlock -match '(?m)^\s*owner\s*=\s*\{' -or
		$partyRegistryBlock -match '(?m)^\s*owner\.var:' -or
		$partyRegistryBlock -notmatch 'scope:vptl_presidential_campaign_country' -or
		$partyRegistryBlock -notmatch 'target\s*=\s*scope:vptl_current_campaign_party') {
		Add-Issue "party-scope-owner-link" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Party-scope registry effects must use the saved country scope and explicit party target instead of owner links."
	}
	if ($partyTicketMaintenanceBlock -match '(?m)^\s*owner\s*=\s*\{\s*save_scope_as\s*=\s*vptl_presidential_campaign_country') {
		Add-Issue "party-maintenance-owner-link" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Party-ticket maintenance must not resolve its country through an unsupported party owner link."
	}
	if ($partyCandidateGuiBlock -notmatch 'has_variable\s*=\s*vptl_presidential_party_ticket_candidate' -or
		$partyRunningMateGuiBlock -notmatch 'has_variable\s*=\s*vptl_presidential_party_ticket_running_mate') {
		Add-Issue "party-gui-variable-guards" "common\scripted_guis\zzz_vptl_term_limits.txt" 0 "Party-ticket GUI visibility must guard both saved character variables before dereferencing them."
	}
	$partyCandidateVisibilityCount = ([regex]::Matches($electionPanelGuiText, "vptl_show_presidential_party_ticket_candidate_sgui'\)\.IsShown")).Count
	$partyRunningMateVisibilityCount = ([regex]::Matches($electionPanelGuiText, "vptl_show_presidential_party_ticket_running_mate_sgui'\)\.IsShown")).Count
	if ($partyCandidateVisibilityCount -lt 2 -or $partyRunningMateVisibilityCount -lt 2) {
		Add-Issue "party-gui-dereference-guards" "gui\election_panel.gui" 0 "Party candidate and running-mate data contexts must be protected by visible and unavailable-state scripted-GUI guards."
	}
	foreach ($required in @(
		'vptl_presidential_basic_eligibility',
		'is_character_alive',
		'has_role_of_type\s*=\s*politician',
		'is_heir_of_own_country\s*=\s*no',
		'owner\.var:vptl_vice_president_elect\s*\?=\s*this',
		'owner\.var:vptl_presidential_transition_outgoing_ruler\s*\?=\s*this',
		'owner\.var:vptl_presidential_final_running_mate\s*\?=\s*this',
		'owner\.var:vptl_president_elect',
		'vptl_vice_presidential_terms_served'
	)) {
		if ($certifiedOutgoingVicePresidentElectEligibilityBlock -notmatch $required) {
			Add-Issue "outgoing-vice-president-elect" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Only the valid certified VP-elect who is also the outgoing acting president may step down into the vice presidency."
			break
		}
	}
	if ($certifiedOutgoingVicePresidentElectEligibilityBlock -match 'is_ruler_of_own_country\s*=\s*no') {
		Add-Issue "outgoing-vice-president-elect-preservation" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "The exact certified VP-elect/outgoing-president overlap must remain valid while that character is still acting ruler."
	}
	if ($electTicketRepairBlock -notmatch '\bvptl_presidential_transition_replacement_running_mate_eligible\s*=\s*yes' -or
		$electTicketRepairBlock -notmatch '\bvptl_presidential_certified_outgoing_vice_president_elect_eligible\s*=\s*yes') {
		Add-Issue "outgoing-vice-president-elect-preservation" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "VP-elect maintenance must preserve either an ordinarily eligible running mate or the exact certified outgoing acting president."
	}
	if ($replacementVicePresidentSelectionBlock -match '\bvptl_presidential_certified_outgoing_vice_president_elect_eligible\s*=\s*yes') {
		Add-Issue "outgoing-vice-president-elect-selection" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "The outgoing-president exception may preserve an existing certified VP-elect but must never select a new replacement VP-elect."
	}
	$vicePresidentElectWritePattern = 'set_variable\s*=\s*\{\s*name\s*=\s*vptl_vice_president_elect\b'
	$certificationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_certify_presidential_election"
	if (([regex]::Matches($certificationBlock, $vicePresidentElectWritePattern)).Count -ne 1 -or
		([regex]::Matches($replacementVicePresidentSelectionBlock, $vicePresidentElectWritePattern)).Count -ne 3 -or
		([regex]::Matches($allEffectText, $vicePresidentElectWritePattern)).Count -ne 4) {
		Add-Issue "vice-president-elect-write-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "The initial VP-elect must be written only by certification; all later writes must remain confined to the guarded replacement selector."
	}
	if ($inaugurationInstallBlock -notmatch '\bvptl_presidential_certified_outgoing_vice_president_elect_eligible\s*=\s*yes' -or
		$inaugurationInstallBlock -notmatch '\bvptl_presidential_new_successor_candidate_eligible\s*=\s*yes' -or
		$inaugurationInstallBlock -notmatch '\bvptl_update_presidential_successor_unrestricted\s*=\s*yes') {
		Add-Issue "outgoing-vice-president-elect" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Inauguration must install a valid ordinary or outgoing certified VP-elect before using unrestricted fallback selection."
	}
	if ($replacementPresidentBlock -notmatch '\bvptl_presidential_candidate_eligible\s*=\s*yes' -or
		$replacementPresidentBlock -match 'character_role_vptl_former_president|vptl_vice_presidential_terms_served') {
		Add-Issue "transition-president-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Replacement presidents-elect must allow non-term-limited former presidents while retaining presidential term limits."
	}
	if ($replacementVicePresidentBlock -notmatch '\bvptl_presidential_new_successor_candidate_eligible\s*=\s*yes') {
		Add-Issue "transition-vice-president-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Replacement vice presidents-elect must retain former-president and two-term vice-president exclusions."
	}
	if ($transitionSuccessorBlock -notmatch 'owner\.var:vptl_president_elect' -or
		$transitionSuccessorBlock -notmatch 'owner\.var:vptl_vice_president_elect') {
		Add-Issue "transition-sitting-successor-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Pending-transition sitting-successor selection must exclude both certified elects."
	}
}

$electRolesPath = Join-Path $resolvedModPath "common\character_roles\zzz_vptl_successor_roles.txt"
$journalEntriesPath = Join-Path $resolvedModPath "common\journal_entries\zzz_vptl_presidential_inauguration.txt"
$journalGroupsPath = Join-Path $resolvedModPath "common\journal_entry_groups\zzz_vptl_presidential_inauguration.txt"
$presidentialMessagesPath = Join-Path $resolvedModPath "common\messages\zzz_vptl_presidential_messages.txt"
$presidentialModifiersPath = Join-Path $resolvedModPath "common\static_modifiers\zzz_vptl_term_limits.txt"
foreach ($definition in @(
	@($electRolesPath, 'character_role_vptl_president_elect'),
	@($electRolesPath, 'character_role_vptl_vice_president_elect'),
	@($presidentialMessagesPath, 'vptl_presidential_inauguration'),
	@($presidentialMessagesPath, 'vptl_presidential_transition_unusual'),
	@($presidentialModifiersPath, 'modifier_vptl_lame_duck_administration')
)) {
	if (-not (Test-Path $definition[0]) -or [string]::IsNullOrWhiteSpace((Get-TopLevelBlockText $definition[0] $definition[1]))) {
		Add-Issue "inauguration-assets" $definition[0] 0 "Missing required inauguration definition '$($definition[1])'."
	}
}

foreach ($effectName in @('vptl_initialize_presidential_constitution_defaults', 'vptl_certify_presidential_election', 'vptl_schedule_presidential_inauguration', 'vptl_inaugurate_president_elect', 'vptl_cleanup_presidential_inauguration_transition', 'vptl_maintain_presidential_inauguration_transition', 'vptl_handle_presidential_inauguration_character_death', 'vptl_repair_transition_sitting_successor', 'vptl_restore_transition_acting_ruler', 'vptl_update_presidential_successor_unrestricted')) {
	if ([string]::IsNullOrWhiteSpace((Get-TopLevelBlockText $presidentialEffectsPath $effectName))) {
		Add-Issue "inauguration-effects" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Missing required inauguration effect '$effectName'."
	}
}

$successorWrapperBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_update_presidential_successor"
$transitionSuccessorRepairBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_repair_transition_sitting_successor"
$transitionMaintenanceBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_maintain_presidential_inauguration_transition"
$inaugurationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_inaugurate_president_elect"
$transitionDeathBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_handle_presidential_inauguration_character_death"
$actingRulerRestoreBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_restore_transition_acting_ruler"
$unexpectedRulerRepairBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_correct_unexpected_presidential_ruler_change"
$deadRulerPromotionBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_promote_presidential_successor_if_ruler_is_dead"
$trackedDeadRulerPromotionBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_promote_presidential_successor_if_tracked_ruler_is_dead"
$ineligibleRulerReplacementBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_replace_ineligible_usa_presidential_ruler_with_successor"
$rulerSelectedBlock = Get-TopLevelBlockText $presidentialOnActionsPath "vptl_presidential_successor_ruler_selected"
if ($successorWrapperBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_pending' -or
	$successorWrapperBlock -notmatch 'vptl_repair_transition_sitting_successor\s*=\s*yes' -or
	$successorWrapperBlock -notmatch 'vptl_update_presidential_successor_unrestricted\s*=\s*yes') {
	Add-Issue "transition-successor-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Successor maintenance must route pending transitions to protected repair and normal operation to unrestricted selection."
}
if ($rulerSelectedBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_pending' -or
	$rulerSelectedBlock -notmatch 'vptl_restore_transition_outgoing_ruler\s*=\s*yes' -or
	$rulerSelectedBlock -notmatch 'vptl_restore_transition_acting_ruler\s*=\s*yes' -or
	$rulerSelectedBlock -notmatch 'vptl_presidential_handoff_in_progress' -or
	$rulerSelectedBlock -notmatch 'has_variable\s*=\s*vptl_presidential_pending_death_handling') {
	Add-Issue "transition-acting-ruler" "common\on_actions\zzz_vptl_term_limits.txt" 0 "Pending-transition ruler callbacks must allow constitutional handoff but restore the saved acting ruler instead of accepting fallback rulers."
}
if ($actingRulerRestoreBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_pending' -or
	$actingRulerRestoreBlock -notmatch 'has_variable\s*=\s*vptl_presidential_current_ruler' -or
	$actingRulerRestoreBlock -notmatch 'set_character_as_ruler\s*=\s*yes' -or
	$actingRulerRestoreBlock -notmatch 'vptl_sync_presidential_current_ruler\s*=\s*yes' -or
	$actingRulerRestoreBlock -notmatch 'set_variable\s*=\s*\{\s*name\s*=\s*vptl_presidential_transition_outgoing_ruler\s+value\s*=\s*var:vptl_presidential_current_ruler\s*\}') {
	Add-Issue "transition-acting-ruler" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Pending-transition acting-ruler restore must reinstall the tracked living acting ruler and resynchronize state."
}
if ($unexpectedRulerRepairBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_inauguration_pending\s*\}') {
	Add-Issue "transition-acting-ruler" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Normal unexpected-ruler repair must not accept fallback rulers during a pending inauguration."
}
foreach ($promotionBlock in @($deadRulerPromotionBlock, $trackedDeadRulerPromotionBlock)) {
	if ($promotionBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_inauguration_pending\s*\}' -or
		$promotionBlock -notmatch 'has_variable\s*=\s*vptl_presidential_pending_death_handling') {
		Add-Issue "transition-death-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Generic successor promotion must be blocked during inauguration unless the active transition death handler authorized it."
	}
}
if ($transitionDeathBlock -notmatch 'set_variable\s*=\s*vptl_presidential_pending_death_handling' -or
	$transitionDeathBlock -notmatch 'remove_variable\s*=\s*vptl_presidential_pending_death_handling') {
	Add-Issue "transition-death-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Pending-transition character death handling must bracket constitutional succession with its dedicated authorization latch."
}
if ($ineligibleRulerReplacementBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_inauguration_pending\s*\}') {
	Add-Issue "transition-acting-ruler" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Normal USA ruler-eligibility replacement must not change the acting president during a pending inauguration."
}
if ($transitionMaintenanceBlock -notmatch 'vptl_restore_transition_outgoing_ruler\s*=\s*yes' -or
	$transitionMaintenanceBlock -notmatch 'vptl_restore_transition_acting_ruler\s*=\s*yes') {
	Add-Issue "transition-acting-ruler" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Pending-transition maintenance must reassert a surviving outgoing or acting president against deferred fallback ruler changes."
}
$maintenanceElectRepairIndex = $transitionMaintenanceBlock.IndexOf('vptl_repair_presidential_elect_ticket = yes')
$maintenanceOutgoingRestoreIndex = $transitionMaintenanceBlock.IndexOf('vptl_restore_transition_outgoing_ruler = yes')
$maintenanceActingRestoreIndex = $transitionMaintenanceBlock.IndexOf('vptl_restore_transition_acting_ruler = yes')
if ($maintenanceElectRepairIndex -lt 0 -or $maintenanceOutgoingRestoreIndex -lt 0 -or $maintenanceActingRestoreIndex -lt 0 -or
	$maintenanceOutgoingRestoreIndex -ge $maintenanceElectRepairIndex -or $maintenanceActingRestoreIndex -ge $maintenanceElectRepairIndex) {
	Add-Issue "transition-acting-ruler-order" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition maintenance must repair the outgoing or acting ruler before validating the certified elect ticket."
}
if ($transitionDeathBlock -notmatch 'set_variable\s*=\s*\{\s*name\s*=\s*vptl_presidential_transition_outgoing_ruler\s+value\s*=\s*var:vptl_presidential_current_ruler\s*\}') {
	Add-Issue "transition-acting-ruler" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Pending-transition death handling must preserve the tracked acting ruler as outgoing/interim ruler."
}
if ($transitionSuccessorRepairBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_pending' -or
	$transitionSuccessorRepairBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_successor\s*\}' -or
	$transitionSuccessorRepairBlock -notmatch 'vptl_presidential_sitting_successor_handoff_eligible\s*=\s*yes' -or
	$transitionSuccessorRepairBlock -notmatch 'vptl_select_transition_sitting_successor_replacement\s*=\s*yes') {
	Add-Issue "transition-successor-repair" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Pending-transition successor repair must replace only a missing or genuinely ineligible sitting successor."
}
if ($transitionSuccessorRepairBlock -match 'owner\.var:vptl_(?:president_elect|vice_president_elect)') {
	Add-Issue "transition-successor-overlap" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "A valid sitting successor must not be replaced merely because they are also a certified elect."
}
if ($transitionMaintenanceBlock -notmatch 'vptl_repair_transition_sitting_successor\s*=\s*yes') {
	Add-Issue "transition-successor-repair" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition maintenance must repair a missing or genuinely ineligible sitting successor."
}
if ($inaugurationBlock -notmatch 'vptl_update_presidential_successor_unrestricted\s*=\s*yes') {
	Add-Issue "transition-successor-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Inauguration must use unrestricted successor selection only when no valid vice president-elect can be installed."
}
$unrestrictedCallCount = ([regex]::Matches($allEffectText, '\bvptl_update_presidential_successor_unrestricted\s*=\s*yes')).Count
if ($unrestrictedCallCount -ne 2) {
	Add-Issue "transition-successor-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Unrestricted successor selection must be called only by the normal wrapper and the inauguration fallback."
}
foreach ($triggerName in @('vptl_presidential_transition_qualifies', 'vptl_presidential_uses_delayed_inauguration', 'vptl_presidential_inauguration_is_due', 'vptl_presidential_existing_campaign_running_mate_eligible', 'vptl_presidential_certified_outgoing_vice_president_elect_eligible', 'vptl_presidential_transition_replacement_candidate_eligible', 'vptl_presidential_transition_replacement_running_mate_eligible', 'vptl_presidential_transition_sitting_successor_replacement_eligible')) {
	if ([string]::IsNullOrWhiteSpace((Get-TopLevelBlockText $presidentialTriggersPath $triggerName))) {
		Add-Issue "inauguration-triggers" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Missing required inauguration trigger '$triggerName'."
	}
}
if (Test-Path $journalEntriesPath) {
	$journalGroupName = 'vptl_je_group_presidential_inauguration'
	if (-not (Test-Path $journalGroupsPath)) {
		Add-Issue "inauguration-journal-group" "common\journal_entry_groups\zzz_vptl_presidential_inauguration.txt" 0 "Missing the BPR inauguration journal group."
	}
	else {
		$journalGroupBlock = Get-TopLevelBlockText $journalGroupsPath $journalGroupName
		if ($journalGroupBlock -notmatch '\bcontext\s*=\s*country') {
			Add-Issue "inauguration-journal-group" "common\journal_entry_groups\zzz_vptl_presidential_inauguration.txt" 0 "The BPR inauguration journal group must use country context."
		}
	}
	foreach ($days in @(30, 60, 90, 120)) {
		$legacyEntryName = "je_vptl_presidential_transition_$days"
		$legacyEntryBlock = Get-TopLevelBlockText $journalEntriesPath $legacyEntryName
		if ([string]::IsNullOrWhiteSpace($legacyEntryBlock) -or
			$legacyEntryBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_journal_generation') {
			Add-Issue "inauguration-journal-legacy" "common\journal_entries\zzz_vptl_presidential_inauguration.txt" 0 "Legacy journal '$legacyEntryName' must invalidate once generated journals are active."
		}
		foreach ($generation in @(@('a', 1), @('b', 2))) {
			$suffix = [string]$generation[0]
			$generationValue = [int]$generation[1]
			$entryName = "je_vptl_presidential_transition_$($days)_$suffix"
			$entryBlock = Get-TopLevelBlockText $journalEntriesPath $entryName
			if ([string]::IsNullOrWhiteSpace($entryBlock) -or
				$entryBlock -notmatch "group\s*=\s*$journalGroupName" -or
				$entryBlock -notmatch "timeout\s*=\s*$days" -or
				$entryBlock -notmatch "var:vptl_presidential_inauguration_rule\s*=\s*$days" -or
				$entryBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_journal_generation_assigned' -or
				$entryBlock -notmatch "var:vptl_presidential_inauguration_journal_generation\s*=\s*$generationValue" -or
				$entryBlock -notmatch '\bvptl_inaugurate_president_elect\s*=\s*yes') {
				Add-Issue "inauguration-journal" "common\journal_entries\zzz_vptl_presidential_inauguration.txt" 0 "Journal '$entryName' must match its duration, generation, country group, and common inauguration effect."
			}
		}
	}
}
else {
	Add-Issue "inauguration-journal" "common\journal_entries\zzz_vptl_presidential_inauguration.txt" 0 "Missing fixed-duration inauguration journals."
}

if (Test-Path $presidentialEffectsPath) {
	$electRoleRefreshBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_refresh_presidential_elect_roles"
	if ($electRoleRefreshBlock -match 'remove_character_role\s*=\s*character_role_vptl_vice_president(?:\s|$)|remove_variable\s*=\s*vptl_presidential_successor') {
		Add-Issue "elect-role-preservation" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Elect-role refresh must not remove a sitting vice-president role or constitutional-successor state."
	}
}

$numberTraitsPath = Join-Path $resolvedModPath "common\scripted_effects\zzz_vptl_presidential_number_traits.txt"
$presidentialScriptedGuiPath = Join-Path $resolvedModPath "common\scripted_guis\zzz_vptl_term_limits.txt"
$successorCountryTitlesPath = Join-Path $resolvedModPath "common\customizable_localization\zzz_vptl_successor_titles.txt"
$successorRoleTitlesPath = Join-Path $resolvedModPath "common\customizable_localization\zzz_vptl_successor_role_titles.txt"
$presidentialSystemLocPath = Join-Path $resolvedModPath "common\customizable_localization\zzz_vptl_presidential_system.txt"
$presidentialEnglishLocPath = Join-Path $resolvedModPath "localization\english\vptl_term_limits_l_english.yml"

$formerPresidentRoleBlock = Get-TopLevelBlockText $electRolesPath "character_role_vptl_former_president"
$formerPresidentTitleBlock = Get-TopLevelBlockText $successorRoleTitlesPath "character_role_vptl_former_president_custom_loc"
if ($formerPresidentRoleBlock -notmatch 'priority\s*=\s*55' -or
	$formerPresidentRoleBlock -notmatch 'title_format\s*=\s*custom' -or
	$formerPresidentRoleBlock -notmatch 'title_preposition\s*=\s*PREP_IN') {
	Add-Issue "former-president-title" "common\character_roles\zzz_vptl_successor_roles.txt" 0 "The former-president role must use custom formatting, PREP_IN, and priority 55 so it outranks ordinary roles while remaining below active presidential offices."
}
if ([string]::IsNullOrWhiteSpace($formerPresidentTitleBlock) -or
	$formerPresidentTitleBlock -notmatch 'localization_key\s*=\s*character_role_vptl_former_president_title') {
	Add-Issue "former-president-title" "common\customizable_localization\zzz_vptl_successor_role_titles.txt" 0 "The former-president custom localization must resolve to character_role_vptl_former_president_title."
}

$orderSeedBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_seed_1836_presidential_order_numbers"
$usaOrderSeedBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_seed_usa_presidential_order_numbers"
$usaServiceHistoryBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_seed_usa_historical_service_history"
$orderSuppressionSeedBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_seed_1836_presidential_order_display_suppressions"
$orderAssignmentBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_assign_presidential_order_number_to_current_ruler"
if ($orderAssignmentBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_historical_order_numbers_v2_initialized\s*\}' -or
	$orderAssignmentBlock -notmatch 'vptl_seed_usa_presidential_order_numbers\s*=\s*yes' -or
	$orderAssignmentBlock -notmatch 'vptl_seed_1836_presidential_order_numbers\s*=\s*yes' -or
	$orderAssignmentBlock -notmatch 'vptl_seed_1836_presidential_order_display_suppressions\s*=\s*yes' -or
	$orderAssignmentBlock -notmatch 'set_variable\s*=\s*vptl_presidential_historical_order_numbers_v2_initialized') {
	Add-Issue "historical-order-revision" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Historical office metadata must use the save-compatible v2 latch and run number and suppression seeds once."
}
if ($orderAssignmentBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_historical_service_seeds_v3_initialized\s*\}' -or
	$orderAssignmentBlock -notmatch 'vptl_seed_usa_historical_service_history\s*=\s*yes' -or
	$orderAssignmentBlock -notmatch 'set_variable\s*=\s*vptl_presidential_historical_service_seeds_v3_initialized') {
	Add-Issue "historical-service-revision" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Historical USA service metadata must use the save-compatible v3 latch and run its seed once."
}
if ($usaServiceHistoryBlock -notmatch 'has_trait\s*=\s*vptl_presidential_service_one_term_trait[\s\S]*?vptl_presidential_terms_served\s+value\s*=\s*1' -or
	$usaServiceHistoryBlock -notmatch 'has_trait\s*=\s*vptl_presidential_service_one_term_trait[\s\S]*?vptl_presidential_years_served\s+value\s*=\s*4' -or
	$usaServiceHistoryBlock -notmatch 'has_trait\s*=\s*vptl_presidential_history_marker_no_6[\s\S]*?vptl_presidential_order_number\s+value\s*=\s*6' -or
	$usaServiceHistoryBlock -notmatch 'add_character_role\s*=\s*character_role_vptl_former_president') {
	Add-Issue "usa-personal-service-seed" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Personal history traits must seed one-term presidential service, President No. 6, and the former-president role without donor template references."
}
if ($usaServiceHistoryBlock -notmatch 'has_trait\s*=\s*vptl_vice_presidential_service_one_term_trait[\s\S]*?vptl_vice_presidential_terms_served\s+value\s*=\s*1' -or
	$usaServiceHistoryBlock -notmatch 'has_trait\s*=\s*vptl_vice_presidential_service_one_term_trait[\s\S]*?vptl_vice_presidential_years_served\s+value\s*=\s*4') {
	Add-Issue "usa-personal-vice-service-seed" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Personal history traits must seed one tracked vice-presidential term and four years without donor template references."
}

$historicalNumberSeeds = @(
	@($usaOrderSeedBlock, 'usa_andrew_jackson_template', 7, 'USA'),
	@($orderSeedBlock, 'CLM_Francisco_de_Paula_Santander', 1, 'CLM'),
	@($orderSeedBlock, 'ECU_Vicente_Rocafuerte', 2, 'ECU'),
	@($orderSeedBlock, 'PNI_bento_goncalves_da_silva', 1, 'PNI'),
	@($orderSeedBlock, 'PRA_eduardo_angelim', 3, 'PRA'),
	@($orderSeedBlock, 'TEX_david_burnet', 1, 'TEX'),
	@($orderSeedBlock, 'UCA_francisco_morazan', 2, 'UCA'),
	@($orderSeedBlock, 'URU_Manuel_Oribe', 2, 'URU')
)
foreach ($seed in $historicalNumberSeeds) {
	$templatePattern = [regex]::Escape([string]$seed[1])
	$number = [int]$seed[2]
	if ([string]::IsNullOrWhiteSpace([string]$seed[0]) -or [string]$seed[0] -notmatch "has_template\s*=\s*$templatePattern[\s\S]*?vptl_presidential_order_number\s+value\s*=\s*$number") {
		Add-Issue "historical-order-seed" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Missing historical presidential order seed $($seed[3]) $($seed[1]) No. $number."
	}
}
foreach ($newSeed in @(@('PNI', 1), @('PRA', 3))) {
	if ($orderSeedBlock -notmatch "c:$($newSeed[0])[\s\S]*?vptl_presidential_order_counter\s+value\s*=\s*$($newSeed[1])") {
		Add-Issue "historical-order-counter" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "$($newSeed[0]) must seed its internal presidential order counter to at least $($newSeed[1])."
	}
}

$suppressedStartingRulers = @(
	@('BRE', 'BRE_johann_smidt'),
	@('FRM', 'FRM_ferdinand_starck'),
	@('HAM', 'HAM_christian_daniel_benecke'),
	@('ION', 'ION_howard_douglas'),
	@('KRA', 'KRA_Kasper_Wieloglowski'),
	@('LAN', 'LAN_taiji_liu'),
	@('LUB', 'LUB_christian_nicolaus_von_evers'),
	@('ORA', 'ORA_hendrik_potgieter'),
	@('TRN', 'TRN_andries_pretorius')
)
foreach ($suppressed in $suppressedStartingRulers) {
	$templatePattern = [regex]::Escape([string]$suppressed[1])
	if ($orderSuppressionSeedBlock -notmatch "c:$($suppressed[0])[\s\S]*?has_template\s*=\s*$templatePattern[\s\S]*?set_variable\s*=\s*vptl_presidential_order_number_display_suppressed[\s\S]*?vptl_refresh_presidential_office_markers\s*=\s*yes") {
		Add-Issue "historical-order-suppression" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "$($suppressed[0]) starting ruler $($suppressed[1]) must suppress ordinal display and refresh office markers."
	}
}

$numberTraitBlock = Get-TopLevelBlockText $numberTraitsPath "vptl_refresh_presidential_number_trait"
$orderNumberGuiBlock = Get-TopLevelBlockText $presidentialScriptedGuiPath "vptl_show_presidential_order_number_sgui"
if ($numberTraitBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_order_number_display_suppressed\s*\}') {
	Add-Issue "historical-order-suppression" "common\scripted_effects\zzz_vptl_presidential_number_traits.txt" 0 "Numbered presidential traits must not be applied to ordinal-suppressed rulers."
}
if ($orderNumberGuiBlock -notmatch 'NOT\s*=\s*\{\s*has_variable\s*=\s*vptl_presidential_order_number_display_suppressed\s*\}') {
	Add-Issue "historical-order-suppression" "common\scripted_guis\zzz_vptl_term_limits.txt" 0 "The government-panel presidential ordinal must be hidden for ordinal-suppressed rulers."
}

$presidentialSystemLocText = if (Test-Path $presidentialSystemLocPath) { [System.IO.File]::ReadAllText($presidentialSystemLocPath) } else { '' }
foreach ($customLocName in @('vptl_presidential_office_status_with_number', 'vptl_presidential_ruler_title_with_number')) {
	$customLocBlock = Get-TopLevelBlockText $presidentialSystemLocPath $customLocName
	if ($customLocBlock -notmatch 'vptl_presidential_order_number_display_suppressed') {
		Add-Issue "historical-order-localization" "common\customizable_localization\zzz_vptl_presidential_system.txt" 0 "Custom localization '$customLocName' must respect ordinal-display suppression."
	}
}
$presidentialEnglishLocText = if (Test-Path $presidentialEnglishLocPath) { [System.IO.File]::ReadAllText($presidentialEnglishLocPath) } else { '' }
foreach ($days in @(30, 60, 90, 120)) {
	foreach ($generation in @('a', 'b')) {
		foreach ($suffix in @('', '_reason')) {
			$locKey = "je_vptl_presidential_transition_$($days)_$generation$suffix"
			if ($presidentialEnglishLocText -notmatch "(?m)^\s*$([regex]::Escape($locKey)):0\s+") {
				Add-Issue "inauguration-journal-localization" "localization\english\vptl_term_limits_l_english.yml" 0 "Missing generated transition-journal localization '$locKey'."
			}
		}
	}
}
foreach ($locKey in @('modifier_vptl_presidential_term_limited_desc', 'modifier_vptl_presidential_service_partial_term', 'modifier_vptl_presidential_service_one_term', 'modifier_vptl_presidential_service_two_terms', 'vptl_presidential_history_marker')) {
	if ($presidentialEnglishLocText -notmatch "(?m)^\s*$locKey:0\s+.*vptl_presidential_office_status_with_number") {
		Add-Issue "historical-order-localization" "localization\english\vptl_term_limits_l_english.yml" 0 "Localization '$locKey' must use suppression-aware office-status numbering."
	}
}
foreach ($locKey in @('vptl_election_results_presidential_winner_line_text', 'notification_vptl_presidential_transition_desc', 'notification_vptl_presidential_inauguration_desc')) {
	if ($presidentialEnglishLocText -notmatch "(?m)^\s*$locKey:0\s+.*vptl_presidential_ruler_title_with_number") {
		Add-Issue "historical-order-localization" "localization\english\vptl_term_limits_l_english.yml" 0 "Localization '$locKey' must use suppression-aware ruler-title numbering."
	}
}

$successorCountryTitlesText = if (Test-Path $successorCountryTitlesPath) { [System.IO.File]::ReadAllText($successorCountryTitlesPath) } else { '' }
$successorRoleTitlesText = if (Test-Path $successorRoleTitlesPath) { [System.IO.File]::ReadAllText($successorRoleTitlesPath) } else { '' }
$successorTitleMappings = @(
	@('BRE', 'vptl_presidential_successor_mayoral'), @('FRM', 'vptl_presidential_successor_mayoral'), @('HAM', 'vptl_presidential_successor_mayoral'), @('LUB', 'vptl_presidential_successor_mayoral'),
	@('KRA', 'vptl_presidential_successor_senate_successor'), @('ION', 'vptl_presidential_successor_high_commissioner'), @('LAN', 'vptl_presidential_successor_kongsi'),
	@('ORA', 'vptl_presidential_successor_commandant'), @('TRN', 'vptl_presidential_successor_commandant'), @('PRA', 'vptl_presidential_successor_government')
)
foreach ($mapping in $successorTitleMappings) {
	$tag = [regex]::Escape([string]$mapping[0])
	$key = [regex]::Escape([string]$mapping[1])
	if ($successorCountryTitlesText -notmatch "c:$tag[\s\S]*?localization_key\s*=\s*$key" -or $successorRoleTitlesText -notmatch "c:$tag[\s\S]*?localization_key\s*=\s*$key") {
		Add-Issue "successor-title-mapping" "common\customizable_localization" 0 "$($mapping[0]) must use successor title key '$($mapping[1])' in both country and character-role localization."
	}
	if ($presidentialEnglishLocText -notmatch "(?m)^\s*$key:0\s+") {
		Add-Issue "successor-title-localization" "localization\english\vptl_term_limits_l_english.yml" 0 "Missing successor-title localization '$($mapping[1])'."
	}
}
$vicePresidentTitleTrigger = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_successor_uses_vice_president_title"
foreach ($tag in @('USA', 'CLM', 'ECU', 'PNI', 'TEX', 'UCA')) {
	if ($vicePresidentTitleTrigger -notmatch "c:$tag") {
		Add-Issue "successor-title-mapping" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "$tag must use the Vice President successor title."
	}
}
if ($successorCountryTitlesText -notmatch 'c:URU[\s\S]*?localization_key\s*=\s*vptl_presidential_successor_senate_president' -or
	$successorRoleTitlesText -notmatch 'c:URU[\s\S]*?localization_key\s*=\s*vptl_presidential_successor_senate_president') {
	Add-Issue "successor-title-mapping" "common\customizable_localization" 0 "Uruguay must use President of the Senate in both country and character-role localization."
}

$roadmapPath = Join-Path $resolvedModPath "docs\roadmap.md"
if (Test-Path $roadmapPath) {
	$roadmapText = [System.IO.File]::ReadAllText($roadmapPath)
	if ($roadmapText -match '(?i)incumbent reelection model|voluntary retirement|renomination loss|comeback (?:campaign|attempt)|incumbency.*(?:bonus|adjustment)|popularity.*election bonus') {
		Add-Issue "scrapped-roadmap" "docs\roadmap.md" 0 "Scrapped incumbent-reelection or candidate-performance roadmap text remains."
	}
}

$obsoleteTicketTextPatterns = @(
	'incumbent-party candidate is the current president if still eligible, otherwise the eligible successor',
	'automatic(?:ally)?[- ](?:vice president|vp)'
)
foreach ($file in $localizationFiles) {
	$text = [System.IO.File]::ReadAllText($file.FullName)
	foreach ($pattern in $obsoleteTicketTextPatterns) {
		if ($text -match $pattern) {
			Add-Issue "obsolete-ticket-text" (Get-DisplayPath $file.FullName) 0 "Obsolete automatic-successor ticket wording is present."
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
