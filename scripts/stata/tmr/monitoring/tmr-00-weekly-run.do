** 01 - Extract TMR data from REDCap
** 02 - Prepare the data for reporting
** 03 - Overview quality report
** 04a - Individual level weight and HbA1c monitoring
** 04b - Individual level weight and HbA1c monitoring - without identifying names
do "C:\yoshimi-hot\output\analyse-sth\sh003-diabetes-registry\info-hub\scripts\stata\tmr\monitoring\tmr-01-redcap-extract.do"
do "C:\yoshimi-hot\output\analyse-sth\sh003-diabetes-registry\info-hub\scripts\stata\tmr\monitoring\tmr-02-prepare-data.do"
do "C:\yoshimi-hot\output\analyse-sth\sh003-diabetes-registry\info-hub\scripts\stata\tmr\monitoring\tmr-03-dq-report-v2.do"
do "C:\yoshimi-hot\output\analyse-sth\sh003-diabetes-registry\info-hub\scripts\stata\tmr\monitoring\tmr-04-monitor-report-v3.do"
do "C:\yoshimi-hot\output\analyse-sth\sh003-diabetes-registry\info-hub\scripts\stata\tmr\monitoring\tmr-04-monitor-report-v3-noname.do"


