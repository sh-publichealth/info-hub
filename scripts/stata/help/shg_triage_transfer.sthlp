{smcl}
{* *! version 1.0.0 27sep2026}{...}
{title:SHG Diabetes Registry: triage-to-registry transfer}

{pstd}
This dialog runs the test triage-to-registry reconciliation workflow. It uses
the configured SHG private workspace and does not change Stata's working
directory.

{title:Preview reconciliation}

{pstd}
Use this before every transfer. It reads the configured test triage and
registry projects, identifies eligible records not yet in the registry, and
creates a private run folder. It does not change REDCap data.

{title:Authorised transfer}

{pstd}
Use only after reviewing the preview. The current controller is locked to the
test projects. It checks the configured project identifiers, performs the
authorised test transfer, re-reads the registry, and records its verification.

{title:Private outputs}

{pstd}
Each run is stored below {cmd:$SHG_PRIVATE/work/triage-transfer/runs}. The run
folder contains the reconciliation CSV, a YAML summary, the transferred-patient
list, and the private PDF report. These files contain confidential information
and must remain in the private workspace.

{title:Command-line use}

{pstd}
Preview can also be run from any Stata working directory:

{phang2}{cmd:do "$SHG_STATA/registry/shg_triage_report.do" preview}

{title:If a run does not complete}

{pstd}
Read the unsuppressed Stata output first. Then inspect the newest private run
folder and its {cmd:ERROR.txt}, if present. Do not retry an authorised transfer
until the result is understood.
