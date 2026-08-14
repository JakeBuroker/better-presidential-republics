param(
	[string]$ModPath = (Split-Path -Parent $PSScriptRoot)
)

$effectsPath = Join-Path $ModPath 'common\scripted_effects\zzz_vptl_presidential_history.txt'
$guiPath = Join-Path $ModPath 'gui\vptl_presidential_history_window.gui'
$utf8Bom = New-Object System.Text.UTF8Encoding($true)

function Add-Line([System.Collections.Generic.List[string]]$Lines, [string]$Text = '') { $Lines.Add($Text) }
function Copy-VariableBlock([System.Collections.Generic.List[string]]$Lines, [string]$From, [string]$To, [string[]]$Fields, [string]$Indent = '\t') {
	foreach ($field in $Fields) {
		Add-Line $Lines ("{0}if = {{ limit = {{ has_variable = {1}_{2} }} set_variable = {{ name = {3}_{2} value = var:{1}_{2} }} }}" -f $Indent,$From,$field,$To)
		Add-Line $Lines ("{0}else = {{ remove_variable = {1}_{2} }}" -f $Indent,$To,$field)
	}
}

$scopeFields = @('president','vice_president','party','ig') + (1..8 | ForEach-Object { "law_$_" })
$valueFields = @('number','accession_type','departure_reason','gdp_start','gdp_end','population_start','population_end','sol_start','sol_end','prestige_start','prestige_end','rank_start','rank_end','score_rank_start','score_rank_end','start_year','start_month','end_year','end_month','law_count','law_overflow_count')
$allFields = $scopeFields + $valueFields
$e = [System.Collections.Generic.List[string]]::new()
Add-Line $e '# Standalone presidential-library storage.'
Add-Line $e '# National History (Workshop 3772525185) is the architectural reference only.'
Add-Line $e '# BPR owns its append-only archive, latest-50 cache, GUI, and vptl_ namespace.'
Add-Line $e
Add-Line $e 'vptl_capture_presidential_history_power_rank = {'
Add-Line $e '\tset_variable = { name = vptl_history_capture_rank value = -1 }'
$ranks = @('decentralized_power','unrecognized_power','insignificant_power','unrecognized_regional_power','minor_power','unrecognized_major_power','major_power','great_power')
for ($i=0; $i -lt $ranks.Count; $i++) { Add-Line $e ("\tif = {{ limit = {{ country_rank = rank_value:{0} }} set_variable = {{ name = vptl_history_capture_rank value = {1} }} }}" -f $ranks[$i],$i) }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_capture_presidential_history_numeric_rank = {'
Add-Line $e '\t# Lifecycle-only prestige ordering. Equal-prestige countries share a rank.'
Add-Line $e '\tsave_scope_as = vptl_history_rank_subject'
Add-Line $e '\tset_variable = { name = vptl_history_capture_score_rank value = 1 }'
Add-Line $e '\tevery_country = {'
Add-Line $e '\t\tlimit = { is_country_alive = yes prestige > scope:vptl_history_rank_subject.prestige }'
Add-Line $e '\t\tscope:vptl_history_rank_subject = { change_variable = { name = vptl_history_capture_score_rank add = 1 } }'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_prepare_presidential_history_episode_number = {'
Add-Line $e '\t# The normal accession path owns the first assignment. The ledger accepts it.'
Add-Line $e '\t# Only a former president returning with an older number is advanced here.'
Add-Line $e '\tvptl_assign_presidential_order_number_to_current_ruler = yes'
Add-Line $e '\truler ?= { save_scope_as = vptl_history_numbered_ruler }'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { NOT = { has_variable = vptl_presidential_order_counter } scope:vptl_history_numbered_ruler ?= { has_variable = vptl_presidential_order_number } }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_order_counter value = scope:vptl_history_numbered_ruler.var:vptl_presidential_order_number }'
Add-Line $e '\t}'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { has_variable = vptl_presidential_history_previous_president has_variable = vptl_presidential_order_counter scope:vptl_history_numbered_ruler ?= { is_character_alive = yes has_variable = vptl_presidential_order_number NOT = { owner.var:vptl_presidential_history_previous_president ?= this } } }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_number_gap value = var:vptl_presidential_order_counter }'
Add-Line $e '\t\tchange_variable = { name = vptl_presidential_history_number_gap subtract = scope:vptl_history_numbered_ruler.var:vptl_presidential_order_number }'
Add-Line $e '\t\tif = {'
Add-Line $e '\t\t\tlimit = { var:vptl_presidential_history_number_gap > 0 }'
Add-Line $e '\t\t\tchange_variable = { name = vptl_presidential_order_counter add = 1 }'
Add-Line $e '\t\t\tscope:vptl_history_numbered_ruler = { set_variable = { name = vptl_presidential_order_number value = owner.var:vptl_presidential_order_counter } vptl_refresh_presidential_office_markers = yes }'
Add-Line $e '\t\t}'
Add-Line $e '\t\telse_if = { limit = { var:vptl_presidential_history_number_gap < 0 } set_variable = { name = vptl_presidential_order_counter value = scope:vptl_history_numbered_ruler.var:vptl_presidential_order_number } }'
Add-Line $e '\t\tremove_variable = vptl_presidential_history_number_gap'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_capture_presidential_history_episode_data = {'
foreach ($field in @('president','vice_president','party','ig')) { Add-Line $e "\tremove_variable = vptl_history_capture_$field" }
Add-Line $e '\tset_variable = { name = vptl_history_capture_number value = 0 }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_accession_type value = 5 }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_gdp_start value = gdp }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_population_start value = total_population }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_sol_start value = average_sol }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_prestige_start value = prestige }'
Add-Line $e '\tvptl_capture_presidential_history_power_rank = yes'
Add-Line $e '\tvptl_capture_presidential_history_numeric_rank = yes'
Add-Line $e '\tvptl_capture_presidential_history_date = yes'
Add-Line $e '\truler ?= { save_scope_as = vptl_history_capture_president }'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { exists = scope:vptl_history_capture_president }'
Add-Line $e '\t\tset_variable = { name = vptl_history_capture_president value = scope:vptl_history_capture_president }'
Add-Line $e '\t\tscope:vptl_history_capture_president = { if = { limit = { is_character_alive = yes NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject } }'
Add-Line $e '\t\tif = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_order_number } } set_variable = { name = vptl_history_capture_number value = scope:vptl_history_capture_president.var:vptl_presidential_order_number } }'
Add-Line $e '\t\tif = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_elected } } set_variable = { name = vptl_history_capture_accession_type value = 1 } }'
Add-Line $e '\t\telse_if = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_succeeded } } set_variable = { name = vptl_history_capture_accession_type value = 2 } }'
Add-Line $e '\t\telse_if = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_interim } } set_variable = { name = vptl_history_capture_accession_type value = 3 } }'
Add-Line $e '\t\telse_if = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_provisional } } set_variable = { name = vptl_history_capture_accession_type value = 4 } }'
Add-Line $e '\t\tscope:vptl_history_capture_president = { this.interest_group ?= { save_scope_as = vptl_history_capture_ig party ?= { save_scope_as = vptl_history_capture_party } } }'
Add-Line $e '\t}'
Add-Line $e '\t# The first tracked USA episode is Jackson''s real presidency, begun March 1829.'
Add-Line $e '\tif = { limit = { this = c:USA NOT = { has_variable = vptl_presidential_history_slot_1_populated } scope:vptl_history_capture_president ?= { OR = { has_variable = is_andrew_jackson has_template = usa_andrew_jackson_template } } } set_variable = { name = vptl_history_capture_year value = 1829 } set_variable = { name = vptl_history_capture_month value = 3 } }'
Add-Line $e '\tif = { limit = { exists = scope:vptl_history_capture_ig } set_variable = { name = vptl_history_capture_ig value = scope:vptl_history_capture_ig } }'
Add-Line $e '\tif = { limit = { exists = scope:vptl_history_capture_party } set_variable = { name = vptl_history_capture_party value = scope:vptl_history_capture_party } }'
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_successor var:vptl_presidential_successor ?= { is_character_alive = yes } } var:vptl_presidential_successor ?= { if = { limit = { NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject } } set_variable = { name = vptl_history_capture_vice_president value = var:vptl_presidential_successor } }'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_copy_presidential_history_recent_slot = {'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { has_variable = vptl_presidential_history_recent_$FROM$_populated }'
Copy-VariableBlock $e 'vptl_presidential_history_recent_$FROM$' 'vptl_presidential_history_recent_$TO$' $allFields '\t\t'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_recent_$FROM$_closed } set_variable = vptl_presidential_history_recent_$TO$_closed } else = { remove_variable = vptl_presidential_history_recent_$TO$_closed }'
Add-Line $e '\t\tset_variable = vptl_presidential_history_recent_$TO$_populated'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_shift_presidential_history_recent_cache = {'
for ($i=49; $i -ge 1; $i--) { Add-Line $e ("\tvptl_copy_presidential_history_recent_slot = {{ FROM = {0} TO = {1} }}" -f $i,($i+1)) }
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_recent_count } } set_variable = { name = vptl_presidential_history_recent_count value = 0 } }'
Add-Line $e '\tif = { limit = { var:vptl_presidential_history_recent_count < 50 } change_variable = { name = vptl_presidential_history_recent_count add = 1 } }'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_copy_history_capture_to_recent_1 = {'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_president value = var:vptl_history_capture_president }'
foreach ($f in @('vice_president','party','ig')) { Add-Line $e "\tif = { limit = { has_variable = vptl_history_capture_$f } set_variable = { name = vptl_presidential_history_recent_1_$f value = var:vptl_history_capture_$f } } else = { remove_variable = vptl_presidential_history_recent_1_$f }" }
foreach ($f in @('number','accession_type')) { Add-Line $e "\tset_variable = { name = vptl_presidential_history_recent_1_$f value = var:vptl_history_capture_$f }" }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_departure_reason value = 0 }'
foreach ($f in @('gdp','population','sol','prestige')) { Add-Line $e "\tset_variable = { name = vptl_presidential_history_recent_1_${f}_start value = var:vptl_history_capture_${f}_start }"; Add-Line $e "\tremove_variable = vptl_presidential_history_recent_1_${f}_end" }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_rank_start value = var:vptl_history_capture_rank }'
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_rank_end'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_score_rank_start value = var:vptl_history_capture_score_rank }'
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_score_rank_end'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_start_year value = var:vptl_history_capture_year }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_start_month value = var:vptl_history_capture_month }'
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_end_year'
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_end_month'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_law_count value = 0 }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_law_overflow_count value = 0 }'
for ($i=1;$i -le 8;$i++) { Add-Line $e "\tremove_variable = vptl_presidential_history_recent_1_law_$i" }
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_closed'
Add-Line $e '\tset_variable = vptl_presidential_history_recent_1_populated'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_copy_history_capture_to_archive_slot = {'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_president value = var:vptl_history_capture_president }'
foreach ($f in @('vice_president','party','ig')) { Add-Line $e "\tif = { limit = { has_variable = vptl_history_capture_$f } set_variable = { name = vptl_presidential_history_slot_`$SLOT`$_$f value = var:vptl_history_capture_$f } }".Replace('`$','$') }
foreach ($f in @('number','accession_type')) { Add-Line $e "\tset_variable = { name = vptl_presidential_history_slot_`$SLOT`$_$f value = var:vptl_history_capture_$f }".Replace('`$','$') }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_departure_reason value = 0 }'
foreach ($f in @('gdp','population','sol','prestige')) { Add-Line $e ("\tset_variable = {{ name = vptl_presidential_history_slot_`$SLOT`$_{0}_start value = var:vptl_history_capture_{0}_start }}" -f $f).Replace('`$','$') }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_rank_start value = var:vptl_history_capture_rank }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_score_rank_start value = var:vptl_history_capture_score_rank }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_start_year value = var:vptl_history_capture_year }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_start_month value = var:vptl_history_capture_month }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_law_count value = 0 }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_law_overflow_count value = 0 }'
Add-Line $e '\tset_variable = vptl_presidential_history_slot_$SLOT$_active'
Add-Line $e '\tset_variable = vptl_presidential_history_slot_$SLOT$_populated'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_open_presidential_history_episode = {'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { vptl_presidential_transition_qualifies = yes ruler ?= { is_character_alive = yes } NOT = { has_variable = vptl_presidential_history_current_slot } OR = { has_variable = vptl_presidential_history_committed_change has_variable = vptl_presidential_history_pending_constitutional_accession AND = { NOT = { in_election_campaign = yes } NOT = { has_variable = vptl_presidential_election_transition } NOT = { has_variable = vptl_presidential_election_settlement_in_progress } NOT = { has_variable = vptl_presidential_inauguration_pending } NOT = { has_variable = vptl_presidential_inauguration_in_progress } NOT = { has_variable = vptl_presidential_handoff_in_progress } } } }'
Add-Line $e '\t\tvptl_prepare_presidential_history_episode_number = yes'
Add-Line $e '\t\tvptl_capture_presidential_history_episode_data = yes'
Add-Line $e '\t\tif = {'
Add-Line $e '\t\t\tlimit = { has_variable = vptl_history_capture_president }'
Add-Line $e '\t\t\tvptl_shift_presidential_history_recent_cache = yes'
Add-Line $e '\t\t\tvptl_copy_history_capture_to_recent_1 = yes'
for ($i=1;$i -le 128;$i++) { $kw=if($i -eq 1){'if'}else{'else_if'}; Add-Line $e ("\t\t\t{0} = {{ limit = {{ NOT = {{ has_variable = vptl_presidential_history_slot_{1}_populated }} }} set_variable = {{ name = vptl_presidential_history_current_slot value = {1} }} vptl_copy_history_capture_to_archive_slot = {{ SLOT = {1} }} }}" -f $kw,$i) }
Add-Line $e '\t\t\tif = { limit = { has_variable = vptl_presidential_history_current_slot } set_variable = { name = vptl_presidential_history_current_president value = var:vptl_history_capture_president } clear_variable_list = vptl_presidential_history_active_laws_seen }'
Add-Line $e '\t\t\telse = { remove_variable = vptl_presidential_history_recent_1_populated }'
Add-Line $e '\t\t}'
Add-Line $e '\t}'
foreach ($f in @('president','vice_president','party','ig','number','accession_type','gdp_start','population_start','sol_start','prestige_start','rank','score_rank','year','month')) { Add-Line $e "\tremove_variable = vptl_history_capture_$f" }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_finalize_presidential_history_archive_slot = {'
Add-Line $e '\tif = { limit = { var:vptl_presidential_history_current_slot = $SLOT$ has_variable = vptl_presidential_history_slot_$SLOT$_active NOT = { has_variable = vptl_presidential_history_slot_$SLOT$_closed } }'
foreach ($f in @('gdp','total_population','average_sol','prestige')) { $name=@{'gdp'='gdp';'total_population'='population';'average_sol'='sol';'prestige'='prestige'}[$f]; Add-Line $e "\t\tset_variable = { name = vptl_presidential_history_slot_`$SLOT`$_${name}_end value = $f }".Replace('`$','$') }
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_rank_end value = var:vptl_history_capture_rank }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_score_rank_end value = var:vptl_history_capture_score_rank }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_departure_reason value = var:vptl_presidential_history_departure_reason }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_end_year value = var:vptl_history_capture_year }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_end_month value = var:vptl_history_capture_month }'
Add-Line $e '\t\tset_variable = vptl_presidential_history_slot_$SLOT$_closed remove_variable = vptl_presidential_history_slot_$SLOT$_active'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_preserve_presidential_history_subjects_before_close = {'
Add-Line $e '\t# The ledger''s exact stored subjects are authoritative, not a transition helper scope.'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { has_variable = vptl_presidential_history_current_president }'
Add-Line $e '\t\tvar:vptl_presidential_history_current_president ?= {'
Add-Line $e '\t\t\tif = { limit = { is_character_alive = yes NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject }'
Add-Line $e '\t\t\tif = { limit = { is_character_alive = yes NOT = { has_role = character_role_vptl_former_president } } add_character_role = character_role_vptl_former_president }'
Add-Line $e '\t\t}'
Add-Line $e '\t}'
Add-Line $e '\tif = {'
Add-Line $e '\t\tlimit = { has_variable = vptl_presidential_history_recent_1_vice_president }'
Add-Line $e '\t\tvar:vptl_presidential_history_recent_1_vice_president ?= { if = { limit = { is_character_alive = yes NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject } }'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_request_close_presidential_history_episode = {'
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_history_current_slot NOT = { has_variable = vptl_presidential_history_close_in_progress } }'
Add-Line $e '\t\tset_variable = vptl_presidential_history_close_in_progress'
Add-Line $e '\t\tvptl_preserve_presidential_history_subjects_before_close = yes'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = vptl_presidential_history_departure_reason } } set_variable = { name = vptl_presidential_history_departure_reason value = 7 } }'
Add-Line $e '\t\tvptl_capture_presidential_history_date = yes'
Add-Line $e '\t\tvptl_capture_presidential_history_power_rank = yes'
Add-Line $e '\t\tvptl_capture_presidential_history_numeric_rank = yes'
for ($i=1;$i -le 128;$i++) { Add-Line $e "\t\tvptl_finalize_presidential_history_archive_slot = { SLOT = $i }" }
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_recent_1_populated NOT = { has_variable = vptl_presidential_history_recent_1_closed } }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_gdp_end value = gdp } set_variable = { name = vptl_presidential_history_recent_1_population_end value = total_population } set_variable = { name = vptl_presidential_history_recent_1_sol_end value = average_sol } set_variable = { name = vptl_presidential_history_recent_1_prestige_end value = prestige }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_rank_end value = var:vptl_history_capture_rank } set_variable = { name = vptl_presidential_history_recent_1_score_rank_end value = var:vptl_history_capture_score_rank }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_departure_reason value = var:vptl_presidential_history_departure_reason } set_variable = { name = vptl_presidential_history_recent_1_end_year value = var:vptl_history_capture_year } set_variable = { name = vptl_presidential_history_recent_1_end_month value = var:vptl_history_capture_month } set_variable = vptl_presidential_history_recent_1_closed'
Add-Line $e '\t\t}'
Add-Line $e '\t\tif = {'
Add-Line $e '\t\t\tlimit = { has_variable = vptl_presidential_history_current_president }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_previous_president value = var:vptl_presidential_history_current_president }'
Add-Line $e '\t\t\tif = { limit = { var:vptl_presidential_history_current_president ?= { has_variable = vptl_presidential_order_number } } set_variable = { name = vptl_presidential_history_previous_number value = var:vptl_presidential_history_current_president.var:vptl_presidential_order_number } }'
Add-Line $e '\t\t}'
Add-Line $e '\t\tclear_variable_list = vptl_presidential_history_active_laws_seen remove_variable = vptl_presidential_history_current_slot remove_variable = vptl_presidential_history_current_president remove_variable = vptl_presidential_history_departure_reason remove_variable = vptl_history_capture_year remove_variable = vptl_history_capture_month remove_variable = vptl_history_capture_rank remove_variable = vptl_history_capture_score_rank remove_variable = vptl_presidential_history_close_in_progress'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_refresh_presidential_history_archive_slot = {'
Add-Line $e '\tif = { limit = { var:vptl_presidential_history_current_slot = $SLOT$ has_variable = vptl_presidential_history_slot_$SLOT$_active }'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_successor } var:vptl_presidential_successor ?= { if = { limit = { is_character_alive = yes NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject } } set_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president value = var:vptl_presidential_successor } } else = { remove_variable = vptl_presidential_history_slot_$SLOT$_vice_president }'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_refresh_open_presidential_history_episode = {'
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_history_current_slot has_variable = vptl_presidential_history_current_president NOT = { has_variable = vptl_presidential_history_close_in_progress } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e "\t\tvptl_refresh_presidential_history_archive_slot = { SLOT = $i }" }
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_successor } var:vptl_presidential_successor ?= { if = { limit = { is_character_alive = yes NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject } } set_variable = { name = vptl_presidential_history_recent_1_vice_president value = var:vptl_presidential_successor } } else = { remove_variable = vptl_presidential_history_recent_1_vice_president }'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_record_presidential_history_law_in_archive_slot = {'
Add-Line $e '\tif = { limit = { var:vptl_presidential_history_current_slot = $SLOT$ has_variable = vptl_presidential_history_slot_$SLOT$_active }'
Add-Line $e '\t\tchange_variable = { name = vptl_presidential_history_slot_$SLOT$_law_count add = 1 }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_recent_1_law_count value = var:vptl_presidential_history_slot_$SLOT$_law_count }'
for ($i=1;$i -le 8;$i++) { $kw=if($i -eq 1){'if'}else{'else_if'}; Add-Line $e ("\t\t{0} = {{ limit = {{ var:vptl_presidential_history_slot_`$SLOT`$_law_count = {1} }} set_variable = {{ name = vptl_presidential_history_slot_`$SLOT`$_law_{1} value = var:vptl_presidential_history_pending_law }} set_variable = {{ name = vptl_presidential_history_recent_1_law_{1} value = var:vptl_presidential_history_pending_law }} }}" -f $kw,$i).Replace('`$','$') }
Add-Line $e '\t\telse = { change_variable = { name = vptl_presidential_history_slot_$SLOT$_law_overflow_count add = 1 } set_variable = { name = vptl_presidential_history_recent_1_law_overflow_count value = var:vptl_presidential_history_slot_$SLOT$_law_overflow_count } }'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_record_law_for_active_presidential_history = {'
Add-Line $e '\tif = { limit = { vptl_presidential_transition_qualifies = yes has_variable = vptl_presidential_history_current_slot has_variable = vptl_presidential_history_current_president has_variable = vptl_presidential_history_pending_law ruler ?= { owner.var:vptl_presidential_history_current_president ?= this } NOT = { is_target_in_variable_list = { name = vptl_presidential_history_active_laws_seen target = var:vptl_presidential_history_pending_law } } }'
Add-Line $e '\t\tadd_to_variable_list = { name = vptl_presidential_history_active_laws_seen target = var:vptl_presidential_history_pending_law }'
for ($i=1;$i -le 128;$i++) { Add-Line $e "\t\tvptl_record_presidential_history_law_in_archive_slot = { SLOT = $i }" }
Add-Line $e '\t}'
Add-Line $e '\tremove_variable = vptl_presidential_history_pending_law'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_copy_presidential_history_recent_to_display_slot = {'
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_history_recent_$SLOT$_populated }'
Copy-VariableBlock $e 'vptl_presidential_history_recent_$SLOT$' 'vptl_presidential_history_display_$SLOT$' $allFields '\t\t'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_recent_$SLOT$_closed } set_variable = { name = vptl_presidential_history_display_$SLOT$_closed value = 1 } } else = { set_variable = { name = vptl_presidential_history_display_$SLOT$_closed value = 0 } }'
foreach ($metric in @('gdp','population')) {
	Add-Line $e "\t\tremove_variable = vptl_presidential_history_display_`$SLOT`$_${metric}_change_available".Replace('`$','$')
	Add-Line $e "\t\tremove_variable = vptl_presidential_history_display_`$SLOT`$_${metric}_change_percent".Replace('`$','$')
	Add-Line $e ("\t\tif = {{ limit = {{ has_variable = vptl_presidential_history_recent_`$SLOT`$_closed has_variable = vptl_presidential_history_recent_`$SLOT`$_{0}_end var:vptl_presidential_history_recent_`$SLOT`$_{0}_start > 0 }} set_variable = {{ name = vptl_presidential_history_display_`$SLOT`$_{0}_change_percent value = var:vptl_presidential_history_recent_`$SLOT`$_{0}_end }} change_variable = {{ name = vptl_presidential_history_display_`$SLOT`$_{0}_change_percent subtract = var:vptl_presidential_history_recent_`$SLOT`$_{0}_start }} change_variable = {{ name = vptl_presidential_history_display_`$SLOT`$_{0}_change_percent divide = var:vptl_presidential_history_recent_`$SLOT`$_{0}_start }} change_variable = {{ name = vptl_presidential_history_display_`$SLOT`$_{0}_change_percent multiply = 100 }} set_variable = vptl_presidential_history_display_`$SLOT`$_{0}_change_available }}" -f $metric).Replace('`$','$')
}
Add-Line $e '\t\tset_variable = vptl_presidential_history_display_$SLOT$_populated'
Add-Line $e '\t}'
Add-Line $e '\telse = {'
foreach ($f in $allFields + @('closed','populated','gdp_change_available','gdp_change_percent','population_change_available','population_change_percent')) { Add-Line $e "\t\tremove_variable = vptl_presidential_history_display_`$SLOT`$_$f".Replace('`$','$') }
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_load_presidential_history_latest_50 = {'
Add-Line $e '\tvptl_refresh_open_presidential_history_episode = yes'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_display_count value = 0 }'
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_history_recent_count } set_variable = { name = vptl_presidential_history_display_count value = var:vptl_presidential_history_recent_count } }'
for ($i=1;$i -le 50;$i++) { Add-Line $e "\tvptl_copy_presidential_history_recent_to_display_slot = { SLOT = $i }" }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_sync_presidential_history_after_ruler_change = {'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_sync_in_progress } } set_variable = vptl_presidential_history_sync_in_progress'
Add-Line $e '\t\tif = { limit = { NOT = { vptl_presidential_transition_qualifies = yes } has_variable = vptl_presidential_history_current_slot } set_variable = { name = vptl_presidential_history_departure_reason value = 6 } vptl_request_close_presidential_history_episode = yes }'
Add-Line $e '\t\telse_if = { limit = { vptl_presidential_transition_qualifies = yes OR = { has_variable = vptl_presidential_history_committed_change has_variable = vptl_presidential_history_pending_constitutional_accession AND = { NOT = { in_election_campaign = yes } NOT = { has_variable = vptl_presidential_election_transition } NOT = { has_variable = vptl_presidential_election_settlement_in_progress } NOT = { has_variable = vptl_presidential_inauguration_pending } NOT = { has_variable = vptl_presidential_inauguration_in_progress } NOT = { has_variable = vptl_presidential_handoff_in_progress } } } }'
Add-Line $e '\t\t\tif = { limit = { has_variable = vptl_presidential_history_current_slot OR = { NOT = { ruler ?= { is_character_alive = yes } } NOT = { has_variable = vptl_presidential_history_current_president } ruler ?= { NOT = { owner.var:vptl_presidential_history_current_president ?= this } } } } if = { limit = { NOT = { has_variable = vptl_presidential_history_departure_reason } } set_variable = { name = vptl_presidential_history_departure_reason value = 5 } } vptl_request_close_presidential_history_episode = yes }'
Add-Line $e '\t\t\tif = { limit = { NOT = { has_variable = vptl_presidential_history_current_slot } ruler ?= { is_character_alive = yes } } vptl_open_presidential_history_episode = yes if = { limit = { has_variable = vptl_presidential_history_current_slot } remove_variable = vptl_presidential_history_pending_constitutional_accession } }'
Add-Line $e '\t\t}'
Add-Line $e '\t\tremove_variable = vptl_presidential_history_sync_in_progress'
Add-Line $e '\t}'
Add-Line $e '}'

$effectsText = (($e -join "`r`n") + "`r`n").Replace('\t', "`t")
[System.IO.File]::WriteAllText($effectsPath, $effectsText, $utf8Bom)

# The GUI is generated separately below so all 50 fixed cards stay identical.
$g = [System.Collections.Generic.List[string]]::new()
Add-Line $g 'window = {'; Add-Line $g '\tname = "vptl_presidential_history_window"'; Add-Line $g '\tlayer = top'; Add-Line $g '\tparentanchor = center'; Add-Line $g '\tsize = { 1040 850 }'; Add-Line $g '\tallow_outside = yes'; Add-Line $g '\tvisible = "[And(GetVariableSystem.Exists(''vptl_presidential_history_panel_open''), GetMetaPlayer.GetPlayedOrObservedCountry.IsValid)]"'; Add-Line $g '\tdatacontext = "[GetMetaPlayer.GetPlayedOrObservedCountry]"'; Add-Line $g '\tbackground = { using = paper_bg }'
Add-Line $g '\tvbox = {'; Add-Line $g '\t\tmargin = { 24 18 }'; Add-Line $g '\t\tspacing = 7'; Add-Line $g '\t\tlayoutpolicy_horizontal = expanding'; Add-Line $g '\t\tlayoutpolicy_vertical = expanding'; Add-Line $g '\t\thbox = {'; Add-Line $g '\t\t\tlayoutpolicy_horizontal = expanding'; Add-Line $g '\t\t\tsize = { 992 42 }'; Add-Line $g '\t\t\ttextbox = { text = "vptl_presidential_library_title" fontsize = 28 align = center|nobaseline layoutpolicy_horizontal = expanding }'; Add-Line $g '\t\t\tbutton = { size = { 36 36 } using = default_button_primary onclick = "[GetVariableSystem.Clear(''vptl_presidential_history_panel_open'')]" icon = { parentanchor = center size = { 22 22 } texture = "gfx/interface/buttons/button_icons/close.dds" } }'; Add-Line $g '\t\t}'
Add-Line $g '\t\ttextbox = { visible = "[LessThan_CFixedPoint(Country.MakeScope.Var(''vptl_presidential_history_display_count'').GetValue, ''(CFixedPoint)1'')]" layoutpolicy_horizontal = expanding size = { 992 80 } text = "vptl_presidential_history_empty" align = center|nobaseline fontsize = 18 }'
Add-Line $g '\t\tscrollarea = {'; Add-Line $g '\t\t\tvisible = "[GreaterThanOrEqualTo_CFixedPoint(Country.MakeScope.Var(''vptl_presidential_history_display_count'').GetValue, ''(CFixedPoint)1'')]"'; Add-Line $g '\t\t\tsize = { 992 770 }'; Add-Line $g '\t\t\tscrollbarpolicy_horizontal = always_off'; Add-Line $g '\t\t\tscrollbaralign_vertical = right'; Add-Line $g '\t\t\tscrollbar_vertical = { using = vertical_scrollbar }'; Add-Line $g '\t\t\tscrollwidget = {'; Add-Line $g '\t\t\t\tvbox = {'; Add-Line $g '\t\t\t\t\tlayoutpolicy_horizontal = expanding'; Add-Line $g '\t\t\t\t\tlayoutpolicy_vertical = preferred'; Add-Line $g '\t\t\t\t\tspacing = 5'
# Retained below as a layout reference; the polished cards are emitted by the loop after it.
for ($s=51;$s -le 50;$s++) {
	$p="vptl_presidential_history_display_${s}"
	Add-Line $g '\t\t\t\t\twidget = {'; Add-Line $g ("\t\t\t\t\t\tvisible = `"[And(GreaterThanOrEqualTo_CFixedPoint(Country.MakeScope.Var('{0}_count').GetValue, '(CFixedPoint){1}'), Country.MakeScope.Var('{2}_populated').IsSet)]`"" -f 'vptl_presidential_history_display',$s,$p); Add-Line $g '\t\t\t\t\t\tsize = { 964 116 }'; Add-Line $g '\t\t\t\t\t\tbackground = { using = entry_bg_fancy_dark alpha = 0.38 }'; Add-Line $g '\t\t\t\t\t\thbox = {'; Add-Line $g '\t\t\t\t\t\t\tmargin = { 10 7 }'; Add-Line $g '\t\t\t\t\t\t\tspacing = 10'
	Add-Line $g ("\t\t\t\t\t\t\tcharacter_portrait_small2 = {{ visible = `"[Country.MakeScope.Var('{0}_president').GetCharacter.IsValid]`" datacontext = `"[Country.MakeScope.Var('{0}_president').GetCharacter]`" }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\ticon = {{ visible = `"[Not(Country.MakeScope.Var('{0}_president').GetCharacter.IsValid)]`" size = {{ 60 60 }} texture = `"gfx/interface/icons/generic_icons/historical_character_icon.dds`" }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\tvbox = {'; Add-Line $g '\t\t\t\t\t\t\t\tspacing = 1'
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_president').GetCharacter.IsValid]`" size = {{ 260 21 }} raw_text = `"#BOLD [Country.MakeScope.Var('{0}_president').GetCharacter.GetFullName]#!`" fontsize = 16 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_president').GetCharacter.IsValid)]`" size = {{ 260 21 }} text = `"vptl_presidential_history_unavailable_president`" fontsize = 16 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 62 20 }} raw_text = `"No. [Country.MakeScope.Var('{0}_number').GetValue|0]`" fontsize = 12 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_closed').GetValue, '(CFixedPoint)0'))]`" size = {{ 126 20 }} text = `"vptl_presidential_history_current_episode`" fontsize = 12 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_closed').GetValue, '(CFixedPoint)0')]`" size = {{ 126 20 }} text = `"vptl_presidential_history_former_episode`" fontsize = 12 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_closed').GetValue, '(CFixedPoint)0'))]`" size = {{ 190 20 }} raw_text = `"Since [Country.MakeScope.Var('{0}_start_month').GetValue|0]/[Country.MakeScope.Var('{0}_start_year').GetValue|0]`" fontsize = 12 align = right|nobaseline }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_closed').GetValue, '(CFixedPoint)0')]`" size = {{ 190 20 }} raw_text = `"[Country.MakeScope.Var('{0}_start_month').GetValue|0]/[Country.MakeScope.Var('{0}_start_year').GetValue|0] - [Country.MakeScope.Var('{0}_end_month').GetValue|0]/[Country.MakeScope.Var('{0}_end_year').GetValue|0]`" fontsize = 12 align = right|nobaseline }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	for ($i=0;$i -le 5;$i++) { $key=@('vptl_presidential_history_accession_unrecorded','vptl_presidential_history_accession_elected','vptl_presidential_history_accession_succeeded','vptl_presidential_history_accession_interim','vptl_presidential_history_accession_provisional','vptl_presidential_history_accession_initial')[$i]; Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_accession_type').GetValue, '(CFixedPoint){1}')]`" size = {{ 275 18 }} text = `"{2}`" fontsize = 11 elide = right }}" -f $p,$i,$key) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_closed').GetValue, '(CFixedPoint)0'))]`" size = {{ 280 18 }} text = `"vptl_presidential_history_departure_open`" fontsize = 11 elide = right }}" -f $p)
	for ($i=1;$i -le 7;$i++) { $key=@('','vptl_presidential_history_departure_death','vptl_presidential_history_departure_lost_election','vptl_presidential_history_departure_term_limited','vptl_presidential_history_departure_election_handoff','vptl_presidential_history_departure_removed','vptl_presidential_history_departure_system_ended','vptl_presidential_history_departure_unknown')[$i]; Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[And(GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_closed').GetValue, '(CFixedPoint)0'), EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_departure_reason').GetValue, '(CFixedPoint){1}'))]`" size = {{ 280 18 }} text = `"{2}`" fontsize = 11 elide = right }}" -f $p,$i,$key) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 80 18 }} text = `"vptl_presidential_history_vp_compact`" fontsize = 11 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_vice_president').GetCharacter.IsValid]`" size = {{ 190 18 }} raw_text = `"[Country.MakeScope.Var('{0}_vice_president').GetCharacter.GetFullName]`" fontsize = 11 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_vice_president').GetCharacter.IsValid)]`" size = {{ 190 18 }} text = `"vptl_presidential_history_unavailable_vice_president`" fontsize = 11 elide = right }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	Add-Line $g ("\t\t\t\t\t\t\t\t\tparty_icon = {{ visible = `"[Country.MakeScope.Var('{0}_party').GetParty.IsValid]`" size = {{ 18 18 }} datacontext = `"[Country.MakeScope.Var('{0}_party').GetParty]`" }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_party').GetParty.IsValid]`" size = {{ 165 18 }} raw_text = `"[Country.MakeScope.Var('{0}_party').GetParty.GetName]`" fontsize = 11 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_party').GetParty.IsValid)]`" size = {{ 183 18 }} text = `"vptl_presidential_history_unavailable_party`" fontsize = 11 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\tig_icon = {{ visible = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup.IsValid]`" size = {{ 18 18 }} datacontext = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup]`" }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup.IsValid]`" size = {{ 160 18 }} raw_text = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup.GetName]`" fontsize = 11 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_ig').GetInterestGroup.IsValid)]`" size = {{ 178 18 }} text = `"vptl_presidential_history_unavailable_ig`" fontsize = 11 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 86 18 }} raw_text = `"Terms: [Country.MakeScope.Var('{0}_terms_at_end').GetValue|0]`" fontsize = 11 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 170 18 }} raw_text = `"GDP: [Country.MakeScope.Var('{0}_gdp_start').GetValue|D] - [Country.MakeScope.Var('{0}_gdp_end').GetValue|D]`" fontsize = 11 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_gdp_change_available').IsSet]`" size = {{ 72 18 }} raw_text = `"([Country.MakeScope.Var('{0}_gdp_change_percent').GetValue|1]%)`" fontsize = 11 }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 205 18 }} raw_text = `"Pop: [Country.MakeScope.Var('{0}_population_start').GetValue|D] - [Country.MakeScope.Var('{0}_population_end').GetValue|D]`" fontsize = 11 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_population_change_available').IsSet]`" size = {{ 72 18 }} raw_text = `"([Country.MakeScope.Var('{0}_population_change_percent').GetValue|1]%)`" fontsize = 11 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 145 18 }} raw_text = `"SoL: [Country.MakeScope.Var('{0}_sol_start').GetValue|1] - [Country.MakeScope.Var('{0}_sol_end').GetValue|1]`" fontsize = 11 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 150 18 }} raw_text = `"Prestige: [Country.MakeScope.Var('{0}_prestige_start').GetValue|0] - [Country.MakeScope.Var('{0}_prestige_end').GetValue|0]`" fontsize = 11 }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t\ttextbox = { size = { 34 18 } text = "vptl_presidential_history_laws_compact" fontsize = 11 }'
	for ($i=1;$i -le 8;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\tlaw_icon = {{ visible = `"[Country.MakeScope.Var('{0}_law_{1}').GetLaw.IsValid]`" size = {{ 18 18 }} datacontext = `"[Country.MakeScope.Var('{0}_law_{1}').GetLaw]`" tooltipwidget = {{ FancyTooltip_Law = {{}} }} }}" -f $p,$i) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_law_overflow_count').GetValue, '(CFixedPoint)0')]`" size = {{ 38 18 }} raw_text = `"+[Country.MakeScope.Var('{0}_law_overflow_count').GetValue|0]`" fontsize = 11 }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'
	# Rank category appears as a fifth compact line only through localized alternatives.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'; Add-Line $g '\t\t\t\t\t\t\t\t\ttextbox = { size = { 42 16 } text = "vptl_presidential_history_rank_compact" fontsize = 10 }'
	for ($i=0;$i -le 7;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_rank_start').GetValue, '(CFixedPoint){1}')]`" size = {{ 150 16 }} text = `"vptl_presidential_history_rank_{1}`" fontsize = 10 }}" -f $p,$i) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[LessThan_CFixedPoint(Country.MakeScope.Var('{0}_rank_start').GetValue, '(CFixedPoint)0')]`" size = {{ 150 16 }} text = `"vptl_presidential_history_rank_unavailable`" fontsize = 10 }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t\ttextbox = { size = { 14 16 } text = " → " fontsize = 10 }'
	for ($i=0;$i -le 7;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_rank_end').GetValue, '(CFixedPoint){1}')]`" size = {{ 150 16 }} text = `"vptl_presidential_history_rank_{1}`" fontsize = 10 }}" -f $p,$i) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[LessThan_CFixedPoint(Country.MakeScope.Var('{0}_rank_end').GetValue, '(CFixedPoint)0')]`" size = {{ 150 16 }} text = `"vptl_presidential_history_rank_unavailable`" fontsize = 10 }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'; Add-Line $g '\t\t\t\t\t\t\t}'; Add-Line $g '\t\t\t\t\t\t}'; Add-Line $g '\t\t\t\t\t}'
}
for ($s=1;$s -le 50;$s++) {
	$p="vptl_presidential_history_display_${s}"
	$closed="GreaterThan_CFixedPoint(Country.MakeScope.Var('${p}_closed').GetValue, '(CFixedPoint)0')"
	$open="Not($closed)"
	Add-Line $g '\t\t\t\t\twidget = {'
	Add-Line $g ("\t\t\t\t\t\tvisible = `"[And(GreaterThanOrEqualTo_CFixedPoint(Country.MakeScope.Var('vptl_presidential_history_display_count').GetValue, '(CFixedPoint){0}'), Country.MakeScope.Var('{1}_populated').IsSet)]`"" -f $s,$p)
	Add-Line $g '\t\t\t\t\t\tsize = { 964 128 }'
	Add-Line $g '\t\t\t\t\t\tbackground = { using = entry_bg_fancy_dark alpha = 0.38 }'
	Add-Line $g '\t\t\t\t\t\thbox = {'; Add-Line $g '\t\t\t\t\t\t\tmargin = { 10 7 }'; Add-Line $g '\t\t\t\t\t\t\tspacing = 10'
	Add-Line $g ("\t\t\t\t\t\t\tcharacter_portrait_small2 = {{ visible = `"[Country.MakeScope.Var('{0}_president').GetCharacter.IsValid]`" datacontext = `"[Country.MakeScope.Var('{0}_president').GetCharacter]`" }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\ticon = {{ visible = `"[Not(Country.MakeScope.Var('{0}_president').GetCharacter.IsValid)]`" size = {{ 60 60 }} texture = `"gfx/interface/icons/generic_icons/historical_character_icon.dds`" }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\tvbox = {'; Add-Line $g '\t\t\t\t\t\t\t\tspacing = 2'

	# Header: immutable episode identity, number, and service span.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_president').GetCharacter.IsValid]`" size = {{ 420 24 }} raw_text = `"#BOLD [Country.MakeScope.Var('{0}_president').GetCharacter.GetFullName]#!`" fontsize = 18 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_president').GetCharacter.IsValid)]`" size = {{ 420 24 }} text = `"vptl_presidential_history_unavailable_president`" fontsize = 18 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 100 22 }} raw_text = `"No. [Country.MakeScope.Var('{0}_number').GetValue|0]`" fontsize = 14 }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 340 22 }} raw_text = `"[Country.MakeScope.Var('{1}_start_month').GetValue|0]/[Country.MakeScope.Var('{1}_start_year').GetValue|0] - Present`" fontsize = 14 align = right|nobaseline }}" -f $open,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 340 22 }} raw_text = `"[Country.MakeScope.Var('{1}_start_month').GetValue|0]/[Country.MakeScope.Var('{1}_start_year').GetValue|0] - [Country.MakeScope.Var('{1}_end_month').GetValue|0]/[Country.MakeScope.Var('{1}_end_year').GetValue|0]`" fontsize = 14 align = right|nobaseline }}" -f $closed,$p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'

	# Accession/departure and the country-specific constitutional deputy title.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	for ($i=0;$i -le 5;$i++) { $key=@('vptl_presidential_history_accession_unrecorded','vptl_presidential_history_accession_elected','vptl_presidential_history_accession_succeeded','vptl_presidential_history_accession_interim','vptl_presidential_history_accession_provisional','vptl_presidential_history_accession_initial')[$i]; Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_accession_type').GetValue, '(CFixedPoint){1}')]`" size = {{ 280 20 }} text = `"{2}`" fontsize = 13 elide = right }}" -f $p,$i,$key) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 300 20 }} text = `"vptl_presidential_history_departure_open`" fontsize = 13 elide = right }}" -f $open)
	for ($i=1;$i -le 7;$i++) { $key=@('','vptl_presidential_history_departure_death','vptl_presidential_history_departure_lost_election','vptl_presidential_history_departure_term_limited','vptl_presidential_history_departure_election_handoff','vptl_presidential_history_departure_removed','vptl_presidential_history_departure_system_ended','vptl_presidential_history_departure_unknown')[$i]; Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[And({0}, EqualTo_CFixedPoint(Country.MakeScope.Var('{1}_departure_reason').GetValue, '(CFixedPoint){2}'))]`" size = {{ 300 20 }} text = `"{3}`" fontsize = 13 elide = right }}" -f $closed,$p,$i,$key) }
	Add-Line $g '\t\t\t\t\t\t\t\t\ttextbox = { size = { 180 20 } raw_text = "[GetPlayer.GetCustom(''vptl_presidential_successor_title'')]:" fontsize = 13 elide = right }'
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_vice_president').GetCharacter.IsValid]`" size = {{ 100 20 }} raw_text = `"[Country.MakeScope.Var('{0}_vice_president').GetCharacter.GetFullName]`" fontsize = 13 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_vice_president').GetCharacter.IsValid)]`" size = {{ 100 20 }} text = `"vptl_presidential_history_unavailable_vice_president`" fontsize = 13 elide = right }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'

	# Political affiliations plus boundary-frozen GDP and population.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	Add-Line $g ("\t\t\t\t\t\t\t\t\tparty_icon = {{ visible = `"[Country.MakeScope.Var('{0}_party').GetParty.IsValid]`" size = {{ 18 18 }} datacontext = `"[Country.MakeScope.Var('{0}_party').GetParty]`" }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_party').GetParty.IsValid]`" size = {{ 162 20 }} raw_text = `"[Country.MakeScope.Var('{0}_party').GetParty.GetName]`" fontsize = 13 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_party').GetParty.IsValid)]`" size = {{ 180 20 }} text = `"vptl_presidential_history_unavailable_party`" fontsize = 13 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\tig_icon = {{ visible = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup.IsValid]`" size = {{ 18 18 }} datacontext = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup]`" }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup.IsValid]`" size = {{ 162 20 }} raw_text = `"[Country.MakeScope.Var('{0}_ig').GetInterestGroup.GetName]`" fontsize = 13 elide = right }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{0}_ig').GetInterestGroup.IsValid)]`" size = {{ 180 20 }} text = `"vptl_presidential_history_unavailable_ig`" fontsize = 13 elide = right }}" -f $p)
	foreach ($metric in @(@('gdp','GDP'),@('population','Pop'))) {
		$name=$metric[0]; $label=$metric[1]
		Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 250 20 }} raw_text = `"{1}: [Country.MakeScope.Var('{2}_{3}_start').GetValue|D]`" fontsize = 13 }}" -f $open,$label,$p,$name)
		Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 190 20 }} raw_text = `"{1}: [Country.MakeScope.Var('{2}_{3}_start').GetValue|D] → [Country.MakeScope.Var('{2}_{3}_end').GetValue|D]`" fontsize = 13 }}" -f $closed,$label,$p,$name)
		Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Country.MakeScope.Var('{0}_{1}_change_available').IsSet]`" size = {{ 60 20 }} raw_text = `"([Country.MakeScope.Var('{0}_{1}_change_percent').GetValue|1]%)`" fontsize = 13 }}" -f $p,$name)
	}
	Add-Line $g '\t\t\t\t\t\t\t\t}'

	# SoL, prestige, numeric prestige rank, power category, and enacted laws.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = {'
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 150 20 }} raw_text = `"SoL: [Country.MakeScope.Var('{1}_sol_start').GetValue|1]`" fontsize = 13 }}" -f $open,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 150 20 }} raw_text = `"SoL: [Country.MakeScope.Var('{1}_sol_start').GetValue|1] → [Country.MakeScope.Var('{1}_sol_end').GetValue|1]`" fontsize = 13 }}" -f $closed,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 170 20 }} raw_text = `"Prestige: [Country.MakeScope.Var('{1}_prestige_start').GetValue|0]`" fontsize = 12 }}" -f $open,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 170 20 }} raw_text = `"Prestige: [Country.MakeScope.Var('{1}_prestige_start').GetValue|0] → [Country.MakeScope.Var('{1}_prestige_end').GetValue|0]`" fontsize = 12 }}" -f $closed,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 90 20 }} raw_text = `"Rank: #[Country.MakeScope.Var('{1}_score_rank_start').GetValue|0]`" fontsize = 12 }}" -f $open,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 110 20 }} raw_text = `"Rank: #[Country.MakeScope.Var('{1}_score_rank_start').GetValue|0] → #[Country.MakeScope.Var('{1}_score_rank_end').GetValue|0]`" fontsize = 12 }}" -f $closed,$p)
	for ($i=0;$i -le 7;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_rank_start').GetValue, '(CFixedPoint){1}')]`" size = {{ 105 20 }} text = `"vptl_presidential_history_rank_{1}`" fontsize = 12 elide = right }}" -f $p,$i) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 14 20 }} text = `"→`" fontsize = 12 }}" -f $closed)
	for ($i=0;$i -le 7;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[And({0}, EqualTo_CFixedPoint(Country.MakeScope.Var('{1}_rank_end').GetValue, '(CFixedPoint){2}'))]`" size = {{ 105 20 }} text = `"vptl_presidential_history_rank_{2}`" fontsize = 12 elide = right }}" -f $closed,$p,$i) }
	Add-Line $g '\t\t\t\t\t\t\t\t\ttextbox = { size = { 38 20 } text = "vptl_presidential_history_laws_compact" fontsize = 12 }'
	for ($i=1;$i -le 8;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\tlaw_icon = {{ visible = `"[Country.MakeScope.Var('{0}_law_{1}').GetLaw.IsValid]`" size = {{ 18 18 }} datacontext = `"[Country.MakeScope.Var('{0}_law_{1}').GetLaw]`" tooltipwidget = {{ FancyTooltip_Law = {{}} }} }}" -f $p,$i) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_law_overflow_count').GetValue, '(CFixedPoint)0')]`" size = {{ 38 20 }} raw_text = `"+[Country.MakeScope.Var('{0}_law_overflow_count').GetValue|0]`" fontsize = 12 }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t}'
}
Add-Line $g '\t\t\t\t\twidget = { layoutpolicy_horizontal = expanding layoutpolicy_vertical = expanding minimumsize = { 1 1 } }'
Add-Line $g '\t\t\t\t}'; Add-Line $g '\t\t\t}'; Add-Line $g '\t\t}'; Add-Line $g '\t}'; Add-Line $g '}'
$guiText = (($g -join "`r`n") + "`r`n").Replace('\t', "`t")
[System.IO.File]::WriteAllText($guiPath, $guiText, $utf8Bom)

Write-Host "Generated $effectsPath"
Write-Host "Generated $guiPath"
