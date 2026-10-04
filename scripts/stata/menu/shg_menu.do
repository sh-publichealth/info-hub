*! SHG Stata menu
*! version 1.2.0, 27 September 2026
*!
*! Adds the SHG workflow menu to Stata's built-in User menu.
*! The menu does not change the working directory.

version 19.0

if "$SHG_STATA" == "" {
    display as error "SHG_STATA is not defined. Load the local SHG paths first."
    exit 198
}

capture adopath ++ "$SHG_STATA/dialogs"
capture adopath ++ "$SHG_STATA/help"

window menu append submenu "stUser" "SHG"
window menu append submenu "SHG" "Diabetes Registry"

window menu append item "Diabetes Registry" ///
    "Triage-to-registry transfer" ///
    "db shg_triage_report"

window menu refresh

display as text "SHG menu loaded: User > SHG"
