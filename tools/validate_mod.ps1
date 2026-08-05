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
	foreach ($state in @('vptl_president_elect', 'vptl_vice_president_elect', 'vptl_presidential_inauguration_pending', 'vptl_presidential_inauguration_timer', 'vptl_presidential_inauguration_due', 'vptl_presidential_inauguration_completed', 'vptl_presidential_certification_complete', 'vptl_presidential_transition_outgoing_ruler', 'vptl_presidential_transition_winning_party', 'vptl_presidential_transition_winning_ig', 'vptl_presidential_transition_losing_candidate', 'vptl_presidential_transition_losing_running_mate', 'vptl_presidential_transition_incumbent_reelected', 'vptl_presidential_transition_lame_duck', 'vptl_presidential_inauguration_in_progress', 'vptl_presidential_transition_unusual_notification_posted', 'vptl_presidential_final_elected_ruler', 'vptl_presidential_final_running_mate', 'vptl_presidential_winning_ticket_side')) {
		if ($cleanupBlock -notmatch "remove_variable\s*=\s*$([regex]::Escape($state))") {
			Add-Issue "inauguration-cleanup" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition cleanup does not remove '$state'."
		}
	}
	foreach ($cleanupAction in @('remove_modifier\s*=\s*modifier_vptl_lame_duck_administration', 'vptl_refresh_presidential_elect_roles\s*=\s*yes', 'vptl_finish_presidential_election_ruler_notification_suppression\s*=\s*yes')) {
		if ($cleanupWrapperBlock -notmatch $cleanupAction) {
			Add-Issue "inauguration-cleanup" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition cleanup is missing a required role, modifier, or suppression cleanup action."
		}
	}
	foreach ($days in @(30, 60, 90, 120)) {
		if (([regex]::Matches($journalBlock, "add_journal_entry\s*=\s*\{\s*type\s*=\s*je_vptl_presidential_transition_$days\s*\}")).Count -ne 1) {
			Add-Issue "inauguration-journal-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "The $days-day configuration must schedule exactly one matching journal variant."
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
if ((Test-Path $presidentialTriggersPath) -and (Test-Path $presidentialGuiPath)) {
	$candidateEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_candidate_eligible"
	$newSuccessorEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_new_successor_candidate_eligible"
	$sittingSuccessorEligibilityBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_sitting_successor_handoff_eligible"
	$ticketValidationBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_campaign_ticket_valid"
	$incumbentRunningMateGuiBlock = Get-TopLevelBlockText $presidentialGuiPath "vptl_show_presidential_ticket_running_mate_sgui"
	$oppositionRunningMateGuiBlock = Get-TopLevelBlockText $presidentialGuiPath "vptl_show_presidential_opposition_running_mate_sgui"
	$replacementPresidentBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_transition_replacement_candidate_eligible"
	$replacementVicePresidentBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_transition_replacement_running_mate_eligible"
	$transitionSuccessorBlock = Get-TopLevelBlockText $presidentialTriggersPath "vptl_presidential_transition_sitting_successor_replacement_eligible"

	if ([string]::IsNullOrWhiteSpace($candidateEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($newSuccessorEligibilityBlock) -or
		[string]::IsNullOrWhiteSpace($sittingSuccessorEligibilityBlock)) {
		Add-Issue "eligibility-layers" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Separate presidential-candidate, new-successor, and sitting-successor eligibility triggers are required."
	}
	if ($candidateEligibilityBlock -match 'vptl_vice_presidential_terms_served|character_role_vptl_former_president') {
		Add-Issue "presidential-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Presidential candidates must not be blocked by successor-term count or former-president history."
	}
	if ($newSuccessorEligibilityBlock -notmatch 'vptl_vice_presidential_terms_served' -or
		$newSuccessorEligibilityBlock -notmatch 'character_role_vptl_former_president') {
		Add-Issue "successor-selection-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "New successor selection must cap recorded successor terms and block former presidents."
	}
	if ($sittingSuccessorEligibilityBlock -match 'vptl_vice_presidential_terms_served|character_role_vptl_former_president') {
		Add-Issue "successor-handoff-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Sitting successor handoff must not apply new-term or former-president selection restrictions."
	}
	foreach ($block in @($ticketValidationBlock, $incumbentRunningMateGuiBlock, $oppositionRunningMateGuiBlock)) {
		if ($block -notmatch '\bvptl_presidential_new_successor_candidate_eligible\s*=\s*yes') {
			Add-Issue "running-mate-eligibility" "common\scripted_triggers\zzz_vptl_presidential_eligibility.txt" 0 "Ticket validation and both running-mate GUI slots must use new-successor selection eligibility."
			break
		}
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

foreach ($effectName in @('vptl_initialize_presidential_constitution_defaults', 'vptl_certify_presidential_election', 'vptl_schedule_presidential_inauguration', 'vptl_inaugurate_president_elect', 'vptl_cleanup_presidential_inauguration_transition', 'vptl_maintain_presidential_inauguration_transition', 'vptl_handle_presidential_inauguration_character_death', 'vptl_repair_transition_sitting_successor', 'vptl_update_presidential_successor_unrestricted')) {
	if ([string]::IsNullOrWhiteSpace((Get-TopLevelBlockText $presidentialEffectsPath $effectName))) {
		Add-Issue "inauguration-effects" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Missing required inauguration effect '$effectName'."
	}
}

$successorWrapperBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_update_presidential_successor"
$transitionSuccessorRepairBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_repair_transition_sitting_successor"
$transitionMaintenanceBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_maintain_presidential_inauguration_transition"
$inaugurationBlock = Get-TopLevelBlockText $presidentialEffectsPath "vptl_inaugurate_president_elect"
if ($successorWrapperBlock -notmatch 'has_variable\s*=\s*vptl_presidential_inauguration_pending' -or
	$successorWrapperBlock -notmatch 'vptl_repair_transition_sitting_successor\s*=\s*yes' -or
	$successorWrapperBlock -notmatch 'vptl_update_presidential_successor_unrestricted\s*=\s*yes') {
	Add-Issue "transition-successor-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Successor maintenance must route pending transitions to protected repair and normal operation to unrestricted selection."
}
foreach ($requiredToken in @('vptl_president_elect', 'vptl_vice_president_elect', 'vptl_select_transition_sitting_successor_replacement')) {
	if ($transitionSuccessorRepairBlock -notmatch "\b$requiredToken\b") {
		Add-Issue "transition-successor-repair" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Pending-transition successor repair is missing '$requiredToken'."
	}
}
if ($transitionMaintenanceBlock -notmatch 'vptl_repair_transition_sitting_successor\s*=\s*yes') {
	Add-Issue "transition-successor-repair" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Transition maintenance must repair saves whose sitting successor equals a certified elect."
}
if ($inaugurationBlock -notmatch 'vptl_update_presidential_successor_unrestricted\s*=\s*yes') {
	Add-Issue "transition-successor-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Inauguration must use unrestricted successor selection only when no valid vice president-elect can be installed."
}
$unrestrictedCallCount = ([regex]::Matches($allEffectText, '\bvptl_update_presidential_successor_unrestricted\s*=\s*yes')).Count
if ($unrestrictedCallCount -ne 2) {
	Add-Issue "transition-successor-routing" "common\scripted_effects\zzz_vptl_term_limits.txt" 0 "Unrestricted successor selection must be called only by the normal wrapper and the inauguration fallback."
}
foreach ($triggerName in @('vptl_presidential_transition_qualifies', 'vptl_presidential_uses_delayed_inauguration', 'vptl_presidential_inauguration_is_due', 'vptl_presidential_transition_replacement_candidate_eligible', 'vptl_presidential_transition_replacement_running_mate_eligible', 'vptl_presidential_transition_sitting_successor_replacement_eligible')) {
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
		$entryName = "je_vptl_presidential_transition_$days"
		$entryBlock = Get-TopLevelBlockText $journalEntriesPath $entryName
		if ([string]::IsNullOrWhiteSpace($entryBlock) -or
			$entryBlock -notmatch "group\s*=\s*$journalGroupName" -or
			$entryBlock -notmatch "timeout\s*=\s*$days" -or
			$entryBlock -notmatch "var:vptl_presidential_inauguration_rule\s*=\s*$days" -or
			$entryBlock -notmatch '\bvptl_inaugurate_president_elect\s*=\s*yes') {
			Add-Issue "inauguration-journal" "common\journal_entries\zzz_vptl_presidential_inauguration.txt" 0 "Journal '$entryName' must match its configured duration, fixed timeout, and common inauguration effect."
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
