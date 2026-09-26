*! SHG Stata menu
*! version 1.0.0, 26 September 2026
*!
*! Adds the SHG workflow menu to Stata's built-in User menu.
*! Load once from the workstation profile after SHG paths are defined.

version 19.0

if "$SHG_STATA" == "" {
    display as error "SHG_STATA is not defined. Load the local SHG paths first."
    exit 198
}

capture adopath ++ "$SHG_STATA/dialogs"

window menu append submenu "stUser" "SHG"
window menu append submenu "SHG" "Diabetes Registry"

window menu append item "Diabetes Registry" ///
    "Triage transfer and reconciliation" ///
    "db shg_triage_report"

window menu refresh

display as text "SHG menu loaded: User > SHG"

