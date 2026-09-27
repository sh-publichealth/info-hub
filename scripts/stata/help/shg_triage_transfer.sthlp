{smcl}
{* *! version 2.0.0 27sep2026}{...}
{title:SHG Diabetes Registry: triage-to-registry transfer}

{pstd}
This dialog runs the operational triage-to-registry workflow for triage project
1087 and registry project 1077. It uses the configured SHG private workspace
and does not change Stata's working directory.

{title:Preview reconciliation}

{pstd}
Use this before every transfer. It identifies eligible records not yet in the
registry and creates a private run folder. It does not change REDCap data.

{title:Authorised transfer}

{pstd}
Use only after reviewing the preview. The controller verifies both project
identifiers, rechecks each destination match immediately before import,
re-reads the registry and records the verification. The dialog transfers the
complete reviewed candidate set.

{title:Private outputs}

{pstd}
Each run is stored below {cmd:$SHG_PRIVATE/work/triage-transfer/runs}. The run
folder contains the reconciliation CSV, YAML summary, transferred-patient
list, and private PDF report. These files contain confidential information and
must remain in the private workspace.

{title:Command-line use}

{pstd}
Preview can also be run from any Stata working directory:

{phang2}{cmd:do "$SHG_STATA/registry/shg_triage_report.do" preview}

{pstd}
An authorised full transfer uses:

{phang2}{cmd:do "$SHG_STATA/registry/shg_triage_report.do" transfer TRANSFER-1087-TO-1077}

{pstd}
Add a positive final argument only when a deliberately bounded first run has
been agreed.

{title:If a run does not complete}

{pstd}
Read the unsuppressed Stata output first. Then inspect the newest private run
folder and its {cmd:ERROR.txt}, if present. Do not retry a transfer until the
result and any persistent import receipt are understood.
