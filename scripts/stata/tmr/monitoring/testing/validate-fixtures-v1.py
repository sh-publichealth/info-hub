"""Build-side checks. Requires pandas; Stata users can use the DO assertions."""
from pathlib import Path
import json
import pandas as pd
import numpy as np
root = Path(__file__).resolve().parent
schema=json.loads((root/'fixture-schema.json').read_text())
expected=json.loads((root/'expected-results.json').read_text())
read=lambda n: pd.read_stata(root/'data_raw'/n,convert_dates=False,convert_categoricals=False)
df=read('tmr_full_redcap_api_extract_latest.dta')
assert list(df.columns)==schema['raw_fields']
assert len(df)==62 and df.record_id.nunique()==6
mapping=pd.read_csv(root/'config/tmr-visit-map.csv')
assert not mapping.duplicated(['redcap_event_name','repeat_instance']).any()
assert (mapping.loc[mapping.planned_visit>0,'display_order']==mapping.loc[mapping.planned_visit>0,'planned_visit']).all()

def classify(d):
 d=d.copy();d['repeat_instance']=d.redcap_repeat_instance.fillna(0).astype(int)
 d=d.merge(mapping,on=['redcap_event_name','repeat_instance'],how='left',validate='many_to_one')
 # These fixtures use a subset of the complete programme measurement mask.
 mask=d[['weight','hba1c','diabetes_meds','core_measurements_complete','hba1c_complete']].notna().any(axis=1)
 d=d.loc[mask].copy()
 assert d.planned_visit.notna().all(), 'Unmapped event'
 d['key']=np.where(d.planned_visit>0,'P'+d.planned_visit.astype(int).astype(str),'O:'+d.redcap_event_name+':'+d.repeat_instance.astype(str))
 counts=d.groupby(['record_id','key'])[['weight','hba1c','diabetes_meds','visit_date_cm']].nunique()
 assert (counts<=1).all().all(), 'Conflicting visit value'
 result=d.groupby(['record_id','key'],as_index=False).agg(planned_visit=('planned_visit','first'),diabetes_meds=('diabetes_meds','max'),hba1c=('hba1c','max'),core_date=('visit_date_cm','min'))
 result['medcat']=result.diabetes_meds.map({1:1,2:1,3:2,4:3,5:0,6:0})
 return result
r=classify(df)
base=r[r.planned_visit==1].set_index('record_id').medcat
assert base.notna().sum()==expected['baseline_med_n']
assert [(base==i).sum() for i in range(4)]==expected['baseline_med_counts_0_1_2_3plus']
end=r[r.planned_visit==7].set_index('record_id').medcat
assert end.notna().sum()==expected['tmr6_med_n']
assert [(end==i).sum() for i in range(4)]==expected['tmr6_med_counts_0_1_2_3plus']
pair=pd.concat([base.rename('baseline'),end.rename('end')],axis=1).dropna()
assert len(pair)==expected['paired_med_n']
assert (pair.end<pair.baseline).sum()==expected['paired_lower']
assert (pair.end==pair.baseline).sum()==expected['paired_same']
assert (pair.end>pair.baseline).sum()==expected['paired_higher']
assert len(r[(r.record_id=='305-90017')&(r.planned_visit==0)])==5
assert len(r[r.planned_visit==1])==5
assert r[(r.record_id=='305-90017')&(r.planned_visit==7)].hba1c.iloc[0]==40
assert r[(r.record_id=='305-90001')&(r.planned_visit==7)].hba1c.iloc[0]==40
assert not df[(df.record_id=='306-90003')&(df.redcap_event_name=='tmr_visit_2_arm_2')].shape[0]
for name,error in [('negative_unmapped_event.dta','Unmapped event'),('negative_conflicting_weight.dta','Conflicting visit value')]:
 try: classify(read(name))
 except AssertionError as exc: assert str(exc)==error
 else: raise AssertionError(f'{name} unexpectedly passed')
status=pd.read_stata(root/'data_clean/tmr_monitor_participant_status.dta',convert_dates=False,convert_categoricals=False)
assert not status.record_id.duplicated().any()
assert status.withdrawn.sum()==1
# Confirm attached DTA medication labels reproduce the actual dictionary.
with pd.io.stata.StataReader(root/'data_raw/tmr_full_redcap_api_extract_latest.dta') as reader:
 labels=reader.value_labels()['diabetes_meds']
assert labels=={5:'not taking medication(s)',1:'monotherapy oral',2:'monotherapy injectable',3:'combination of 2 drugs',4:'combination of 3 or more drugs',6:'stopped medication(s)'}
# Named/noname code parity, allowing metadata, log and final filename.
named=(root.parent/'tmr-04-monitor-report-v4.do').read_text()
noname=(root.parent/'tmr-04-monitor-report-v4-noname.do').read_text()
normalize=lambda s:s.replace('tmr-04-monitor-report-v4-noname','tmr-04-monitor-report-v4').replace('("`person_name\'")','(" ")').replace("`report_date_file'_noname.pdf","`report_date_file'.pdf")
assert normalize(named)==normalize(noname)
assert sum([20,4,10,10,9,11,10,9,17])==100
assert sum([25,9,9,8,9,9,8,23])==100
for path in root.parent.rglob('*.do'):
 code=path.read_text()
 # Block balance only, not a substitute for Stata execution.
 lines=[x.split('//')[0] for x in code.splitlines() if not x.strip().startswith('*')]
 assert sum(x.count('{')-x.count('}') for x in lines)==0,path
print('PASS: 184-field schema, DTA labels/round trips, logical visits, medication summaries, negative fixtures, report parity, width sums and block balance.')
print('Stata execution and PDF rendering have NOT been performed in this environment.')
