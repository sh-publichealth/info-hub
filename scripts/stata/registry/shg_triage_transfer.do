/*
SHG diabetes triage transfer

First draft: read-only preview
Test projects: triage 1091, registry 1090

Run:
    do scripts/stata/registry/shg_triage_transfer.do
*/

version 19.0

* Workstation configuration
capture confirm file ///
    "scripts/stata/config/shg_paths_LOCAL.do"

if _rc {
    display as error "SHG local configuration not found."
    exit 601
}

do "scripts/stata/config/shg_paths_LOCAL.do"

* Check Python executable
capture confirm file "$SHG_PYTHON_EXE"

if _rc {
    display as error "SHG Python executable not found."
    exit 601
}

* Check Python transfer script
capture confirm file ///
    "$SHG_PYTHON/shg_redcap_transfer.py"

if _rc {
    display as error "Python transfer script not found."
    exit 601
}

display as text "SHG diabetes triage transfer"
display as text "Read-only preview: test projects only"

shell "$SHG_PYTHON_EXE" ///
    "$SHG_PYTHON/shg_redcap_transfer.py" ///
    --private "$SHG_PRIVATE"

display as text "Preview command finished."
display as text ///
    "Check the Python output and private reconciliation files."