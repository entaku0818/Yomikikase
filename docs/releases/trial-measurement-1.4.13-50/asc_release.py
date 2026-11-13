import sys,json,requests,subprocess
from functools import lru_cache
@lru_cache(maxsize=1)
def get_headers():
 ruby = "Dotenv.load('/Users/entaku/repository/VoiceYourText/.env'); print Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'), issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'), key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT')).text"
 token=subprocess.check_output(['/Users/entaku/.rbenv/shims/ruby','-rspaceship','-rdotenv','-e',ruby],text=True).strip()
 return {'Authorization':'Bearer '+token,'Content-Type':'application/json'}
BASE='https://api.appstoreconnect.apple.com/v1/'
VID='d9918a1f-3a8d-4f67-85c5-b361623d8cce'
def call(method,path,body=None,params=None):
 r=requests.request(method,BASE+path,headers=get_headers(),json=body,params=params,timeout=60)
 if not r.ok: raise RuntimeError(str(r.status_code)+' '+r.text[:2500])
 return r.json() if r.content else {}
def patch(typ,id,attrs): return call('PATCH',f'{typ}/{id}',{'data':{'type':typ,'id':id,'attributes':attrs}})
action=sys.argv[1]
v=call('GET','appStoreVersions/'+VID)['data']
builds=call('GET','builds',params={'filter[app]':'6478449537','filter[version]':'50','include':'preReleaseVersion'})
valid=[b for b in builds['data'] if b['attributes']['processingState']=='VALID' and any(p['id']==b['relationships']['preReleaseVersion']['data']['id'] and p['attributes']['version']=='1.4.13' for p in builds.get('included',[]))]
subs=call('GET','apps/6478449537/reviewSubmissions',params={'limit':100})['data']
print(json.dumps({'version':v['attributes']['versionString'],'state':v['attributes']['appStoreState'],'releaseType':v['attributes']['releaseType'],'build50':[{'id':b['id'],'state':b['attributes']['processingState']} for b in builds['data']],'submissions':[{'id':s['id'],'state':s['attributes']['state']} for s in subs if s['attributes']['state']!='COMPLETE']}),flush=True)
if action=='status': sys.exit()
assert len(valid)==1, 'Build 50 must be VALID'
assert v['attributes']['versionString']=='1.4.13'
if action=='cancel':
 assert v['attributes']['appStoreState']=='WAITING_FOR_REVIEW'
 pending=[s for s in subs if s['attributes']['state']=='WAITING_FOR_REVIEW']
 assert len(pending)==1
 items=call('GET',f"reviewSubmissions/{pending[0]['id']}/items",params={'include':'appStoreVersion'})['data']
 assert items and all(i['relationships'].get('appStoreVersion',{}).get('data',{}).get('id')==VID for i in items)
 print(json.dumps(patch('reviewSubmissions',pending[0]['id'],{'canceled':True})['data']['attributes']))
elif action=='submit':
 assert v['attributes']['appStoreState'] in ['DEVELOPER_REJECTED','PREPARE_FOR_SUBMISSION']
 call('PATCH',f'appStoreVersions/{VID}/relationships/build',{'data':{'type':'builds','id':valid[0]['id']}})
 patch('appStoreVersions',VID,{'releaseType':'AFTER_APPROVAL'})
 ready=[s for s in subs if s['attributes']['state']=='READY_FOR_REVIEW']
 assert len(ready)<=1
 sub=ready[0] if ready else call('POST','reviewSubmissions',{'data':{'type':'reviewSubmissions','attributes':{'platform':'IOS'},'relationships':{'app':{'data':{'type':'apps','id':'6478449537'}}}}})['data']
 items=call('GET',f"reviewSubmissions/{sub['id']}/items",params={'include':'appStoreVersion'})['data']
 assert all(i['relationships'].get('appStoreVersion',{}).get('data',{}).get('id')==VID for i in items)
 if not items: call('POST','reviewSubmissionItems',{'data':{'type':'reviewSubmissionItems','relationships':{'reviewSubmission':{'data':{'type':'reviewSubmissions','id':sub['id']}},'appStoreVersion':{'data':{'type':'appStoreVersions','id':VID}}}}})
 result=patch('reviewSubmissions',sub['id'],{'submitted':True})
 print(json.dumps({'version_id':VID,'build_id':valid[0]['id'],'submission_id':sub['id'],'state':result['data']['attributes']['state']}))
