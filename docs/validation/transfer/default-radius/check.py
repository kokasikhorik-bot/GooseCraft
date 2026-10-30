import sys,json,hashlib
from pathlib import Path
sys.path.insert(0,'tools');import project as p
from profile_readback import validate_profile
out=Path('/results/default-radius');out.mkdir(parents=True,exist_ok=False)
cases=p.BUILD/'default-radius';cases.mkdir(exist_ok=False)
origin=cases/'origin.gcw'
p.run([p.CLIENT,'--headless','--generate-world','12345',origin,'--radius','4'])
results={};frames=1100
for label in ('deferred','control'):
    world=cases/label;p.run([p.CLIENT,'--headless','--import-world',origin,world])
    profile=out/(label+'.json');png=out/(label+'.png')
    flags=['--deferred-respawn'] if label=='deferred' else ['--sync-paging']
    data=json.loads(p.run([p.VIEWER,'--offscreen','--paging-replay','--mesh-radius','2','--paged-world',world,*flags,'--frames',frames,'--screenshot',png,'--profile',profile,'--profile-warmup','0'],extra_env={'SDL_VIDEODRIVER':'offscreen','VK_ICD_FILENAMES':'/usr/share/vulkan/icd.d/lvp_icd.x86_64.json'}).stdout)
    validate_profile(profile,frames)
    export=cases/(label+'.gcw');p.run([p.CLIENT,'--headless','--export-pages',world,export])
    results[label]=data
    data['png_sha256']=hashlib.sha256(png.read_bytes()).hexdigest();data['export_sha256']=hashlib.sha256(export.read_bytes()).hexdigest()
    if label=='deferred':frames-=data['loading_frames']
a,b=results['deferred'],results['control']
for key in ('ticks','breaks','places','solid_blocks','player_x','player_y','player_z','max_x','chunk_rebuilds','png_sha256','export_sha256'):
    assert a[key]==b[key],key
assert a['cpu_peak_chunks']==49 and a['transfer_incoming']==a['transfer_admitted']==27 and a['transfer_max_admitted']<=2
assert a['main_page_reads']==0 and a['prefetch_submitted']==a['prefetch_completed']
(out/'results.json').write_text(json.dumps({'scope':'Additional local default mesh-radius=2 check; outside 139 CI scenarios','results':results,'png_gameplay_export_equal':True},indent=2)+'\n')
print('PASS: default radius 2, 49 CPU slots, 27 incoming, exact PNG/ticks/export, main page reads 0')
