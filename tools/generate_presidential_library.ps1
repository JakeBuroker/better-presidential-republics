param(
	[string]$ModPath = (Split-Path -Parent $PSScriptRoot)
)

$effectsPath = Join-Path $ModPath 'common\scripted_effects\zzz_vptl_presidential_history.txt'
$guiPath = Join-Path $ModPath 'gui\vptl_presidential_history_window.gui'
$utf8Bom = New-Object System.Text.UTF8Encoding($true)

function Add-Line([System.Collections.Generic.List[string]]$Lines, [string]$Text = '') { $Lines.Add($Text) }
function Join-GuiExpression([string]$Operator, [string[]]$Expressions) {
	$items = @($Expressions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	if ($items.Count -eq 0) { return '' }
	if ($items.Count -eq 1) { return $items[0] }
	$result = "{0}({1}, {2})" -f $Operator,$items[0],$items[1]
	for ($i = 2; $i -lt $items.Count; $i++) {
		$result = "{0}({1}, {2})" -f $Operator,$result,$items[$i]
	}
	return $result
}
function Gui-And([string[]]$Expressions) { Join-GuiExpression 'And' $Expressions }
function Gui-Or([string[]]$Expressions) { Join-GuiExpression 'Or' $Expressions }
function Copy-VariableBlock([System.Collections.Generic.List[string]]$Lines, [string]$From, [string]$To, [string[]]$Fields, [string]$Indent = '\t') {
	foreach ($field in $Fields) {
		Add-Line $Lines ("{0}if = {{ limit = {{ has_variable = {1}_{2} }} set_variable = {{ name = {3}_{2} value = var:{1}_{2} }} }}" -f $Indent,$From,$field,$To)
		Add-Line $Lines ("{0}else = {{ remove_variable = {1}_{2} }}" -f $Indent,$To,$field)
	}
}

$historicalIdentities = @(
	@{ Id = 1;  Loc = 'vptl_presidential_history_identity_andrew_jackson';   Name = 'Andrew Jackson';                     Match = 'OR = { has_variable = is_andrew_jackson has_template = usa_andrew_jackson_template }' },
	@{ Id = 2;  Loc = 'vptl_presidential_history_identity_winfield_scott';   Name = 'Winfield Scott';                     Match = 'has_template = USA_winfield_scott' },
	@{ Id = 3;  Loc = 'vptl_presidential_history_identity_john_calhoun';     Name = 'John Calhoun';                       Match = 'has_template = USA_john_calhoun' },
	@{ Id = 4;  Loc = 'vptl_presidential_history_identity_daniel_webster';   Name = 'Daniel Webster';                     Match = 'has_template = USA_daniel_webster' },
	@{ Id = 5;  Loc = 'vptl_presidential_history_identity_henry_clay';       Name = 'Henry Clay';                         Match = 'has_template = USA_henry_clay' },
	@{ Id = 6;  Loc = 'vptl_presidential_history_identity_miguel_barragan';  Name = 'Miguel Barragán';                    Match = 'has_template = mex_miguel_barragan_template' },
	@{ Id = 7;  Loc = 'vptl_presidential_history_identity_anastasio_bustamante'; Name = 'Anastasio Bustamante';            Match = 'has_template = MEX_anastasio_bustamante' },
	@{ Id = 8;  Loc = 'vptl_presidential_history_identity_valentin_gomez_farias'; Name = 'Valentín Gómez Farías';          Match = 'has_template = MEX_valentin_gomez_farias' },
	@{ Id = 9;  Loc = 'vptl_presidential_history_identity_antonio_santa_anna'; Name = 'Antonio López de Santa Anna';       Match = 'has_template = MEX_antonio_lopez_de_santa_anna' },
	@{ Id = 10; Loc = 'vptl_presidential_history_identity_jose_miguel_velasco'; Name = 'José Miguel de Velasco';           Match = 'has_template = BOL_Jose_Miguel_de_Velasco' },
	@{ Id = 11; Loc = 'vptl_presidential_history_identity_andres_santa_cruz'; Name = 'Andrés de Santa Cruz';               Match = 'has_template = BOL_Andres_de_Santa_Cruz' },
	@{ Id = 12; Loc = 'vptl_presidential_history_identity_jose_joaquin_prieto'; Name = 'José Joaquín Prieto';              Match = 'has_template = CHL_Jose_Joaquin_Prieto' },
	@{ Id = 13; Loc = 'vptl_presidential_history_identity_santander';        Name = 'Francisco de Paula Santander';       Match = 'has_template = CLM_Francisco_de_Paula_Santander' },
	@{ Id = 14; Loc = 'vptl_presidential_history_identity_juan_jose_flores'; Name = 'Juan José Flores';                   Match = 'has_template = ECU_Juan_Jose_Flores' },
	@{ Id = 15; Loc = 'vptl_presidential_history_identity_rocafuerte';       Name = 'Vicente Rocafuerte';                 Match = 'has_template = ECU_Vicente_Rocafuerte' },
	@{ Id = 16; Loc = 'vptl_presidential_history_identity_jean_pierre_boyer'; Name = 'Jean-Pierre Boyer';                 Match = 'has_template = HAI_jean_pierre_boyer' },
	@{ Id = 17; Loc = 'vptl_presidential_history_identity_francia';          Name = 'José Gaspar Rodríguez de Francia';   Match = 'has_template = PRG_jose_gaspar_rodriguez_de_francia' },
	@{ Id = 18; Loc = 'vptl_presidential_history_identity_david_burnet';     Name = 'David Burnet';                       Match = 'has_template = TEX_david_burnet' },
	@{ Id = 19; Loc = 'vptl_presidential_history_identity_francisco_morazan'; Name = 'Francisco Morazán';                 Match = 'has_template = UCA_francisco_morazan' },
	@{ Id = 20; Loc = 'vptl_presidential_history_identity_fructuoso_rivera'; Name = 'Fructuoso Rivera';                   Match = 'has_template = URU_Fructuoso_Rivera' },
	@{ Id = 21; Loc = 'vptl_presidential_history_identity_manuel_oribe';     Name = 'Manuel Oribe';                       Match = 'has_template = URU_Manuel_Oribe' },
	@{ Id = 22; Loc = 'vptl_presidential_history_identity_bento_goncalves';  Name = 'Bento Gonçalves da Silva';           Match = 'has_template = PNI_bento_goncalves_da_silva' },
	@{ Id = 23; Loc = 'vptl_presidential_history_identity_eduardo_angelim';  Name = 'Eduardo Angelim';                    Match = 'has_template = PRA_eduardo_angelim' },
	@{ Id = 24; Loc = 'vptl_presidential_history_identity_jose_paez';        Name = 'José Antonio Páez';                  Match = 'has_template = VNZ_Jose_Paez' },
	@{ Id = 25; Loc = 'vptl_presidential_history_identity_jose_maria_ponce'; Name = 'José María Ponce';                   Match = 'has_template = VNZ_Jose_Maria_Ponce' },
	@{ Id = 26; Loc = 'vptl_presidential_history_identity_johann_smidt';     Name = 'Johann Smidt';                       Match = 'has_template = BRE_johann_smidt' },
	@{ Id = 27; Loc = 'vptl_presidential_history_identity_ferdinand_starck'; Name = 'Ferdinand Starck';                   Match = 'has_template = FRM_ferdinand_starck' },
	@{ Id = 28; Loc = 'vptl_presidential_history_identity_christian_benecke'; Name = 'Christian Daniel Benecke';          Match = 'has_template = HAM_christian_daniel_benecke' },
	@{ Id = 29; Loc = 'vptl_presidential_history_identity_howard_douglas';   Name = 'Howard Douglas';                     Match = 'has_template = ION_howard_douglas' },
	@{ Id = 30; Loc = 'vptl_presidential_history_identity_kasper_wieloglowski'; Name = 'Kasper Wielogłowski';             Match = 'has_template = KRA_Kasper_Wieloglowski' },
	@{ Id = 31; Loc = 'vptl_presidential_history_identity_taiji_liu';        Name = 'Liu Taiji';                          Match = 'has_template = LAN_taiji_liu' },
	@{ Id = 32; Loc = 'vptl_presidential_history_identity_evers';            Name = 'Christian Nicolaus von Evers';       Match = 'has_template = LUB_christian_nicolaus_von_evers' },
	@{ Id = 33; Loc = 'vptl_presidential_history_identity_hendrik_potgieter'; Name = 'Hendrik Potgieter';                 Match = 'has_template = ORA_hendrik_potgieter' },
	@{ Id = 34; Loc = 'vptl_presidential_history_identity_andries_pretorius'; Name = 'Andries Pretorius';                 Match = 'has_template = TRN_andries_pretorius' },
	@{ Id = 35; Loc = 'vptl_presidential_history_identity_jose_marquez';     Name = 'José Ignacio de Márquez';            Match = 'has_template = CLM_Jose_Marquez' },
	@{ Id = 36; Loc = 'vptl_presidential_history_identity_policarpo_patino'; Name = 'Policarpo Patiño';                   Match = 'OR = { has_template = PRG_policarpo_patino has_template = PRG_policarpo_patino_regular }' },
	@{ Id = 37; Loc = 'vptl_presidential_history_identity_joaquin_suarez';   Name = 'Joaquín Suárez';                     Match = 'has_template = URU_joaquin_suarez' },
	@{ Id = 38; Loc = 'vptl_presidential_history_identity_mariano_calvo';    Name = 'Mariano Enrique Calvo';              Match = 'has_template = BOL_Mariano_Enrique_Calvo' }
)

# Party and IG scopes can later rename or disappear. These IDs freeze the broad
# political family that existed when the presidential episode began.
$partyTypeIdentities = @(
	@{ Id = 1;  Key = 'agrarian_party';          Loc = 'vptl_presidential_history_party_type_agrarian' },
	@{ Id = 2;  Key = 'anarchist_party';         Loc = 'vptl_presidential_history_party_type_anarchist' },
	@{ Id = 3;  Key = 'communist_party';         Loc = 'vptl_presidential_history_party_type_communist' },
	@{ Id = 4;  Key = 'conservative_party';      Loc = 'vptl_presidential_history_party_type_conservative' },
	@{ Id = 5;  Key = 'fascist_party';           Loc = 'vptl_presidential_history_party_type_fascist' },
	@{ Id = 6;  Key = 'free_trade_party';        Loc = 'vptl_presidential_history_party_type_free_trade' },
	@{ Id = 7;  Key = 'liberal_party';           Loc = 'vptl_presidential_history_party_type_liberal' },
	@{ Id = 8;  Key = 'military_party';          Loc = 'vptl_presidential_history_party_type_military' },
	@{ Id = 9;  Key = 'radical_party';           Loc = 'vptl_presidential_history_party_type_radical' },
	@{ Id = 10; Key = 'religious_party';          Loc = 'vptl_presidential_history_party_type_religious' },
	@{ Id = 11; Key = 'revolutionary_party';      Loc = 'vptl_presidential_history_party_type_revolutionary' },
	@{ Id = 12; Key = 'social_democrat_party';    Loc = 'vptl_presidential_history_party_type_social_democrat' }
)

$igTypeIdentities = @(
	@{ Id = 1; Key = 'ig_armed_forces';       Loc = 'vptl_presidential_history_ig_type_armed_forces';      Texture = 'armed_forces_30.dds' },
	@{ Id = 2; Key = 'ig_devout';             Loc = 'vptl_presidential_history_ig_type_devout';            Texture = 'devout_30.dds' },
	@{ Id = 3; Key = 'ig_industrialists';     Loc = 'vptl_presidential_history_ig_type_industrialists';    Texture = 'industrialists_30.dds' },
	@{ Id = 4; Key = 'ig_intelligentsia';     Loc = 'vptl_presidential_history_ig_type_intelligentsia';    Texture = 'intelligensia_30.dds' },
	@{ Id = 5; Key = 'ig_landowners';         Loc = 'vptl_presidential_history_ig_type_landowners';        Texture = 'landowners_30.dds' },
	@{ Id = 6; Key = 'ig_petty_bourgeoisie';  Loc = 'vptl_presidential_history_ig_type_petty_bourgeoisie'; Texture = 'petty_bourgeoisie_30.dds' },
	@{ Id = 7; Key = 'ig_rural_folk';         Loc = 'vptl_presidential_history_ig_type_rural_folk';        Texture = 'rural_folk_30.dds' },
	@{ Id = 8; Key = 'ig_trade_unions';        Loc = 'vptl_presidential_history_ig_type_trade_unions';       Texture = 'trade_unions_30.dds' }
)

# Verified vanilla ideology fallbacks for the supported USA historical figures.
# The live ideology scope is preferred; these labels keep dead scopes readable.
$ideologyIdentities = @(
	@{ Id = 1; Key = 'ideology_jacksonian_democrat'; Loc = 'ideology_jacksonian_democrat' },
	@{ Id = 2; Key = 'ideology_slaver';              Loc = 'ideology_slaver' },
	@{ Id = 3; Key = 'ideology_pacifist';            Loc = 'ideology_pacifist' },
	@{ Id = 4; Key = 'ideology_republican_leader';   Loc = 'ideology_republican_leader' },
	@{ Id = 5; Key = 'ideology_moderate';            Loc = 'ideology_moderate' }
)

function Add-IdentityCapture([System.Collections.Generic.List[string]]$Lines, [string]$ScopeExpr, [string]$TargetVariable, [string]$Indent = "`t") {
	Add-Line $Lines "${Indent}set_variable = { name = $TargetVariable value = 0 }"
	Add-Line $Lines "${Indent}$ScopeExpr = {"
	foreach ($identity in $historicalIdentities) {
		Add-Line $Lines ("{0}`tif = {{ limit = {{ {1} }} owner = {{ set_variable = {{ name = {2} value = {3} }} }} }}" -f $Indent,$identity.Match,$TargetVariable,$identity.Id)
	}
	Add-Line $Lines "${Indent}}"
}

function Add-IdentityFallbackText([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$IdentityField, [string]$UnavailableKey, [string]$Size, [string]$FontSize, [string]$Indent = "`t`t`t`t`t`t`t`t`t", [string]$TooltipWidget = '') {
	$tooltipSuffix = ''
	if (-not [string]::IsNullOrWhiteSpace($TooltipWidget)) {
		$tooltipSuffix = " tooltipwidget = { $TooltipWidget = {} }"
	}
	Add-Line $Lines ("{0}widget = {{" -f $Indent)
	Add-Line $Lines ("{0}`tsize = {{ {1} }}" -f $Indent,$Size)
	foreach ($identity in $historicalIdentities) {
		# Frozen identity labels remain readable after the engine retires a character scope.
		$identityTooltip = ''
		if ([string]::IsNullOrWhiteSpace($TooltipWidget)) { $identityTooltip = " tooltip = `"$($identity.Loc)`"" }
		Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[And(Not(Country.MakeScope.Var('{1}_{2}').GetCharacter.IsValid), EqualTo_CFixedPoint(Country.MakeScope.Var('{1}_{2}_identity').GetValue, '(CFixedPoint){3}'))]`" size = {{ {4} }} text = `"{5}`"{6} fontsize = {7} elide = right align = left|nobaseline{8} }}" -f $Indent,$Prefix,$IdentityField,$identity.Id,$Size,$identity.Loc,$identityTooltip,$FontSize,$tooltipSuffix)
	}
	# Living unknowns use plain text only; dead unknowns stay unavailable.
	$liveVariable = "${Prefix}_${IdentityField}"
	$liveTooltip = ''
	if ([string]::IsNullOrWhiteSpace($TooltipWidget)) { $liveTooltip = " tooltip = `"[Country.MakeScope.Var('$liveVariable').GetCharacter.GetFullNameNoFormatting]`"" }
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[Country.MakeScope.Var('{1}_{2}').GetCharacter.IsValid]`" size = {{ {3} }} raw_text = `"#BOLD [Country.MakeScope.Var('{1}_{2}').GetCharacter.GetFullNameNoFormatting]#!`"{4} fontsize = {5} elide = right align = left|nobaseline{6} }}" -f $Indent,$Prefix,$IdentityField,$Size,$liveTooltip,$FontSize,$tooltipSuffix)
	# Unknown dead characters have no safe name scope and remain unavailable.
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[And(Not(Country.MakeScope.Var('{1}_{2}').GetCharacter.IsValid), LessThan_CFixedPoint(Country.MakeScope.Var('{1}_{2}_identity').GetValue, '(CFixedPoint)1'))]`" size = {{ {3} }} text = `"{4}`" fontsize = {5} elide = right align = left|nobaseline{6} }}" -f $Indent,$Prefix,$IdentityField,$Size,$UnavailableKey,$FontSize,$tooltipSuffix)
	Add-Line $Lines ("{0}}}" -f $Indent)
}

function Add-AffiliationIdentityCapture([System.Collections.Generic.List[string]]$Lines, [string]$ScopeExpr, [string]$TargetVariable, [array]$Mappings, [string]$Trigger, [string]$Indent = "`t") {
	Add-Line $Lines "${Indent}set_variable = { name = $TargetVariable value = 0 }"
	foreach ($mapping in $Mappings) {
		Add-Line $Lines ("{0}if = {{ limit = {{ {1} ?= {{ {2} = {3} }} }} set_variable = {{ name = {4} value = {5} }} }}" -f $Indent,$ScopeExpr,$Trigger,$mapping.Key,$TargetVariable,$mapping.Id)
	}
}

function Add-AffiliationIdentityText([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$IdentityField, [array]$Mappings, [string]$UnavailableKey, [string]$Size, [string]$FontSize, [string]$Indent = "`t`t`t`t`t`t`t`t`t") {
	Add-Line $Lines ("{0}widget = {{ size = {{ {1} }}" -f $Indent,$Size)
	foreach ($mapping in $Mappings) {
		Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{1}_{2}').GetValue, '(CFixedPoint){3}')]`" size = {{ {4} }} text = `"{5}`" tooltip = `"{5}`" fontsize = {6} elide = right align = left|nobaseline }}" -f $Indent,$Prefix,$IdentityField,$mapping.Id,$Size,$mapping.Loc,$FontSize)
	}
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[Or(LessThan_CFixedPoint(Country.MakeScope.Var('{1}_{2}').GetValue, '(CFixedPoint)1'), GreaterThan_CFixedPoint(Country.MakeScope.Var('{1}_{2}').GetValue, '(CFixedPoint){3}'))]`" size = {{ {4} }} text = `"{5}`" fontsize = {6} elide = right align = left|nobaseline }}" -f $Indent,$Prefix,$IdentityField,$Mappings.Count,$Size,$UnavailableKey,$FontSize)
	Add-Line $Lines ("{0}}}" -f $Indent)
}

function Add-IdeologyIdentityCapture([System.Collections.Generic.List[string]]$Lines, [string]$ScopeExpr, [string]$TargetVariable, [string]$Indent = "`t") {
	Add-Line $Lines "${Indent}set_variable = { name = $TargetVariable value = 0 }"
	foreach ($mapping in $ideologyIdentities) {
		Add-Line $Lines ("{0}if = {{ limit = {{ {1} ?= {{ has_ideology = ideology:{2} }} }} set_variable = {{ name = {3} value = {4} }} }}" -f $Indent,$ScopeExpr,$mapping.Key,$TargetVariable,$mapping.Id)
	}
}

function Add-IdeologyText([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Size = '226 32', [string]$Indent = "`t`t`t`t`t`t`t`t`t") {
	$variable = "${Prefix}_ideology"
	$identity = "${Prefix}_ideology_identity"
	Add-Line $Lines ("{0}widget = {{ size = {{ {1} }} hbox = {{ spacing = 4" -f $Indent,$Size)
	Add-Line $Lines ("{0}`ttextbox = {{ size = {{ 72 32 }} text = `"vptl_presidential_history_ideology_label`" fontsize = 14 align = left|nobaseline }}" -f $Indent)
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[Country.MakeScope.Var('{1}').GetIdeology.IsValid]`" size = {{ 150 32 }} datacontext = `"[Country.MakeScope.Var('{1}').GetIdeology]`" raw_text = `"#v [Country.MakeScope.Var('{1}').GetIdeology.GetNameNoFormatting]#!`" fontsize = 15 elide = right tooltipwidget = {{ FancyTooltip_Ideology = {{}} }} }}" -f $Indent,$variable)
	foreach ($mapping in $ideologyIdentities) {
		Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[And(Not(Country.MakeScope.Var('{1}').GetIdeology.IsValid), EqualTo_CFixedPoint(Country.MakeScope.Var('{2}').GetValue, '(CFixedPoint){3}'))]`" size = {{ 150 32 }} text = `"{4}`" tooltip = `"{4}`" fontsize = 15 elide = right }}" -f $Indent,$variable,$identity,$mapping.Id,$mapping.Loc)
	}
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[And(Not(Country.MakeScope.Var('{1}').GetIdeology.IsValid), Or(Not(Country.MakeScope.Var('{2}').IsSet), LessThan_CFixedPoint(Country.MakeScope.Var('{2}').GetValue, '(CFixedPoint)1')))]`" size = {{ 150 32 }} text = `"vptl_presidential_history_profile_unavailable`" fontsize = 15 elide = right }}" -f $Indent,$variable,$identity)
	Add-Line $Lines ("{0}}} }}" -f $Indent)
}

function Add-PopularityText([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Size = '226 32', [string]$Indent = "`t`t`t`t`t`t`t`t`t") {
	$start = "${Prefix}_popularity_start"
	$end = "${Prefix}_popularity_end"
	$closed = "And(Country.MakeScope.Var('${Prefix}_closed').IsSet, GreaterThan_CFixedPoint(Country.MakeScope.Var('${Prefix}_closed').GetValue, '(CFixedPoint)0'))"
	$active = "Not($closed)"
	$closedValue = "And($closed, Country.MakeScope.Var('$end').IsSet)"
	$closedMissing = "And($closed, Not(Country.MakeScope.Var('$end').IsSet))"
	Add-Line $Lines ("{0}widget = {{ size = {{ {1} }} hbox = {{ spacing = 4" -f $Indent,$Size)
	Add-Line $Lines ("{0}`ttextbox = {{ size = {{ 72 32 }} text = `"vptl_presidential_history_popularity_label`" fontsize = 14 align = left|nobaseline }}" -f $Indent)
	$states = @(
		@{ Condition = "GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}').GetValue, '(CFixedPoint)0')" -f $start; Format = "#P +[Country.MakeScope.Var('{0}').GetValue|0]#!" -f $start },
		@{ Condition = "LessThan_CFixedPoint(Country.MakeScope.Var('{0}').GetValue, '(CFixedPoint)0')" -f $start; Format = "#N [Country.MakeScope.Var('{0}').GetValue|0]#!" -f $start },
		@{ Condition = "EqualTo_CFixedPoint(Country.MakeScope.Var('{0}').GetValue, '(CFixedPoint)0')" -f $start; Format = "[Country.MakeScope.Var('{0}').GetValue|0]" -f $start }
	)
	foreach ($state in $states) { Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[And({1}, {2})]`" size = {{ 150 32 }} raw_text = `"{3}`" fontsize = 15 }}" -f $Indent,$active,$state.Condition,$state.Format) }
	$finalStates = @(
		@{ Condition = "GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}').GetValue, '(CFixedPoint)0')" -f $end; Format = "#P +[Country.MakeScope.Var('{0}').GetValue|0]#!" -f $end },
		@{ Condition = "LessThan_CFixedPoint(Country.MakeScope.Var('{0}').GetValue, '(CFixedPoint)0')" -f $end; Format = "#N [Country.MakeScope.Var('{0}').GetValue|0]#!" -f $end },
		@{ Condition = "EqualTo_CFixedPoint(Country.MakeScope.Var('{0}').GetValue, '(CFixedPoint)0')" -f $end; Format = "[Country.MakeScope.Var('{0}').GetValue|0]" -f $end }
	)
	foreach ($state in $finalStates) { Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[And({1}, {2})]`" size = {{ 150 32 }} raw_text = `"{3}`" fontsize = 15 }}" -f $Indent,$closedValue,$state.Condition,$state.Format) }
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[{1}]`" size = {{ 150 32 }} text = `"vptl_presidential_history_profile_unavailable`" fontsize = 15 }}" -f $Indent,$closedMissing)
	Add-Line $Lines ("{0}}} }}" -f $Indent)
}

function Add-ExecutiveProfileTooltipType([System.Collections.Generic.List[string]]$Lines, [int]$Slot, [string]$SubjectField, [string]$TooltipType, [string]$TitleKey, [string]$UnavailableKey) {
	$prefix = "vptl_presidential_history_display_${Slot}"
	$closed = "And(Country.MakeScope.Var('${prefix}_closed').IsSet, GreaterThan_CFixedPoint(Country.MakeScope.Var('${prefix}_closed').GetValue, '(CFixedPoint)0'))"
	$open = "Not($closed)"
	$subjectVariable = "${prefix}_${SubjectField}"
	$subjectValid = "Country.MakeScope.Var('${subjectVariable}').GetCharacter.IsValid"
	$subjectIdentity = "${subjectVariable}_identity"
	$profilePrefix = if ($SubjectField -eq 'president') { $prefix } else { $subjectVariable }
	$profileIndent = "`t`t`t`t`t"

	Add-Line $Lines ("`ttype {0} = FancyTooltipWidgetType {{" -f $TooltipType)
	Add-Line $Lines '\t\tblockoverride "text" {}'
	Add-Line $Lines '\t\tblockoverride "icon_texture" {}'
	Add-Line $Lines '\t\tblockoverride "icon_frame" {}'
	Add-Line $Lines ("`t`tblockoverride `"name`" {{ text = `"{0}`" }}" -f $TitleKey)
	Add-Line $Lines '\t\tblockoverride "type" {}'
	Add-Line $Lines '\t\tblockoverride "tooltip_content_after" {'

	# The title is record-bound: live names use the stored Character scope, while
	# dead historical names use the same frozen identity mapping as the card.
	Add-Line $Lines ("{0}custom_tooltip_textbox = {{ visible = `"[{1}]`" raw_text = `"#BOLD [Country.MakeScope.Var('{2}').GetCharacter.GetFullNameNoFormatting]#!`" fontsize = 18 }}" -f $profileIndent,$subjectValid,$subjectVariable)
	foreach ($identity in $historicalIdentities) {
		Add-Line $Lines ("{0}custom_tooltip_textbox = {{ visible = `"[And(Not({1}), EqualTo_CFixedPoint(Country.MakeScope.Var('{2}').GetValue, '(CFixedPoint){3}'))]`" text = `"{4}`" fontsize = 18 }}" -f $profileIndent,$subjectValid,$subjectIdentity,$identity.Id,$identity.Loc)
	}
	Add-Line $Lines ("{0}custom_tooltip_textbox = {{ visible = `"[And(Not({1}), LessThan_CFixedPoint(Country.MakeScope.Var('{2}').GetValue, '(CFixedPoint)1'))]`" text = `"{3}`" fontsize = 18 }}" -f $profileIndent,$subjectValid,$subjectIdentity,$UnavailableKey)
	Add-Line $Lines ("{0}tooltip_divider = {{}}" -f $profileIndent)

	# Culture and religion remain stored captured scopes for both open and closed records.
	foreach ($profile in @(
		@{ Field = 'culture'; Getter = 'Culture'; Label = 'vptl_presidential_history_culture_label' },
		@{ Field = 'religion'; Getter = 'Religion'; Label = 'vptl_presidential_history_religion_label' }
	)) {
		$variable = "${profilePrefix}_$($profile.Field)"
		$valid = "Country.MakeScope.Var('$variable').Get$($profile.Getter).IsValid"
		Add-Line $Lines ("{0}custom_tooltip_textbox = {{ text = `"{1}`" }}" -f $profileIndent,$profile.Label)
		Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[{1}]`" raw_text = `"#v [Country.MakeScope.Var('{2}').Get{3}.GetNameNoFormatting]#!`" }}" -f $profileIndent,$valid,$variable,$profile.Getter)
		Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[Not({1})]`" text = `"vptl_presidential_history_profile_unavailable`" }}" -f $profileIndent,$valid)
	}

	# Ideology keeps the valid stored scope first, then the historical identity fallback.
	$ideologyVariable = "${profilePrefix}_ideology"
	$ideologyIdentity = "${profilePrefix}_ideology_identity"
	$ideologyValid = "Country.MakeScope.Var('$ideologyVariable').GetIdeology.IsValid"
	Add-Line $Lines ("{0}custom_tooltip_textbox = {{ text = `"vptl_presidential_history_ideology_label`" }}" -f $profileIndent)
	Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[{1}]`" raw_text = `"#v [Country.MakeScope.Var('{2}').GetIdeology.GetNameNoFormatting]#!`" }}" -f $profileIndent,$ideologyValid,$ideologyVariable)
	foreach ($mapping in $ideologyIdentities) {
		Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[And(Not({1}), EqualTo_CFixedPoint(Country.MakeScope.Var('{2}').GetValue, '(CFixedPoint){3}'))]`" text = `"{4}`" }}" -f $profileIndent,$ideologyValid,$ideologyIdentity,$mapping.Id,$mapping.Loc)
	}
	Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[And(Not({1}), Or(Not(Country.MakeScope.Var('{2}').IsSet), LessThan_CFixedPoint(Country.MakeScope.Var('{2}').GetValue, '(CFixedPoint)1')))]`" text = `"vptl_presidential_history_profile_unavailable`" }}" -f $profileIndent,$ideologyValid,$ideologyIdentity)

	# Open records use the maintained popularity value; closed records use only the frozen end value.
	$activePopularity = Gui-And @($open, "Country.MakeScope.Var('${profilePrefix}_popularity').IsSet")
	$closedPopularity = Gui-And @($closed, "Country.MakeScope.Var('${profilePrefix}_popularity_end').IsSet")
	$missingPopularity = Gui-Or @(
		(Gui-And @($open, "Not(Country.MakeScope.Var('${profilePrefix}_popularity').IsSet)")),
		(Gui-And @($closed, "Not(Country.MakeScope.Var('${profilePrefix}_popularity_end').IsSet)"))
	)
	Add-Line $Lines ("{0}custom_tooltip_textbox = {{ text = `"vptl_presidential_history_popularity_label`" }}" -f $profileIndent)
	foreach ($state in @(
		@{ Condition = "GreaterThan_CFixedPoint(Country.MakeScope.Var('${profilePrefix}_popularity').GetValue, '(CFixedPoint)0')"; Visible = $activePopularity; Value = "#P +[Country.MakeScope.Var('${profilePrefix}_popularity').GetValue|0]#!" },
		@{ Condition = "LessThan_CFixedPoint(Country.MakeScope.Var('${profilePrefix}_popularity').GetValue, '(CFixedPoint)0')"; Visible = $activePopularity; Value = "#N [Country.MakeScope.Var('${profilePrefix}_popularity').GetValue|0]#!" },
		@{ Condition = "EqualTo_CFixedPoint(Country.MakeScope.Var('${profilePrefix}_popularity').GetValue, '(CFixedPoint)0')"; Visible = $activePopularity; Value = "[Country.MakeScope.Var('${profilePrefix}_popularity').GetValue|0]" },
		@{ Condition = "GreaterThan_CFixedPoint(Country.MakeScope.Var('${profilePrefix}_popularity_end').GetValue, '(CFixedPoint)0')"; Visible = $closedPopularity; Value = "#P +[Country.MakeScope.Var('${profilePrefix}_popularity_end').GetValue|0]#!" },
		@{ Condition = "LessThan_CFixedPoint(Country.MakeScope.Var('${profilePrefix}_popularity_end').GetValue, '(CFixedPoint)0')"; Visible = $closedPopularity; Value = "#N [Country.MakeScope.Var('${profilePrefix}_popularity_end').GetValue|0]#!" },
		@{ Condition = "EqualTo_CFixedPoint(Country.MakeScope.Var('${profilePrefix}_popularity_end').GetValue, '(CFixedPoint)0')"; Visible = $closedPopularity; Value = "[Country.MakeScope.Var('${profilePrefix}_popularity_end').GetValue|0]" }
	)) {
		Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[{1}]`" raw_text = `"{2}`" }}" -f $profileIndent,(Gui-And @($state.Visible,$state.Condition)),$state.Value)
	}
	Add-Line $Lines ("{0}custom_tooltip_textbox_with_empty_line = {{ visible = `"[{1}]`" text = `"vptl_presidential_history_profile_unavailable`" }}" -f $profileIndent,$missingPopularity)

	Add-Line $Lines "`t`t}"
	Add-Line $Lines "`t}"
}

function Add-PercentCalculation([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Metric, [string]$Indent = '\t', [bool]$OnlyIfMissing = $false) {
	$baseline = "${Prefix}_${Metric}_start"
	$final = "${Prefix}_${Metric}_end"
	$percent = "${Prefix}_${Metric}_change_percent"
	$available = "${Prefix}_${Metric}_change_available"
	if (-not $OnlyIfMissing) {
		Add-Line $Lines "${Indent}remove_variable = $available"
		Add-Line $Lines "${Indent}remove_variable = $percent"
	}
	$limit = "has_variable = $baseline has_variable = $final $baseline > 0"
	if ($OnlyIfMissing) { $limit += " NOT = { has_variable = $available }" }
	Add-Line $Lines "${Indent}if = {"
	Add-Line $Lines "${Indent}`tlimit = { $limit }"
	Add-Line $Lines "${Indent}`tset_variable = { name = $percent value = 0 }"
	Add-Line $Lines "${Indent}`tchange_variable = { name = $percent add = { value = var:$final subtract = var:$baseline divide = var:$baseline multiply = 100 } }"
	Add-Line $Lines "${Indent}`tset_variable = $available"
	Add-Line $Lines "${Indent}}"
}

function Add-LivePercentCalculation([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Metric, [string]$CurrentValue, [string]$Indent = '\t') {
	$baseline = "${Prefix}_${Metric}_start"
	$percent = "${Prefix}_${Metric}_active_change_percent"
	$available = "${Prefix}_${Metric}_active_change_available"
	Add-Line $Lines "${Indent}remove_variable = $available"
	Add-Line $Lines "${Indent}remove_variable = $percent"
	Add-Line $Lines "${Indent}if = {"
	Add-Line $Lines "${Indent}`tlimit = { has_variable = $baseline $baseline > 0 }"
	Add-Line $Lines "${Indent}`tset_variable = { name = $percent value = 0 }"
	Add-Line $Lines "${Indent}`tchange_variable = { name = $percent add = { value = $CurrentValue subtract = var:$baseline divide = var:$baseline multiply = 100 } }"
	Add-Line $Lines "${Indent}`tset_variable = $available"
	Add-Line $Lines "${Indent}}"
}

function Add-NationalMetricText([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Name, [string]$Label, [string]$Format, [string]$LiveGetter, [bool]$ShowPercent, [string]$Width = '180', [string]$Indent = "`t`t`t`t`t`t`t`t`t") {
	$closed = "And(Country.MakeScope.Var('${Prefix}_closed').IsSet, GreaterThan_CFixedPoint(Country.MakeScope.Var('${Prefix}_closed').GetValue, '(CFixedPoint)0'))"
	$start = "${Prefix}_${Name}_start"
	$end = "${Prefix}_${Name}_end"
	$closedValue = "And($closed, Country.MakeScope.Var('$end').IsSet)"
	$missingValue = "And($closed, Not(Country.MakeScope.Var('$end').IsSet))"
	Add-Line $Lines ("{0}widget = {{ size = {{ {1} 48 }} vbox = {{" -f $Indent,$Width)
	Add-Line $Lines ("{0}`ttextbox = {{ size = {{ {1} 18 }} text = `"{2}`" fontsize = 14 }}" -f $Indent,$Width,$Label)
	Add-Line $Lines ("{0}`thbox = {{ spacing = 4" -f $Indent)
	Add-Line $Lines ("{0}`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 112 28 }} raw_text = `"#BOLD [Country.{2}|{3}]#!`" fontsize = 16 elide = right }}" -f $Indent,("Not($closed)"),$LiveGetter,$Format)
	Add-Line $Lines ("{0}`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 112 28 }} raw_text = `"#BOLD [Country.MakeScope.Var('{2}').GetValue|{3}]#!`" fontsize = 16 elide = right }}" -f $Indent,$closedValue,$end,$Format)
	Add-Line $Lines ("{0}`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 112 28 }} text = `"vptl_presidential_history_metric_unavailable`" fontsize = 15 elide = right }}" -f $Indent,$missingValue)
	if ($ShowPercent) {
		$available = "${Prefix}_${Name}_change_available"
		$storedPercent = "Country.MakeScope.Var('${Prefix}_${Name}_change_percent').GetValue"
		$closedPositive = Gui-And @($closed, "Country.MakeScope.Var('$available').IsSet", "GreaterThan_CFixedPoint($storedPercent, '(CFixedPoint)0')")
		$closedNegative = Gui-And @($closed, "Country.MakeScope.Var('$available').IsSet", "LessThan_CFixedPoint($storedPercent, '(CFixedPoint)0')")
		$closedZero = Gui-And @($closed, "Country.MakeScope.Var('$available').IsSet", "EqualTo_CFixedPoint($storedPercent, '(CFixedPoint)0')")
		$activeAvailable = "${Prefix}_${Name}_active_change_available"
		$activePercentPath = "Country.MakeScope.Var('${Prefix}_${Name}_active_change_percent').GetValue|1"
		$activePositive = Gui-And @("Not($closed)", "Country.MakeScope.Var('$activeAvailable').IsSet", "GreaterThan_CFixedPoint(Country.MakeScope.Var('${Prefix}_${Name}_active_change_percent').GetValue, '(CFixedPoint)0')")
		$activeNegative = Gui-And @("Not($closed)", "Country.MakeScope.Var('$activeAvailable').IsSet", "LessThan_CFixedPoint(Country.MakeScope.Var('${Prefix}_${Name}_active_change_percent').GetValue, '(CFixedPoint)0')")
		$activeZero = Gui-And @("Not($closed)", "Country.MakeScope.Var('$activeAvailable').IsSet", "EqualTo_CFixedPoint(Country.MakeScope.Var('${Prefix}_${Name}_active_change_percent').GetValue, '(CFixedPoint)0')")
		Add-Line $Lines ("{0}`t`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 62 28 }} raw_text = `"#P +[{2}]%#!`" fontsize = 15 align = right|nobaseline }}" -f $Indent,$activePositive,$activePercentPath)
		Add-Line $Lines ("{0}`t`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 62 28 }} raw_text = `"#N [{2}]%#!`" fontsize = 15 align = right|nobaseline }}" -f $Indent,$activeNegative,$activePercentPath)
		Add-Line $Lines ("{0}`t`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 62 28 }} raw_text = `"[{2}]%`" fontsize = 15 align = right|nobaseline }}" -f $Indent,$activeZero,$activePercentPath)
		Add-Line $Lines ("{0}`t`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 62 28 }} raw_text = `"#P +[{2}|1]%#!`" fontsize = 15 align = right|nobaseline }}" -f $Indent,$closedPositive,$storedPercent)
		Add-Line $Lines ("{0}`t`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 62 28 }} raw_text = `"#N [{2}|1]%#!`" fontsize = 15 align = right|nobaseline }}" -f $Indent,$closedNegative,$storedPercent)
		Add-Line $Lines ("{0}`t`t`ttextbox = {{ visible = `"[{1}]`" size = {{ 62 28 }} raw_text = `"[{2}|1]%`" fontsize = 15 align = right|nobaseline }}" -f $Indent,$closedZero,$storedPercent)
	}
	Add-Line $Lines ("{0}`t}}" -f $Indent)
	Add-Line $Lines ("{0}}} }}" -f $Indent)
}

function Add-FrozenIgBadge([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Indent = "`t`t`t`t`t`t`t`t`t") {
	Add-Line $Lines ("{0}widget = {{ size = {{ 300 30 }} hbox = {{ spacing = 6" -f $Indent)
	Add-Line $Lines ("{0}`twidget = {{ size = {{ 30 30 }}" -f $Indent)
	foreach ($mapping in $igTypeIdentities) {
		Add-Line $Lines ("{0}`t`ticon = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{1}_ig_type_identity').GetValue, '(CFixedPoint){2}')]`" size = {{ 30 30 }} texture = `"gfx/interface/icons/ig_icons/{3}`" tooltip = `"{4}`" }}" -f $Indent,$Prefix,$mapping.Id,$mapping.Texture,$mapping.Loc)
	}
	Add-Line $Lines ("{0}`t}}" -f $Indent)
	Add-AffiliationIdentityText $Lines $Prefix 'ig_type_identity' $igTypeIdentities 'vptl_presidential_history_unavailable_ig' '264 30' '15' ("{0}`t" -f $Indent)
	Add-Line $Lines ("{0}}} }}" -f $Indent)
}

function Add-ProfileScopeText([System.Collections.Generic.List[string]]$Lines, [string]$Prefix, [string]$Field, [string]$Getter, [string]$Context, [string]$Tooltip, [string]$LabelKey, [string]$Indent = "`t`t`t`t`t`t`t`t`t") {
	$variable = "${Prefix}_${Field}"
	Add-Line $Lines ("{0}widget = {{ size = {{ 226 32 }} hbox = {{ spacing = 4" -f $Indent)
	Add-Line $Lines ("{0}`ttextbox = {{ size = {{ 72 32 }} text = `"{1}`" fontsize = 14 align = left|nobaseline }}" -f $Indent,$LabelKey)
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[Country.MakeScope.Var('{1}').Get{2}.IsValid]`" size = {{ 150 32 }} datacontext = `"[Country.MakeScope.Var('{1}').Get{2}]`" raw_text = `"#v [Country.MakeScope.Var('{1}').Get{2}.GetNameNoFormatting]#!`" fontsize = 15 elide = right tooltipwidget = {{ {3} = {{}} }} }}" -f $Indent,$variable,$Getter,$Tooltip)
	Add-Line $Lines ("{0}`ttextbox = {{ visible = `"[Not(Country.MakeScope.Var('{1}').Get{2}.IsValid)]`" size = {{ 150 32 }} text = `"vptl_presidential_history_profile_unavailable`" fontsize = 15 elide = right }}" -f $Indent,$variable,$Getter)
	Add-Line $Lines ("{0}}}" -f $Indent)
	Add-Line $Lines ("{0}}}" -f $Indent)
}

$scopeFields = @('president','vice_president','party','ig','culture','religion','ideology','vice_president_culture','vice_president_religion','vice_president_ideology') + (1..8 | ForEach-Object { "law_$_" })
$percentageMetrics = @('gdp','population','sol','prestige')
$activePercentageFields = $percentageMetrics | ForEach-Object { "${_}_active_change_available"; "${_}_active_change_percent" }
$valueFields = @('president_identity','vice_president_identity','party_type_identity','ig_type_identity','ideology_identity','vice_president_ideology_identity','popularity','popularity_start','popularity_end','vice_president_popularity','vice_president_popularity_start','vice_president_popularity_end','number','accession_type','departure_reason','gdp_start','gdp_end','gdp_change_available','gdp_change_percent','gdp_active_change_available','gdp_active_change_percent','population_start','population_end','population_change_available','population_change_percent','population_active_change_available','population_active_change_percent','sol_start','sol_end','sol_change_available','sol_change_percent','sol_active_change_available','sol_active_change_percent','prestige_start','prestige_end','prestige_change_available','prestige_change_percent','prestige_active_change_available','prestige_active_change_percent','rank_start','rank_end','score_rank_start','score_rank_end','start_year','start_month','end_year','end_month','law_count','law_overflow_count')
$allFields = $scopeFields + $valueFields
$e = [System.Collections.Generic.List[string]]::new()
$e.Add('# Generated presidential-history effects: edit this generator, then regenerate the output.')
$e.Add('# Archive variables are durable country state; recent/display variables are copies for the library UI.')
$e.Add('')
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
Add-Line $e '\t# Stored in the save-compatible score_rank_* fields, but captured from'
Add-Line $e '\t# vanilla global_country_ranking so it matches the top-bar rank tooltip.'
Add-Line $e '\tset_variable = { name = vptl_history_capture_score_rank value = -1 }'
for ($i=1; $i -le 250; $i++) { Add-Line $e ("\tif = {{ limit = {{ global_country_ranking = {0} }} set_variable = {{ name = vptl_history_capture_score_rank value = {0} }} }}" -f $i) }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_latch_presidential_history_death_rank = {'
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_history_current_slot NOT = { has_variable = vptl_presidential_history_rank_latched } }'
Add-Line $e '\t\tvptl_capture_presidential_history_numeric_rank = yes'
Add-Line $e '\t\tif = { limit = { var:vptl_history_capture_score_rank > 0 }'
for ($i=1;$i -le 128;$i++) { $kw=if($i -eq 1){'if'}else{'else_if'}; Add-Line $e ("\t\t\t{0} = {{ limit = {{ var:vptl_presidential_history_current_slot = {1} has_variable = vptl_presidential_history_slot_{1}_populated NOT = {{ has_variable = vptl_presidential_history_slot_{1}_closed }} }} set_variable = {{ name = vptl_presidential_history_slot_{1}_score_rank_end value = var:vptl_history_capture_score_rank }} }}" -f $kw,$i) }
Add-Line $e '\t\t\tset_variable = vptl_presidential_history_rank_latched'
Add-Line $e '\t\t}'
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
foreach ($field in @('president','vice_president','party','ig','culture','religion','ideology','vice_president_culture','vice_president_religion','vice_president_ideology')) { Add-Line $e "\tremove_variable = vptl_history_capture_$field" }
Add-Line $e '\tset_variable = { name = vptl_history_capture_president_identity value = 0 }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_vice_president_identity value = 0 }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_vice_president_ideology_identity value = 0 }'
Add-Line $e '\tset_variable = { name = vptl_history_capture_popularity_start value = 0 }'
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
Add-IdentityCapture $e 'scope:vptl_history_capture_president' 'vptl_history_capture_president_identity' "`t`t"
Add-Line $e '\t\tif = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_order_number } } set_variable = { name = vptl_history_capture_number value = scope:vptl_history_capture_president.var:vptl_presidential_order_number } }'
Add-Line $e '\t\tif = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_elected } } set_variable = { name = vptl_history_capture_accession_type value = 1 } }'
Add-Line $e '\t\telse_if = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_succeeded } } set_variable = { name = vptl_history_capture_accession_type value = 2 } }'
Add-Line $e '\t\telse_if = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_interim } } set_variable = { name = vptl_history_capture_accession_type value = 3 } }'
Add-Line $e '\t\telse_if = { limit = { scope:vptl_history_capture_president = { has_variable = vptl_presidential_accession_provisional } } set_variable = { name = vptl_history_capture_accession_type value = 4 } }'
Add-Line $e '\t\tset_variable = { name = vptl_history_capture_popularity_start value = scope:vptl_history_capture_president.popularity }'
Add-Line $e '\t\tscope:vptl_history_capture_president = { this.interest_group ?= { save_scope_as = vptl_history_capture_ig party ?= { save_scope_as = vptl_history_capture_party } } culture ?= { save_scope_as = vptl_history_capture_culture } religion ?= { save_scope_as = vptl_history_capture_religion } ideology ?= { save_scope_as = vptl_history_capture_ideology } }'
Add-IdeologyIdentityCapture $e 'scope:vptl_history_capture_president' 'vptl_history_capture_ideology_identity' "`t`t"
Add-Line $e '\t}'
Add-Line $e '\t# The first tracked USA episode is Jackson''s real presidency, begun March 1829.'
Add-Line $e '\tif = { limit = { this = c:USA NOT = { has_variable = vptl_presidential_history_slot_1_populated } scope:vptl_history_capture_president ?= { OR = { has_variable = is_andrew_jackson has_template = usa_andrew_jackson_template } } } set_variable = { name = vptl_history_capture_year value = 1829 } set_variable = { name = vptl_history_capture_month value = 3 } set_variable = { name = vptl_history_capture_accession_type value = 1 } }'
Add-Line $e '\tif = { limit = { exists = scope:vptl_history_capture_ig } set_variable = { name = vptl_history_capture_ig value = scope:vptl_history_capture_ig } }'
Add-Line $e '\tif = { limit = { exists = scope:vptl_history_capture_party } set_variable = { name = vptl_history_capture_party value = scope:vptl_history_capture_party } }'
foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\tif = { limit = { exists = scope:vptl_history_capture_$field } set_variable = { name = vptl_history_capture_$field value = scope:vptl_history_capture_$field } }" }
Add-AffiliationIdentityCapture $e 'scope:vptl_history_capture_party' 'vptl_history_capture_party_type_identity' $partyTypeIdentities 'is_party_type' "`t"
Add-AffiliationIdentityCapture $e 'scope:vptl_history_capture_ig' 'vptl_history_capture_ig_type_identity' $igTypeIdentities 'is_interest_group_type' "`t"
Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_successor var:vptl_presidential_successor ?= { is_character_alive = yes } } var:vptl_presidential_successor ?= { if = { limit = { NOT = { has_role = character_role_vptl_presidential_history_subject } } add_character_role = character_role_vptl_presidential_history_subject } } set_variable = { name = vptl_history_capture_vice_president value = var:vptl_presidential_successor }'
Add-IdentityCapture $e 'var:vptl_presidential_successor' 'vptl_history_capture_vice_president_identity' "`t`t"
Add-Line $e '\t\tvar:vptl_presidential_successor ?= { culture ?= { save_scope_as = vptl_history_capture_vice_president_culture } religion ?= { save_scope_as = vptl_history_capture_vice_president_religion } ideology ?= { save_scope_as = vptl_history_capture_vice_president_ideology } }'
Add-IdeologyIdentityCapture $e 'var:vptl_presidential_successor' 'vptl_history_capture_vice_president_ideology_identity' "`t`t"
Add-Line $e '\t\tset_variable = { name = vptl_history_capture_vice_president_popularity_start value = var:vptl_presidential_successor.popularity }'
Add-Line $e '\t}'
foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\tif = { limit = { exists = scope:vptl_history_capture_vice_president_$field } set_variable = { name = vptl_history_capture_vice_president_$field value = scope:vptl_history_capture_vice_president_$field } }" }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_freeze_presidential_history_affiliations_for_record = {'
Add-Line $e '\t# Legacy records derive each broad category once from their still-valid scope.'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated NOT = { has_variable = $PREFIX$_party_type_identity } }'
Add-AffiliationIdentityCapture $e 'var:$PREFIX$_party' '$PREFIX$_party_type_identity' $partyTypeIdentities 'is_party_type' "`t`t"
Add-Line $e '\t}'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated NOT = { has_variable = $PREFIX$_ig_type_identity } }'
Add-AffiliationIdentityCapture $e 'var:$PREFIX$_ig' '$PREFIX$_ig_type_identity' $igTypeIdentities 'is_interest_group_type' "`t`t"
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_migrate_presidential_history_affiliation_identities = {'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_affiliation_identities_migrated } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e ("`t`tvptl_freeze_presidential_history_affiliations_for_record = {{ PREFIX = vptl_presidential_history_slot_{0} }}" -f $i) }
for ($i=1;$i -le 50;$i++) { Add-Line $e ("`t`tvptl_freeze_presidential_history_affiliations_for_record = {{ PREFIX = vptl_presidential_history_recent_{0} }}" -f $i) }
Add-Line $e '\t\tset_variable = vptl_presidential_history_affiliation_identities_migrated'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_freeze_presidential_history_profile_for_record = {'
Add-Line $e '\t# Backfill old records once, and only while their original president resolves.'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated var:$PREFIX$_president ?= { is_character_alive = yes } OR = { NOT = { has_variable = $PREFIX$_culture } NOT = { has_variable = $PREFIX$_religion } NOT = { has_variable = $PREFIX$_ideology } NOT = { has_variable = $PREFIX$_ideology_identity } NOT = { has_variable = $PREFIX$_popularity_start } NOT = { has_variable = $PREFIX$_popularity } } }'
Add-Line $e '\t\tvar:$PREFIX$_president ?= { save_scope_as = vptl_history_profile_subject culture ?= { save_scope_as = vptl_history_capture_culture } religion ?= { save_scope_as = vptl_history_capture_religion } ideology ?= { save_scope_as = vptl_history_capture_ideology } }'
foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\t\tif = { limit = { NOT = { has_variable = `$PREFIX`$_$field } exists = scope:vptl_history_capture_$field } set_variable = { name = `$PREFIX`$_$field value = scope:vptl_history_capture_$field } }" }
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_ideology_identity } }'
Add-IdeologyIdentityCapture $e 'var:$PREFIX$_president' '$PREFIX$_ideology_identity' "`t`t`t"
Add-Line $e '\t\t}'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_popularity_start } has_variable = $PREFIX$_popularity } set_variable = { name = $PREFIX$_popularity_start value = var:$PREFIX$_popularity } }'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_popularity_start } exists = scope:vptl_history_profile_subject } set_variable = { name = $PREFIX$_popularity_start value = scope:vptl_history_profile_subject.popularity } }'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_popularity } has_variable = $PREFIX$_popularity_start } set_variable = { name = $PREFIX$_popularity value = var:$PREFIX$_popularity_start } }'
Add-Line $e '\t}'
foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\tremove_variable = vptl_history_capture_$field" }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_migrate_presidential_history_profiles = {'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_profiles_migrated } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e ("\t\tvptl_freeze_presidential_history_profile_for_record = {{ PREFIX = vptl_presidential_history_slot_{0} }}" -f $i) }
for ($i=1;$i -le 50;$i++) { Add-Line $e ("\t\tvptl_freeze_presidential_history_profile_for_record = {{ PREFIX = vptl_presidential_history_recent_{0} }}" -f $i) }
Add-Line $e '\t\tset_variable = vptl_presidential_history_profiles_migrated'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_freeze_presidential_history_vice_president_profile_for_record = {'
Add-Line $e '\t# Legacy VP profiles are backfilled only from the exact stored deputy.'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated var:$PREFIX$_vice_president ?= { is_character_alive = yes } OR = { NOT = { has_variable = $PREFIX$_vice_president_culture } NOT = { has_variable = $PREFIX$_vice_president_religion } NOT = { has_variable = $PREFIX$_vice_president_ideology } NOT = { has_variable = $PREFIX$_vice_president_ideology_identity } NOT = { has_variable = $PREFIX$_vice_president_popularity_start } NOT = { has_variable = $PREFIX$_vice_president_popularity } } }'
Add-Line $e '\t\tvar:$PREFIX$_vice_president ?= { save_scope_as = vptl_history_vice_president_profile_subject culture ?= { save_scope_as = vptl_history_capture_vice_president_culture } religion ?= { save_scope_as = vptl_history_capture_vice_president_religion } ideology ?= { save_scope_as = vptl_history_capture_vice_president_ideology } }'
foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\t\tif = { limit = { NOT = { has_variable = `$PREFIX`$_vice_president_$field } exists = scope:vptl_history_capture_vice_president_$field } set_variable = { name = `$PREFIX`$_vice_president_$field value = scope:vptl_history_capture_vice_president_$field } }" }
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_vice_president_ideology_identity } }'
Add-IdeologyIdentityCapture $e 'var:$PREFIX$_vice_president' '$PREFIX$_vice_president_ideology_identity' "`t`t`t"
Add-Line $e '\t\t}'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_vice_president_popularity_start } exists = scope:vptl_history_vice_president_profile_subject } set_variable = { name = $PREFIX$_vice_president_popularity_start value = scope:vptl_history_vice_president_profile_subject.popularity } }'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = $PREFIX$_vice_president_popularity } has_variable = $PREFIX$_vice_president_popularity_start } set_variable = { name = $PREFIX$_vice_president_popularity value = var:$PREFIX$_vice_president_popularity_start } }'
Add-Line $e '\t}'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated has_variable = $PREFIX$_closed NOT = { has_variable = $PREFIX$_vice_president_popularity_end } }'
Add-Line $e '\t\tif = { limit = { has_variable = $PREFIX$_vice_president_popularity } set_variable = { name = $PREFIX$_vice_president_popularity_end value = var:$PREFIX$_vice_president_popularity } }'
Add-Line $e '\t\telse_if = { limit = { has_variable = $PREFIX$_vice_president_popularity_start } set_variable = { name = $PREFIX$_vice_president_popularity_end value = var:$PREFIX$_vice_president_popularity_start } }'
Add-Line $e '\t}'
foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\tremove_variable = vptl_history_capture_vice_president_$field" }
Add-Line $e '\tremove_variable = vptl_history_vice_president_profile_subject'
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_migrate_presidential_history_vice_president_profiles = {'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_vice_president_profiles_migrated } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e ("\t\tvptl_freeze_presidential_history_vice_president_profile_for_record = {{ PREFIX = vptl_presidential_history_slot_{0} }}" -f $i) }
for ($i=1;$i -le 50;$i++) { Add-Line $e ("\t\tvptl_freeze_presidential_history_vice_president_profile_for_record = {{ PREFIX = vptl_presidential_history_recent_{0} }}" -f $i) }
Add-Line $e '\t\tset_variable = vptl_presidential_history_vice_president_profiles_migrated'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_migrate_presidential_history_metric_snapshots_for_record = {'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated NOT = { has_variable = $PREFIX$_closed } }'
foreach ($field in @('gdp_end','population_end','sol_end','prestige_end','rank_end','score_rank_end','popularity_end') + ($percentageMetrics | ForEach-Object { "${_}_change_available"; "${_}_change_percent" }) + $activePercentageFields) { Add-Line $e "\t\tremove_variable = `$PREFIX`$_$field".Replace('`$','$') }
Add-Line $e '\t}'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated has_variable = $PREFIX$_closed NOT = { has_variable = $PREFIX$_popularity_end } }'
Add-Line $e '\t\tif = { limit = { has_variable = $PREFIX$_popularity } set_variable = { name = $PREFIX$_popularity_end value = var:$PREFIX$_popularity } }'
Add-Line $e '\t\telse_if = { limit = { has_variable = $PREFIX$_popularity_start } set_variable = { name = $PREFIX$_popularity_end value = var:$PREFIX$_popularity_start } }'
Add-Line $e '\t}'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated has_variable = $PREFIX$_closed NOT = { has_variable = $PREFIX$_score_rank_end } has_variable = $PREFIX$_score_rank_start $PREFIX$_score_rank_start > 0 } set_variable = { name = $PREFIX$_score_rank_end value = var:$PREFIX$_score_rank_start } }'
foreach ($metric in $percentageMetrics) { Add-PercentCalculation $e '$PREFIX$' $metric "\t" $true }
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_migrate_presidential_history_metric_snapshots = {'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_metric_snapshots_migrated } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e ("\t\tvptl_migrate_presidential_history_metric_snapshots_for_record = {{ PREFIX = vptl_presidential_history_slot_{0} }}" -f $i) }
for ($i=1;$i -le 50;$i++) { Add-Line $e ("\t\tvptl_migrate_presidential_history_metric_snapshots_for_record = {{ PREFIX = vptl_presidential_history_recent_{0} }}" -f $i) }
Add-Line $e '\t\tset_variable = vptl_presidential_history_metric_snapshots_migrated'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_migrate_presidential_history_metric_percentages = {'
Add-Line $e '\t# Versioned backfill for saves that already ran the original metric migration.'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_metric_percentages_migrated } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e ("\t\tvptl_migrate_presidential_history_metric_snapshots_for_record = {{ PREFIX = vptl_presidential_history_slot_{0} }}" -f $i) }
for ($i=1;$i -le 50;$i++) { Add-Line $e ("\t\tvptl_migrate_presidential_history_metric_snapshots_for_record = {{ PREFIX = vptl_presidential_history_recent_{0} }}" -f $i) }
Add-Line $e '\t\tset_variable = vptl_presidential_history_metric_percentages_migrated'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_migrate_presidential_history_closed_rank_fallback_for_record = {'
Add-Line $e '\tif = { limit = { has_variable = $PREFIX$_populated has_variable = $PREFIX$_closed NOT = { has_variable = $PREFIX$_score_rank_end } has_variable = $PREFIX$_score_rank_start $PREFIX$_score_rank_start > 0 }'
Add-Line $e '\t\tset_variable = { name = $PREFIX$_score_rank_end value = var:$PREFIX$_score_rank_start }'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e

Add-Line $e 'vptl_migrate_presidential_history_closed_rank_fallback = {'
Add-Line $e '\tif = { limit = { NOT = { has_variable = vptl_presidential_history_closed_rank_fallback_migrated } }'
for ($i=1;$i -le 128;$i++) { Add-Line $e ("\t\tvptl_migrate_presidential_history_closed_rank_fallback_for_record = {{ PREFIX = vptl_presidential_history_slot_{0} }}" -f $i) }
for ($i=1;$i -le 50;$i++) { Add-Line $e ("\t\tvptl_migrate_presidential_history_closed_rank_fallback_for_record = {{ PREFIX = vptl_presidential_history_recent_{0} }}" -f $i) }
Add-Line $e '\t\tset_variable = vptl_presidential_history_closed_rank_fallback_migrated'
Add-Line $e '\t}'
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
foreach ($f in @('vice_president','party','ig','culture','religion','ideology','vice_president_culture','vice_president_religion','vice_president_ideology')) { Add-Line $e "\tif = { limit = { has_variable = vptl_history_capture_$f } set_variable = { name = vptl_presidential_history_recent_1_$f value = var:vptl_history_capture_$f } } else = { remove_variable = vptl_presidential_history_recent_1_$f }" }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_president_identity value = var:vptl_history_capture_president_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_vice_president_identity value = var:vptl_history_capture_vice_president_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_party_type_identity value = var:vptl_history_capture_party_type_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_ig_type_identity value = var:vptl_history_capture_ig_type_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_ideology_identity value = var:vptl_history_capture_ideology_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_vice_president_ideology_identity value = var:vptl_history_capture_vice_president_ideology_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_popularity_start value = var:vptl_history_capture_popularity_start }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_popularity value = var:vptl_history_capture_popularity_start }'
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_popularity_end'
Add-Line $e '\tif = { limit = { has_variable = vptl_history_capture_vice_president_popularity_start } set_variable = { name = vptl_presidential_history_recent_1_vice_president_popularity_start value = var:vptl_history_capture_vice_president_popularity_start } set_variable = { name = vptl_presidential_history_recent_1_vice_president_popularity value = var:vptl_history_capture_vice_president_popularity_start } } else = { remove_variable = vptl_presidential_history_recent_1_vice_president_popularity_start remove_variable = vptl_presidential_history_recent_1_vice_president_popularity }'
Add-Line $e '\tremove_variable = vptl_presidential_history_recent_1_vice_president_popularity_end'
foreach ($f in @('number','accession_type')) { Add-Line $e "\tset_variable = { name = vptl_presidential_history_recent_1_$f value = var:vptl_history_capture_$f }" }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_recent_1_departure_reason value = 0 }'
foreach ($f in @('gdp','population','sol','prestige')) { Add-Line $e "\tset_variable = { name = vptl_presidential_history_recent_1_${f}_start value = var:vptl_history_capture_${f}_start }"; Add-Line $e "\tremove_variable = vptl_presidential_history_recent_1_${f}_end" }
foreach ($f in ($percentageMetrics | ForEach-Object { "${_}_change_available"; "${_}_change_percent" })) { Add-Line $e "\tremove_variable = vptl_presidential_history_recent_1_$f" }
foreach ($f in $activePercentageFields) { Add-Line $e "\tremove_variable = vptl_presidential_history_recent_1_$f" }
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
foreach ($f in @('vice_president','party','ig','culture','religion','ideology','vice_president_culture','vice_president_religion','vice_president_ideology')) { Add-Line $e "\tif = { limit = { has_variable = vptl_history_capture_$f } set_variable = { name = vptl_presidential_history_slot_`$SLOT`$_$f value = var:vptl_history_capture_$f } }".Replace('`$','$') }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_president_identity value = var:vptl_history_capture_president_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_identity value = var:vptl_history_capture_vice_president_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_party_type_identity value = var:vptl_history_capture_party_type_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_ig_type_identity value = var:vptl_history_capture_ig_type_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_ideology_identity value = var:vptl_history_capture_ideology_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_ideology_identity value = var:vptl_history_capture_vice_president_ideology_identity }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_popularity_start value = var:vptl_history_capture_popularity_start }'
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_popularity value = var:vptl_history_capture_popularity_start }'
Add-Line $e '\tif = { limit = { has_variable = vptl_history_capture_vice_president_popularity_start } set_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_popularity_start value = var:vptl_history_capture_vice_president_popularity_start } set_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_popularity value = var:vptl_history_capture_vice_president_popularity_start } }'
foreach ($f in @('number','accession_type')) { Add-Line $e "\tset_variable = { name = vptl_presidential_history_slot_`$SLOT`$_$f value = var:vptl_history_capture_$f }".Replace('`$','$') }
Add-Line $e '\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_departure_reason value = 0 }'
foreach ($f in @('gdp','population','sol','prestige')) { Add-Line $e ("\tset_variable = {{ name = vptl_presidential_history_slot_`$SLOT`$_{0}_start value = var:vptl_history_capture_{0}_start }}" -f $f).Replace('`$','$') }
foreach ($f in @('gdp_end','population_end','sol_end','prestige_end','rank_end','score_rank_end','popularity_end','vice_president_popularity_end') + ($percentageMetrics | ForEach-Object { "${_}_change_available"; "${_}_change_percent" }) + $activePercentageFields) { Add-Line $e "\tremove_variable = vptl_presidential_history_slot_`$SLOT`$_$f".Replace('`$','$') }
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
foreach ($f in @('president','vice_president','party','ig','culture','religion','ideology','vice_president_culture','vice_president_religion','vice_president_ideology','president_identity','vice_president_identity','party_type_identity','ig_type_identity','ideology_identity','vice_president_ideology_identity','popularity','popularity_start','popularity_end','vice_president_popularity_start','number','accession_type','gdp_start','population_start','sol_start','prestige_start','rank','score_rank','year','month')) { Add-Line $e "\tremove_variable = vptl_history_capture_$f" }
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_finalize_presidential_history_archive_slot = {'
Add-Line $e '\tif = { limit = { var:vptl_presidential_history_current_slot = $SLOT$ has_variable = vptl_presidential_history_slot_$SLOT$_populated NOT = { has_variable = vptl_presidential_history_slot_$SLOT$_closed } }'
foreach ($f in @('gdp','total_population','average_sol','prestige')) { $name=@{'gdp'='gdp';'total_population'='population';'average_sol'='sol';'prestige'='prestige'}[$f]; Add-Line $e "\t\tset_variable = { name = vptl_presidential_history_slot_`$SLOT`$_${name}_end value = $f }".Replace('`$','$') }
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_rank_end value = var:vptl_history_capture_rank }'
Add-Line $e '\t\tif = { limit = { NOT = { has_variable = vptl_presidential_history_slot_$SLOT$_score_rank_end } var:vptl_history_capture_score_rank > 0 } set_variable = { name = vptl_presidential_history_slot_$SLOT$_score_rank_end value = var:vptl_history_capture_score_rank } }'
foreach ($metric in $percentageMetrics) { Add-PercentCalculation $e 'vptl_presidential_history_slot_$SLOT$' $metric "\t\t" $false }
foreach ($field in $activePercentageFields) { Add-Line $e "\t\tremove_variable = vptl_presidential_history_slot_`$SLOT`$_$field".Replace('`$','$') }
Add-Line $e '\t\t# Prefer the outgoing president, then the maintained active value, then the accession baseline.'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_popularity_start }'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_slot_$SLOT$_popularity } set_variable = { name = vptl_presidential_history_slot_$SLOT$_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_popularity } }'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_current_president var:vptl_presidential_history_current_president ?= { is_character_alive = yes } } set_variable = { name = vptl_presidential_history_slot_$SLOT$_popularity_end value = var:vptl_presidential_history_current_president.popularity } }'
Add-Line $e '\t\t# The closing record owns the final VP value; later successor changes cannot replace it.'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_slot_$SLOT$_vice_president_popularity_start } set_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_vice_president_popularity_start } }'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_slot_$SLOT$_vice_president_popularity } set_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_vice_president_popularity } }'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_slot_$SLOT$_vice_president var:vptl_presidential_history_slot_$SLOT$_vice_president ?= { is_character_alive = yes } } set_variable = { name = vptl_presidential_history_slot_$SLOT$_vice_president_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_vice_president.popularity } }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_departure_reason value = var:vptl_presidential_history_departure_reason }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_end_year value = var:vptl_history_capture_year }'
Add-Line $e '\t\tset_variable = { name = vptl_presidential_history_slot_$SLOT$_end_month value = var:vptl_history_capture_month }'
Add-Line $e '\t\tset_variable = vptl_presidential_history_slot_$SLOT$_closed remove_variable = vptl_presidential_history_slot_$SLOT$_active'
Add-Line $e '\t\t# Mirror the finalized archive snapshot before the recent cache shifts the episode.'
Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_recent_1_populated NOT = { has_variable = vptl_presidential_history_recent_1_closed } }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_gdp_end value = var:vptl_presidential_history_slot_$SLOT$_gdp_end } set_variable = { name = vptl_presidential_history_recent_1_population_end value = var:vptl_presidential_history_slot_$SLOT$_population_end } set_variable = { name = vptl_presidential_history_recent_1_sol_end value = var:vptl_presidential_history_slot_$SLOT$_sol_end } set_variable = { name = vptl_presidential_history_recent_1_prestige_end value = var:vptl_presidential_history_slot_$SLOT$_prestige_end }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_rank_end value = var:vptl_presidential_history_slot_$SLOT$_rank_end } set_variable = { name = vptl_presidential_history_recent_1_score_rank_end value = var:vptl_presidential_history_slot_$SLOT$_score_rank_end }'
	Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_popularity_end }'
	Add-Line $e '\t\t\tif = { limit = { has_variable = vptl_presidential_history_slot_$SLOT$_vice_president_popularity_end } set_variable = { name = vptl_presidential_history_recent_1_vice_president_popularity_end value = var:vptl_presidential_history_slot_$SLOT$_vice_president_popularity_end } } else = { remove_variable = vptl_presidential_history_recent_1_vice_president_popularity_end }'
	foreach ($metric in $percentageMetrics) { Add-Line $e "\t\t\tif = { limit = { has_variable = vptl_presidential_history_slot_`$SLOT`$_${metric}_change_available } set_variable = { name = vptl_presidential_history_recent_1_${metric}_change_available } set_variable = { name = vptl_presidential_history_recent_1_${metric}_change_percent value = var:vptl_presidential_history_slot_`$SLOT`$_${metric}_change_percent } } else = { remove_variable = vptl_presidential_history_recent_1_${metric}_change_available remove_variable = vptl_presidential_history_recent_1_${metric}_change_percent }".Replace('`$','$') }
	Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_departure_reason value = var:vptl_presidential_history_departure_reason } set_variable = { name = vptl_presidential_history_recent_1_end_year value = var:vptl_history_capture_year } set_variable = { name = vptl_presidential_history_recent_1_end_month value = var:vptl_history_capture_month } set_variable = vptl_presidential_history_recent_1_closed'
Add-Line $e '\t\t}'
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
Add-Line $e '\t\tif = {'
Add-Line $e '\t\t\tlimit = { has_variable = vptl_presidential_history_current_president }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_previous_president value = var:vptl_presidential_history_current_president }'
Add-Line $e '\t\t\tif = { limit = { var:vptl_presidential_history_current_president ?= { has_variable = vptl_presidential_order_number } } set_variable = { name = vptl_presidential_history_previous_number value = var:vptl_presidential_history_current_president.var:vptl_presidential_order_number } }'
Add-Line $e '\t\t}'
Add-Line $e '\t\tclear_variable_list = vptl_presidential_history_active_laws_seen remove_variable = vptl_presidential_history_current_slot remove_variable = vptl_presidential_history_current_president remove_variable = vptl_presidential_history_departure_reason remove_variable = vptl_history_capture_year remove_variable = vptl_history_capture_month remove_variable = vptl_history_capture_rank remove_variable = vptl_history_capture_score_rank remove_variable = vptl_presidential_history_rank_latched remove_variable = vptl_presidential_history_close_in_progress'
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_refresh_presidential_history_archive_slot = {'
	Add-Line $e '\t# Retained as a compatibility no-op; closed final metrics are never refreshed.'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_refresh_open_presidential_history_episode = {'
	Add-Line $e '\t# Historical final metrics are immutable; active cards bind directly to current Country values.'
	Add-Line $e '\t# Only the associated successor and its active profile may refresh while the episode stays open.'
	Add-Line $e '\tif = { limit = { has_variable = vptl_presidential_history_current_slot has_variable = vptl_presidential_history_current_president NOT = { has_variable = vptl_presidential_history_close_in_progress } }'
	Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_successor }'
Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_vice_president value = var:vptl_presidential_successor }'
Add-IdentityCapture $e 'var:vptl_presidential_successor' 'vptl_presidential_history_recent_1_vice_president_identity' "`t`t`t"
	Add-Line $e '\t\t\tvar:vptl_presidential_successor ?= { culture ?= { save_scope_as = vptl_history_capture_vice_president_culture } religion ?= { save_scope_as = vptl_history_capture_vice_president_religion } ideology ?= { save_scope_as = vptl_history_capture_vice_president_ideology } }'
	Add-IdeologyIdentityCapture $e 'var:vptl_presidential_successor' 'vptl_history_capture_vice_president_ideology_identity' "`t`t`t"
	Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_vice_president_ideology_identity value = var:vptl_history_capture_vice_president_ideology_identity }'
	foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\t\t\tif = { limit = { exists = scope:vptl_history_capture_vice_president_$field } set_variable = { name = vptl_presidential_history_recent_1_vice_president_$field value = scope:vptl_history_capture_vice_president_$field } } else = { remove_variable = vptl_presidential_history_recent_1_vice_president_$field }" }
	Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_vice_president_popularity_start value = var:vptl_presidential_successor.popularity }'
	Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_vice_president_popularity value = var:vptl_presidential_successor.popularity }'
	for ($i=1;$i -le 128;$i++) {
		Add-Line $e "\t\t\tif = { limit = { var:vptl_presidential_history_current_slot = $i } set_variable = { name = vptl_presidential_history_slot_${i}_vice_president value = var:vptl_presidential_successor } set_variable = { name = vptl_presidential_history_slot_${i}_vice_president_identity value = var:vptl_presidential_history_recent_1_vice_president_identity } set_variable = { name = vptl_presidential_history_slot_${i}_vice_president_ideology_identity value = var:vptl_history_capture_vice_president_ideology_identity } set_variable = { name = vptl_presidential_history_slot_${i}_vice_president_popularity_start value = var:vptl_presidential_successor.popularity } set_variable = { name = vptl_presidential_history_slot_${i}_vice_president_popularity value = var:vptl_presidential_successor.popularity }"
		foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\t\t\t\tif = { limit = { exists = scope:vptl_history_capture_vice_president_$field } set_variable = { name = vptl_presidential_history_slot_${i}_vice_president_$field value = scope:vptl_history_capture_vice_president_$field } } else = { remove_variable = vptl_presidential_history_slot_${i}_vice_president_$field }" }
		Add-Line $e '\t\t\t}'
	}
	Add-Line $e '\t\t}'
	Add-Line $e '\t\telse = {'
	foreach ($field in @('vice_president','vice_president_identity','vice_president_culture','vice_president_religion','vice_president_ideology','vice_president_ideology_identity','vice_president_popularity_start','vice_president_popularity','vice_president_popularity_end')) { Add-Line $e "\t\t\tremove_variable = vptl_presidential_history_recent_1_$field" }
	for ($i=1;$i -le 128;$i++) {
		Add-Line $e "\t\t\tif = { limit = { var:vptl_presidential_history_current_slot = $i }"
		foreach ($field in @('vice_president','vice_president_identity','vice_president_culture','vice_president_religion','vice_president_ideology','vice_president_ideology_identity','vice_president_popularity_start','vice_president_popularity','vice_president_popularity_end')) { Add-Line $e "\t\t\t\tremove_variable = vptl_presidential_history_slot_${i}_$field" }
		Add-Line $e '\t\t\t}'
	}
	Add-Line $e '\t\t}'
	foreach ($field in @('culture','religion','ideology')) { Add-Line $e "\t\tremove_variable = vptl_history_capture_vice_president_$field" }
	Add-Line $e '\t\tremove_variable = vptl_history_capture_vice_president_ideology_identity'
	Add-Line $e '\t\tif = { limit = { has_variable = vptl_presidential_history_current_president var:vptl_presidential_history_current_president ?= { is_character_alive = yes } }'
	Add-Line $e '\t\t\tset_variable = { name = vptl_presidential_history_recent_1_popularity value = var:vptl_presidential_history_current_president.popularity }'
	for ($i=1;$i -le 128;$i++) { Add-Line $e "\t\t\tif = { limit = { var:vptl_presidential_history_current_slot = $i } set_variable = { name = vptl_presidential_history_slot_${i}_popularity value = var:vptl_presidential_history_current_president.popularity } }" }
	Add-Line $e '\t\t}'
	$liveMetricValues = @(@('gdp','gdp'), @('population','total_population'), @('sol','average_sol'), @('prestige','prestige'))
	foreach ($mapping in $liveMetricValues) { Add-LivePercentCalculation $e 'vptl_presidential_history_recent_1' $mapping[0] $mapping[1] "\t\t" }
	for ($i=1;$i -le 128;$i++) {
		foreach ($mapping in $liveMetricValues) {
			Add-Line $e "\t\tif = { limit = { var:vptl_presidential_history_current_slot = $i }"
			Add-LivePercentCalculation $e "vptl_presidential_history_slot_${i}" $mapping[0] $mapping[1] "\t\t\t"
			Add-Line $e '\t\t}'
		}
	}
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
Add-Line $e '\t\tset_variable = vptl_presidential_history_display_$SLOT$_populated'
Add-Line $e '\t}'
Add-Line $e '\telse = {'
foreach ($f in $allFields + @('closed','populated') + ($percentageMetrics | ForEach-Object { "${_}_change_available"; "${_}_change_percent" })) { Add-Line $e "\t\tremove_variable = vptl_presidential_history_display_`$SLOT`$_$f".Replace('`$','$') }
Add-Line $e '\t}'
Add-Line $e '}'
Add-Line $e
Add-Line $e 'vptl_load_presidential_history_latest_50 = {'
Add-Line $e '\tvptl_migrate_presidential_history_affiliation_identities = yes'
Add-Line $e '\tvptl_migrate_presidential_history_profiles = yes'
Add-Line $e '\tvptl_migrate_presidential_history_vice_president_profiles = yes'
Add-Line $e '\tvptl_migrate_presidential_history_metric_snapshots = yes'
Add-Line $e '\tvptl_migrate_presidential_history_metric_percentages = yes'
Add-Line $e '\tvptl_migrate_presidential_history_closed_rank_fallback = yes'
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
Add-Line $e '\t\tvptl_refresh_open_presidential_history_episode = yes'
Add-Line $e '\t\tremove_variable = vptl_presidential_history_sync_in_progress'
Add-Line $e '\t}'
Add-Line $e '}'

$effectsText = (($e -join "`r`n") + "`r`n").Replace('\t', "`t")
[System.IO.File]::WriteAllText($effectsPath, $effectsText, $utf8Bom)

# The GUI is generated separately below so all 50 fixed cards stay identical.
$g = [System.Collections.Generic.List[string]]::new()
$g.Add('# Generated Presidential Library window: edit the generator rather than this output file.')
$g.Add('# The GUI reads prepared country variables and checks scope validity before showing names or icons.')
$g.Add('')
# tooltipwidget resolves custom FancyTooltipWidgetType derivatives from the
# vanilla TooltipTypes registry. Keep the individual type names namespaced
# with vptl_, but register them where the engine looks them up at hover time.
Add-Line $g 'types TooltipTypes {'
for ($s=1;$s -le 50;$s++) {
	Add-ExecutiveProfileTooltipType $g $s 'president' ("vptl_presidential_history_profile_tooltip_{0}" -f $s) 'vptl_presidential_history_profile_tooltip_title' 'vptl_presidential_history_unavailable_president'
	Add-ExecutiveProfileTooltipType $g $s 'vice_president' ("vptl_presidential_history_vice_president_profile_tooltip_{0}" -f $s) 'vptl_presidential_history_vice_president_profile_tooltip_title' 'vptl_presidential_history_unavailable_vice_president'
}
Add-Line $g '}'
Add-Line $g ''
Add-Line $g 'window = {'; Add-Line $g '\tname = "vptl_presidential_history_window"'; Add-Line $g '\tlayer = top'; Add-Line $g '\tparentanchor = center'; Add-Line $g '\tsize = { 1040 850 }'; Add-Line $g '\tallow_outside = yes'; Add-Line $g '\tvisible = "[And(GetVariableSystem.Exists(''vptl_presidential_history_panel_open''), GetMetaPlayer.GetPlayedOrObservedCountry.IsValid)]"'; Add-Line $g '\tdatacontext = "[GetMetaPlayer.GetPlayedOrObservedCountry]"'; Add-Line $g '\tbackground = { using = paper_bg }'
Add-Line $g '\tvbox = {'; Add-Line $g '\t\tmargin = { 24 18 }'; Add-Line $g '\t\tspacing = 7'; Add-Line $g '\t\tlayoutpolicy_horizontal = expanding'; Add-Line $g '\t\tlayoutpolicy_vertical = expanding'; Add-Line $g '\t\thbox = {'; Add-Line $g '\t\t\tlayoutpolicy_horizontal = expanding'; Add-Line $g '\t\t\tsize = { 992 42 }'; Add-Line $g '\t\t\ttextbox = { text = "vptl_presidential_library_title" fontsize = 28 align = center|nobaseline layoutpolicy_horizontal = expanding }'; Add-Line $g '\t\t\tbutton = { size = { 36 36 } using = default_button_primary onclick = "[GetVariableSystem.Clear(''vptl_presidential_history_panel_open'')]" icon = { parentanchor = center size = { 22 22 } texture = "gfx/interface/buttons/button_icons/close.dds" } }'; Add-Line $g '\t\t}'
Add-Line $g '\t\ttextbox = { visible = "[LessThan_CFixedPoint(Country.MakeScope.Var(''vptl_presidential_history_display_count'').GetValue, ''(CFixedPoint)1'')]" layoutpolicy_horizontal = expanding size = { 992 80 } text = "vptl_presidential_history_empty" align = center|nobaseline fontsize = 18 }'
Add-Line $g '\t\tscrollarea = {'; Add-Line $g '\t\t\tvisible = "[GreaterThanOrEqualTo_CFixedPoint(Country.MakeScope.Var(''vptl_presidential_history_display_count'').GetValue, ''(CFixedPoint)1'')]"'; Add-Line $g '\t\t\tsize = { 992 770 }'; Add-Line $g '\t\t\tscrollbarpolicy_horizontal = always_off'; Add-Line $g '\t\t\tscrollbaralign_vertical = right'; Add-Line $g '\t\t\tscrollbar_vertical = { using = vertical_scrollbar }'; Add-Line $g '\t\t\tscrollwidget = {'; Add-Line $g '\t\t\t\tvbox = {'; Add-Line $g '\t\t\t\t\tlayoutpolicy_horizontal = expanding'; Add-Line $g '\t\t\t\t\tlayoutpolicy_vertical = preferred'; Add-Line $g '\t\t\t\t\tspacing = 5'
for ($s=1;$s -le 50;$s++) {
	$p="vptl_presidential_history_display_${s}"
	# A missing closed marker means the active record is still open.
	$closed="And(Country.MakeScope.Var('${p}_closed').IsSet, GreaterThan_CFixedPoint(Country.MakeScope.Var('${p}_closed').GetValue, '(CFixedPoint)0'))"
	$open="Not($closed)"
	$rankClosed=Gui-And @($closed, "Country.MakeScope.Var('${p}_score_rank_end').IsSet", "GreaterThan_CFixedPoint(Country.MakeScope.Var('${p}_score_rank_end').GetValue, '(CFixedPoint)0')")
	$rankMissingClosed="And($closed, Not($rankClosed))"
	Add-Line $g '\t\t\t\t\twidget = {'
	Add-Line $g ("\t\t\t\t\t\tvisible = `"[And(GreaterThanOrEqualTo_CFixedPoint(Country.MakeScope.Var('vptl_presidential_history_display_count').GetValue, '(CFixedPoint){0}'), Country.MakeScope.Var('{1}_populated').IsSet)]`"" -f $s,$p)
	Add-Line $g '\t\t\t\t\t\tsize = { 964 174 }'
	Add-Line $g '\t\t\t\t\t\tbackground = { using = entry_bg_fancy_dark alpha = 0.42 }'
	Add-Line $g '\t\t\t\t\t\thbox = {'; Add-Line $g '\t\t\t\t\t\t\tmargin = { 18 8 }'; Add-Line $g '\t\t\t\t\t\t\tvbox = {'; Add-Line $g '\t\t\t\t\t\t\t\tspacing = 2'

	# Fixed header grid: number, president, deputy, and year-only service dates.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = { spacing = 6'
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ 64 34 }} raw_text = `"#BOLD No. [Country.MakeScope.Var('{0}_number').GetValue|0]#!`" fontsize = 18 align = left|nobaseline }}" -f $p)
	Add-IdentityFallbackText $g $p 'president' 'vptl_presidential_history_unavailable_president' '300 34' '24' -TooltipWidget ("vptl_presidential_history_profile_tooltip_{0}" -f $s)
	Add-Line $g '\t\t\t\t\t\t\t\t\twidget = { size = { 314 34 } hbox = { spacing = 6'
	Add-Line $g '\t\t\t\t\t\t\t\t\t\ttextbox = { size = { 106 34 } raw_text = "#weak [GetPlayer.GetCustom(''vptl_presidential_successor_title'')]:#!" fontsize = 14 elide = right align = right|nobaseline }'
	Add-IdentityFallbackText $g $p 'vice_president' 'vptl_presidential_history_unavailable_vice_president' '202 34' '16' '\t\t\t\t\t\t\t\t\t\t' -TooltipWidget ("vptl_presidential_history_vice_president_profile_tooltip_{0}" -f $s)
	Add-Line $g '\t\t\t\t\t\t\t\t\t} }'
	Add-Line $g '\t\t\t\t\t\t\t\t\twidget = { size = { 232 34 }'
	Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 232 34 }} raw_text = `"#BOLD [Country.MakeScope.Var('{1}_start_year').GetValue|0]–#!`" fontsize = 18 align = right|nobaseline }}" -f $open,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 232 34 }} raw_text = `"#BOLD [Country.MakeScope.Var('{1}_start_year').GetValue|0]–[Country.MakeScope.Var('{1}_end_year').GetValue|0]#!`" fontsize = 18 align = right|nobaseline }}" -f $closed,$p)
	Add-Line $g '\t\t\t\t\t\t\t\t\t}'
	Add-Line $g '\t\t\t\t\t\t\t\t}'

	# Office row keeps accession, frozen affiliations, and status in fixed columns.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = { spacing = 8'
	for ($i=0;$i -le 5;$i++) { $key=@('vptl_presidential_history_accession_unrecorded','vptl_presidential_history_accession_elected','vptl_presidential_history_accession_succeeded','vptl_presidential_history_accession_interim','vptl_presidential_history_accession_provisional','vptl_presidential_history_accession_initial')[$i]; Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[EqualTo_CFixedPoint(Country.MakeScope.Var('{0}_accession_type').GetValue, '(CFixedPoint){1}')]`" size = {{ 170 30 }} text = `"{2}`" fontsize = 15 elide = right tooltip = `"{2}`" }}" -f $p,$i,$key) }
	Add-AffiliationIdentityText $g $p 'party_type_identity' $partyTypeIdentities 'vptl_presidential_history_unavailable_party' '210 30' '15'
	Add-FrozenIgBadge $g $p
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 224 30 }} text = `"vptl_presidential_history_departure_open`" fontsize = 15 align = right|nobaseline }}" -f $open)
	for ($i=1;$i -le 7;$i++) { $key=@('','vptl_presidential_history_departure_death','vptl_presidential_history_departure_lost_election','vptl_presidential_history_departure_term_limited','vptl_presidential_history_departure_election_handoff','vptl_presidential_history_departure_removed','vptl_presidential_history_departure_system_ended','vptl_presidential_history_departure_unknown')[$i]; Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[And({0}, EqualTo_CFixedPoint(Country.MakeScope.Var('{1}_departure_reason').GetValue, '(CFixedPoint){2}'))]`" size = {{ 224 30 }} text = `"{3}`" fontsize = 15 elide = left align = right|nobaseline tooltip = `"{3}`" }}" -f $closed,$p,$i,$key) }
	Add-Line $g '\t\t\t\t\t\t\t\t}'

	# Results row: active cards bind live country values; completed cards bind frozen finals.
	Add-Line $g '\t\t\t\t\t\t\t\thbox = { spacing = 8'
	Add-NationalMetricText $g $p 'gdp' 'vptl_presidential_history_gdp_label' 'D' 'GetGDP' $true
	Add-NationalMetricText $g $p 'population' 'vptl_presidential_history_population_label' 'D' 'GetTotalPopulation' $true
	Add-NationalMetricText $g $p 'sol' 'vptl_presidential_history_sol_label' '1' 'GetAverageSoLByPopulation' $true
	Add-NationalMetricText $g $p 'prestige' 'vptl_presidential_history_prestige_label' '0' 'GetPrestige' $true
	<# old metric loop retained below only as a source comment for historical context.
		$name=$metric[0]; $label=$metric[1]; $format=$metric[2]; $width=$metric[3]
		# This mirrors the last known-good binding: active reads start, closed reads start to end.
		$currentAvailable="And($open, Country.MakeScope.Var('${p}_${name}_start').IsSet)"
		$closedAvailable=Gui-And @($closed, "Country.MakeScope.Var('${p}_${name}_start').IsSet", "Country.MakeScope.Var('${p}_${name}_end').IsSet")
		$currentMissing="And($open, Not(Country.MakeScope.Var('${p}_${name}_start').IsSet))"
		$closedMissing="And($closed, Or(Not(Country.MakeScope.Var('${p}_${name}_start').IsSet), Not(Country.MakeScope.Var('${p}_${name}_end').IsSet)))"
		Add-Line $g ("\t\t\t\t\t\t\t\t\twidget = {{ size = {{ {0} 48 }} vbox = {{" -f $width)
		Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ size = {{ {0} 18 }} text = `"{1}`" fontsize = 14 }}" -f $width,$label)
		Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ {1} 28 }} raw_text = `"#BOLD [Country.MakeScope.Var('{2}_{3}_start').GetValue|{4}]#!`" fontsize = 16 elide = right }}" -f $currentAvailable,$width,$p,$name,$format)
		Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ {1} 28 }} raw_text = `"#BOLD [Country.MakeScope.Var('{2}_{3}_start').GetValue|{4}] → [Country.MakeScope.Var('{2}_{3}_end').GetValue|{4}]#!`" fontsize = 15 elide = right }}" -f $closedAvailable,$width,$p,$name,$format)
		Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Or({0}, {1})]`" size = {{ {2} 28 }} text = `"vptl_presidential_history_metric_unavailable`" fontsize = 15 elide = right }}" -f $currentMissing,$closedMissing,$width)
		Add-Line $g '\t\t\t\t\t\t\t\t\t} }'
	}
	Add-Line $g '\t\t\t\t\t\t\t\t\twidget = { size = { 176 48 } vbox = {'
	Add-Line $g '\t\t\t\t\t\t\t\t\t\ttextbox = { size = { 176 18 } text = "vptl_presidential_history_rank_label" fontsize = 14 }'
	Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 176 28 }} raw_text = `"#v ##[Country.MakeScope.Var('{1}_score_rank_end').GetValue|0]#!`" fontsize = 16 }}" -f $rankOpenEnd,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 176 28 }} raw_text = `"#v ##[Country.MakeScope.Var('{1}_score_rank_start').GetValue|0]#!`" fontsize = 16 }}" -f $rankOpenStartOnly,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 176 28 }} raw_text = `"#v ##[Country.MakeScope.Var('{1}_score_rank_start').GetValue|0]#! → #v ##[Country.MakeScope.Var('{1}_score_rank_end').GetValue|0]#!`" fontsize = 15 }}" -f $rankClosed,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[Or({0}, {1})]`" size = {{ 176 28 }} text = `"vptl_presidential_history_rank_unavailable_value`" fontsize = 15 }}" -f $rankMissingOpen,$rankMissingClosed)
	Add-Line $g '\t\t\t\t\t\t\t\t\t} }'
	Add-Line $g '\t\t\t\t\t\t\t\t}'

	#>
	<# Rank display temporarily disabled while rank persistence is being repaired.
	Add-Line $g '\t\t\t\t\t\t\twidget = { size = { 176 48 } vbox = {'
	Add-Line $g '\t\t\t\t\t\t\t\ttextbox = { size = { 176 18 } text = "vptl_presidential_history_rank_label" fontsize = 14 }'
	Add-Line $g ("\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 176 28 }} raw_text = `"#v ##[Country.GetCountryScorePositionDesc]#!`" fontsize = 16 }}" -f $open)
	Add-Line $g ("\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 176 28 }} raw_text = `"#v ##[Country.MakeScope.Var('{1}_score_rank_end').GetValue|0]#!`" fontsize = 16 }}" -f $rankClosed,$p)
	Add-Line $g ("\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[{0}]`" size = {{ 176 28 }} text = `"vptl_presidential_history_rank_unavailable_value`" fontsize = 15 }}" -f $rankMissingClosed)
	Add-Line $g '\t\t\t\t\t\t\t} }'
	#>
	Add-Line $g '\t\t\t\t\t\t}'

	# Laws stay inside a dedicated footer so long histories cannot disturb the grid.
	Add-Line $g '\t\t\t\t\t\t\t\twidget = { size = { 928 40 } background = { using = entry_bg_fancy_dark alpha = 0.22 } hbox = { spacing = 5'
	Add-Line $g '\t\t\t\t\t\t\t\t\ttextbox = { size = { 150 40 } text = "vptl_presidential_history_laws_enacted" fontsize = 16 align = left|nobaseline }'
	for ($i=1;$i -le 8;$i++) { Add-Line $g ("\t\t\t\t\t\t\t\t\twidget = {{ visible = `"[Country.MakeScope.Var('{0}_law_{1}').GetLaw.IsValid]`" size = {{ 32 40 }} law_icon = {{ parentanchor = center size = {{ 28 28 }} datacontext = `"[Country.MakeScope.Var('{0}_law_{1}').GetLaw]`" tooltipwidget = {{ FancyTooltip_Law = {{}} }} }} }}" -f $p,$i) }
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[GreaterThan_CFixedPoint(Country.MakeScope.Var('{0}_law_overflow_count').GetValue, '(CFixedPoint)0')]`" size = {{ 60 40 }} raw_text = `"#BOLD +[Country.MakeScope.Var('{0}_law_overflow_count').GetValue|0]#!`" fontsize = 14 align = center|nobaseline }}" -f $p)
	Add-Line $g ("\t\t\t\t\t\t\t\t\ttextbox = {{ visible = `"[LessThan_CFixedPoint(Country.MakeScope.Var('{0}_law_count').GetValue, '(CFixedPoint)1')]`" size = {{ 220 40 }} text = `"vptl_presidential_history_no_laws`" fontsize = 14 align = left|nobaseline }}" -f $p)
	Add-Line $g '\t\t\t\t\t\t\t\t\twidget = { layoutpolicy_horizontal = expanding size = { 1 40 } }'
	Add-Line $g '\t\t\t\t\t\t\t\t} }'
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
