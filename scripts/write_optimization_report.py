import json,statistics,math,hashlib,zipfile,re,subprocess
from pathlib import Path
from datetime import datetime,timezone,timedelta
root=Path.cwd()
data=json.loads((root/'reports/TruocKhiToiUu/Baseline_App_2026-11-04_114840.json').read_text(encoding='utf-8-sig'))
data['captured_at']=datetime.now(timezone(timedelta(hours=7))).isoformat(timespec='seconds')
def read_json(path):return json.loads((root/path).read_text(encoding='utf-8-sig'))
def read_log(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
def digest(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()
def percentile(values,q):return sorted(values)[max(0,math.ceil(len(values)*q)-1)]
def summarize(rounds):
    samples=[v for r in rounds for v in r['samples']]
    return {'n':len(samples),'median_ms':statistics.median(samples),'p95_ms':percentile(samples,.95),
            'rss_mean_mib':statistics.mean(r['rss_bytes'] for r in rounds)/1048576,
            'rounds':[{'round':i+1,'median_ms':statistics.median(r['samples']),
                       'p95_ms':percentile(r['samples'],.95),'rss_mib':r['rss_bytes']/1048576}
                      for i,r in enumerate(rounds)]}
before=read_json('reports/SauKhiToiUu/before/detector-benchmark.json')
# Both post-change runs used the same detector code. ZIP inspection established
# that the model was STORED in both APKs; their old experimental filenames do
# not imply an actual compression difference.
after_paths=['reports/SauKhiToiUu/after/detector-benchmark-compressed-model.json',
             'reports/SauKhiToiUu/after/detector-benchmark-uncompressed-model.json']
after_runs=[read_json(p) for p in after_paths]
for run in after_runs:
    if run['mode']!=before['mode'] or run['fixture']!=before['fixture']:raise RuntimeError('Incomparable benchmark modes or fixtures')
    if run['signatures']!=before['signatures']:raise RuntimeError('Detector fixture output changed')
E={'benchmark_before':before,'benchmark_after_runs':after_runs,
   'benchmark_after_paths':after_paths,'before':summarize(before['rounds']),
   'after':summarize([r for run in after_runs for r in run['rounds']]),
   'same_signatures':True,'effective_model_zip_method':'STORED in every inspected artifact',
   'limitations':'Emulator x86_64, debug; synthetic detector fixture; host load and cache not controlled. No physical-device battery, camera end-to-end or TTS start latency measurements.'}
E['median_reduction_pct']=(E['before']['median_ms']-E['after']['median_ms'])/E['before']['median_ms']*100
E['p95_reduction_pct']=(E['before']['p95_ms']-E['after']['p95_ms'])/E['before']['p95_ms']*100
E['rss_change_pct']=(E['after']['rss_mean_mib']-E['before']['rss_mean_mib'])/E['before']['rss_mean_mib']*100
def apk(path):
    p=root/path
    with zipfile.ZipFile(p) as z:
        model=next(i for i in z.infolist() if i.filename.endswith('best_float32.tflite'))
        return {'path':path,'bytes':p.stat().st_size,'MiB':p.stat().st_size/1048576,
                'sha256':digest(p),'abis':sorted({i.filename.split('/')[1] for i in z.infolist() if i.filename.startswith('lib/')}),
                'model_bytes':model.file_size,'model_compressed_bytes':model.compress_size,
                'model_zip_method':model.compress_type,'model_sha256':hashlib.sha256(z.read(model.filename)).hexdigest()}
E['apk_before']=apk('reports/SauKhiToiUu/before/app-before-arm64-release.apk')
E['apk_after']=apk('reports/SauKhiToiUu/after/app-after-arm64-release.apk')
E['model_sha256']=digest(root/'assets/models/best_float32.tflite')
if E['apk_before']['model_sha256']!=E['model_sha256'] or E['apk_after']['model_sha256']!=E['model_sha256']:
    raise RuntimeError('Model identity changed')
E['apk_reduction_pct']=(E['apk_before']['bytes']-E['apk_after']['bytes'])/E['apk_before']['bytes']*100
E['idle']=read_json('reports/SauKhiToiUu/after/idle-memory.json')
if not (E['idle']['samples'][0]['camera_active'] and not E['idle']['samples'][1]['camera_active'] and E['idle']['samples'][-1]['camera_active']):raise RuntimeError('Camera resume check has not passed')
for sample in E['idle']['samples']:
    row=next((line for line in sample['meminfo'].splitlines() if line.strip().startswith('Native Heap')),None)
    if row:
        fields=row.split()[2:]
        if len(fields)>=8:sample['native_heap_alloc_kib']=int(fields[6])
tests=read_log(root/'reports/SauKhiToiUu/after/tests.log')
passed=re.search(r'\+(\d+): All tests passed!',tests)
if not passed:raise RuntimeError('Final tests have not passed')
E['tests_passed']=int(passed.group(1))
E['baseline_tests']={'passed':52,'failed':5,'note':'Five existing stale test cases/fixtures were corrected; these are not performance gains.'}
analysis=read_log(root/'reports/SauKhiToiUu/after/analyze.log')
E['analysis']={'errors':len(re.findall(r'(?m)^\s*error - ',analysis)),'warnings':len(re.findall(r'(?m)^\s*warning - ',analysis)),'info':len(re.findall(r'(?m)^\s*info - ',analysis))}
if E['analysis']['errors']:raise RuntimeError('Static analysis has errors')
E['source_after_sha256']={}
for directory in ['lib','test','scripts','android']:
    for p in (root/directory).rglob('*'):
        if not p.is_file() or any(x in {'.gradle','.kotlin','.cxx','build','__pycache__'} for x in p.parts):continue
        if p.suffix in {'.dart','.kt','.kts','.gradle','.ps1','.py','.properties'} and p.name not in {'local.properties','key.properties'}:
            E['source_after_sha256'][p.relative_to(root).as_posix()]=digest(p)
E['git_status']=subprocess.run(['git','status','--short'],cwd=root,capture_output=True,text=True,encoding='utf-8').stdout.strip()
E['web_build_passed']=(root/'reports/SauKhiToiUu/after/web-build.log').exists() and 'Built build' in read_log(root/'reports/SauKhiToiUu/after/web-build.log')
data['optimization']=E

import json, zipfile, hashlib, math
from pathlib import Path
from datetime import datetime, timezone
from xml.etree import ElementTree as ET

W='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
ET.register_namespace('w',W); ET.register_namespace('r',R)
def w(n): return '{'+W+'}'+n
def el(p,n,**attrs): return ET.SubElement(p,w(n),{w(k):str(v) for k,v in attrs.items()})
def xml(e): return ET.tostring(e,encoding='utf-8',xml_declaration=True)
stamp=data['captured_at']
stamp_id=stamp[:10]+'_'+stamp[11:19].replace(':','')
out=Path.cwd()/'reports'/'SauKhiToiUu'
docx_path=out/('Evaluation_App_'+stamp_id+'.docx')
json_path=out/('Evaluation_App_'+stamp_id+'.json')
if docx_path.exists() or json_path.exists(): raise RuntimeError('Baseline files already exist; refusing to overwrite.')
out.mkdir(parents=True,exist_ok=True)
model,debug,old_release=data['artifacts']
pss=data.get('device',{}).get('total_pss_kb')
rss=data.get('device',{}).get('total_rss_kb')
pss_text=f'{pss/1024:.2f} MiB ({pss:,} KiB)' if pss else 'Chưa đo'
rss_text=f'{rss/1024:.2f} MiB ({rss:,} KiB)' if rss else 'Chưa đo'
capture=datetime.fromisoformat(stamp).strftime('%d/%m/%Y %H:%M:%S')+' (UTC+07:00)'
document=ET.Element(w('document')); body=el(document,'body')
def para(text='',style=None,parent=body,bold=False,size=None,color=None,after=None):
    p=el(parent,'p'); pp=el(p,'pPr')
    if style: el(pp,'pStyle',val=style)
    if after is not None:el(pp,'spacing',after=after)
    r=el(p,'r'); rp=el(r,'rPr')
    if bold:el(rp,'b')
    if size:el(rp,'sz',val=size)
    if color:el(rp,'color',val=color)
    for i,line in enumerate(str(text).split('\n')):
        if i:el(r,'br')
        t=el(r,'t');t.set('{http://www.w3.org/XML/1998/namespace}space','preserve');t.text=line
    return p
def title(kicker,text,sub):
    para(kicker,'Kicker');para(text,'Title');para(sub,'Subtitle')
def h(text):para(text,'Heading2')
def note(text):para(text,'Note')
def bullet(text):para('• '+text,'ListText')
def table(headers,rows,widths=None,font=18):
    if widths is None:widths=[3000,6840] if len(headers)==2 else [9840//len(headers)]*len(headers)
    t=el(body,'tbl');pr=el(t,'tblPr')
    el(pr,'tblW',w=9840,type='dxa');el(pr,'tblLayout',type='fixed')
    borders=el(pr,'tblBorders')
    for edge in ['top','left','bottom','right','insideH','insideV']:el(borders,edge,val='single',sz=4,color='D9E2EC')
    margins=el(pr,'tblCellMar')
    for edge in ['top','bottom']:el(margins,edge,w=70,type='dxa')
    for edge in ['left','right']:el(margins,edge,w=100,type='dxa')
    grid=el(t,'tblGrid')
    for width in widths:el(grid,'gridCol',w=width)
    for idx,values in enumerate([headers]+list(rows)):
        tr=el(t,'tr');trpr=el(tr,'trPr');el(trpr,'cantSplit')
        if idx==0:el(trpr,'tblHeader')
        for j,value in enumerate(values):
            tc=el(tr,'tc');cp=el(tc,'tcPr');el(cp,'tcW',w=widths[j],type='dxa');el(cp,'vAlign',val='center')
            el(cp,'shd',fill='17324D' if idx==0 else ('F1F5F9' if idx%2==0 else 'FFFFFF'),val='clear')
            para(value,'TableText',parent=tc,bold=(idx==0),color=('FFFFFF' if idx==0 else '243B53'),size=font,after=0)
    para('',after=30,size=4)
def page():
    p=el(body,'p');r=el(p,'r');el(r,'br',type='page')
def hashes(pairs):
    return [(label,digest[:32]+'\n'+digest[32:]) for label,digest in pairs]


E=data['optimization']; B=E['before']; A=E['after']
f=lambda v:f'{v:.2f}'
title('KẾT QUẢ TRIỂN KHAI','Trước / sau tối ưu','Camera • APK • RAM • Pin • TTS')
para('Thời điểm tổng hợp: '+capture,'Meta')
note('So sánh source đã lưu trước tối ưu với pipeline hiện tại. Model AI, ngưỡng 0,78 và quy tắc xác nhận 3 frame được giữ nguyên. Số đo detector dùng máy ảo debug, không đại diện cho điện thoại release.')
h('1. Kết quả định lượng')
table(['Chỉ số','Trước','Sau','Diễn giải'],[
('Detector: trung vị (ms)',f(B['median_ms']),f(A['median_ms']),f"Giảm {E['median_reduction_pct']:.1f}% trong bài ảnh cố định."),
('Detector: P95 (ms)',f(B['p95_ms']),f(A['p95_ms']),f"Giảm {E['p95_reduction_pct']:.1f}%; có biến động JIT/tải máy chủ."),
('RSS trung bình các mốc vòng đo (MiB)',f(B['rss_mean_mib']),f(A['rss_mean_mib']),f"Tăng {E['rss_change_pct']:.1f}%; chưa đạt mục tiêu giảm RAM khi suy luận liên tục."),
('APK release mục tiêu ARM64 (MiB)',f(E['apk_before']['MiB']),f(E['apk_after']['MiB']),f"Giảm {E['apk_reduction_pct']:.1f}%; sau dùng APK riêng ABI."),
('Đầu ra ảnh thử','60 frame','120 frame','Cả hai lượt sau đều khớp toàn bộ 60 chữ ký đầu ra của lượt trước.'),
('Kiểm thử','52 đạt / 5 lỗi cũ',str(E['tests_passed'])+' đạt','Có cập nhật test cũ và thêm test mới; không coi đây là chỉ số tăng tốc.')
],widths=[3000,1500,1500,3840],font=18)
h('2. Các điều kiện cần đọc kèm')
bullet('Trước: 3 vòng × 20 frame; sau: 2 lần chạy, tổng 6 vòng × 20 frame. Mỗi lần chạy có 5 frame làm nóng.')
bullet('Cùng ảnh YUV420 640 × 480, bốn góc xoay; cùng model float32 [1,3,416,416] → [1,22,3549], CPU 4 luồng.')
bullet('Máy ảo Flutter_API_36, Android 16/API 36, x86_64; Flutter 3.47.7, Dart 3.13.5. Mọi lượt detector đều là debug.')
note('Đánh đổi: worker giữ lâu giúp giảm công việc lặp lại, nhưng RSS đang chạy vẫn cao hơn mốc. Nạp model/worker cũng có chi phí khởi tạo; cơ chế giải phóng khi nghỉ dài phải được cân nhắc cùng thời gian mở lại.')
para('Mốc Git: '+data['commit']+'. Source sau là working tree chưa commit; dấu kiểm tra file và dữ liệu thô được lưu trong JSON đi kèm.','Note')

page()
title('DETECTOR & CAMERA','Chi tiết các lượt đo','Trung vị tính lại từ mẫu thô; P95 dùng thứ hạng gần nhất')
round_rows=[]
for label,stats in [('Trước',B),('Sau',A)]:
    for r in stats['rounds']:
        round_rows.append((label+' '+str(r['round']),'20',f(r['median_ms']),f(r['p95_ms']),f(r['rss_mib'])))
table(['Bản / vòng','Frame','Trung vị (ms)','P95 (ms)','RSS (MiB)'],round_rows,
      widths=[2100,800,2200,2200,2540],font=18)
note('RSS là ảnh chụp cuối mỗi vòng, không phải RAM sống của riêng model hoặc đỉnh RAM. Gộp cả hai lượt sau thay vì chỉ chọn lượt tốt hơn. Máy chủ/GC/JIT/cache không được kiểm soát như phòng đo.')
h('3. Chi phí nạp model đã quan sát')
table(['Bản','Thời gian khởi tạo detector'],[
('Trước, một lần',f(before['initialize_ms'])+' ms'),
('Sau, lần 1',f(after_runs[0]['initialize_ms'])+' ms'),
('Sau, lần 2',f(after_runs[1]['initialize_ms'])+' ms'),
])
note('Đây là các quan sát đơn lẻ, không phải benchmark cold start. Chưa thể kết luận độ trễ mở app trên điện thoại thật; số liệu hiện tại cho thấy cần theo dõi chi phí khởi tạo tăng.')
h('4. Những thay đổi đã áp dụng')
bullet('Một worker isolate cho cả phiên; mỗi lần chỉ có một frame đang xử lý. Truyền snapshot bằng TransferableTypedData.')
bullet('Tái sử dụng Float32List 416 × 416 × 3; ghi vào tensor đã cấp phát; giải mã output trực tiếp từ view trước lượt invoke tiếp theo.')
bullet('Model được nạp từ file có quản lý vòng đời. Worker thoát trước khi interpreter được đóng; đường dẫn tạm trên Android được gỡ sau khi model đã được ánh xạ.')
bullet('Chu kỳ nhận xử lý: 120 ms khi quét bình thường; 300 ms sau 3 frame không có tiền; 240 ms khi đã đọc kết quả hoặc liên tiếp cần chỉnh camera.')
note('Chế độ 240 ms khi khóa kết quả có thể làm chậm việc xác nhận tiền đã rời khung so với 120 ms. Cần đánh giá thao tác chuyển sang tờ tiếp theo với người dùng thật.')

page()
title('VÒNG ĐỜI & PHẢN HỒI','RAM, pin và giọng nói','Tách số đo trong cùng bản app khỏi so sánh trước/sau phiên bản')
h('5. Phép thử xuống nền rồi quay lại')
idle_rows=[]
for s in E['idle']['samples']:
    native=s.get('native_heap_alloc_kib')
    idle_rows.append((s['phase'],f(s['total_pss_kib']/1024) if s['total_pss_kib'] else '—',
        f(native/1024) if native is not None else '—','Có' if s['camera_active'] else 'Không'))
table(['Trạng thái','PSS (MiB)','Native heap alloc (MiB)','Camera hoạt động'],idle_rows,
      widths=[3600,1800,2400,2040],font=18)
note('Đây là phép thử vòng đời trong bản đã tối ưu, không phải A/B RAM trên điện thoại. Camera đã dừng khi xuống nền và được kiểm tra hoạt động lại. Model/worker được lên lịch giải phóng sau 15 giây nghỉ; quay lại sớm hủy lịch này.')
h('6. TTS — kiểm thử hành vi')
table(['Kịch bản','Trước / sau và bằng chứng'],[
('3 câu khác nhau, cùng tốc độ, đọc tuần tự','Theo code cũ: setSpeechRate 3 lần và stop 3 lần. Test sau: setSpeechRate 1 lần và không stop thừa giữa 3 câu.'),
('Mệnh giá đang được đọc','TTS ưu tiên kết quả hơn hướng dẫn camera/flash; test xác nhận các câu ưu tiên thấp không cắt ngang.'),
('Câu trùng đang phát','Gộp vào cùng Future đang đọc, tránh yêu cầu native lặp lại.'),
('Hủy / lỗi / thử lại','Test kiểm tra hủy khi đang cấu hình, kết quả ngắt hướng dẫn và đọc tiếp được sau lỗi engine giả lập.'),
('Độ trễ âm thanh thực','Chưa đo. Các test native channel giả lập không đo thời gian bắt đầu phát ra loa.')
])
h('7. Pin và khả năng phần cứng')
para('Khi không có tiền ổn định, giới hạn cấu hình giảm từ khoảng 8,33 xuống 3,33 lượt xử lý/giây. Đây là giảm tần suất suy luận tối đa, không phải kết luận giảm 60% pin. Điện năng/mAh trong 20 phút: Chưa đo.')
para('Android Camera2 kiểm tra FLASH_INFO_AVAILABLE cho camera đã chọn. Webcam không có flash tiếp tục nhận diện, không đăng ký lux cho auto-flash và không chuyển thành lỗi camera chỉ vì “No flash unit”. Lỗi camera thực như mất kết nối vẫn được báo.')

page()
title('ĐÓNG GÓI & TÍNH TOÀN VẸN','APK release và model','Giữ rõ tác dụng của tách ABI và danh tính model')
table(['Artifact','Trước','Sau'],[
('Kích thước byte',f"{E['apk_before']['bytes']:,}",f"{E['apk_after']['bytes']:,}"),
('Dung lượng MiB',f(E['apk_before']['MiB']),f(E['apk_after']['MiB'])),
('ABI có thư viện trong APK',', '.join(E['apk_before']['abis']),', '.join(E['apk_after']['abis'])),
('Model trong APK',f"{E['apk_before']['model_bytes']:,} byte",f"{E['apk_after']['model_bytes']:,} byte"),
('Phương thức ZIP của model','STORED / không nén','STORED / không nén'),
],widths=[3000,3420,3420],font=18)
note('Mốc trước là APK release build mới với target ARM64 trước khi sửa source, nhưng còn thư viện từ các ABI khác. Bản sau dùng --split-per-abi và chỉ có ARM64. Mức giảm chủ yếu là thay đổi đóng gói ABI; không được trình bày như giảm cùng tỷ lệ của model hoặc bộ nhớ.')
para('Không dùng APK release cũ ngày 16/10 hoặc APK debug 102,24 MB để tính mức cải thiện. R8 và thu gọn tài nguyên được cấu hình rõ ràng; không quy riêng phần giảm cho R8 khi chưa tách thử nghiệm.','Note')
h('8. SHA-256 kiểm chứng')
table(['Đối tượng','SHA-256 (đủ 64 ký tự, chia hai dòng)'],hashes([
('Model nguồn và model nhúng ở cả hai APK',E['model_sha256']),
('APK trước',E['apk_before']['sha256']),
('APK sau',E['apk_after']['sha256']),
]),widths=[4100,5740],font=16)
h('9. File có thể dùng')
para('APK ARM64 sau tối ưu: '+E['apk_after']['path'],'Reference')
para('Bản source trước: reports/SauKhiToiUu/before/source-before.zip','Reference')
para('Mốc Word gốc: reports/TruocKhiToiUu/Baseline_App_2026-11-04_114840.docx','Reference')
note('Script build_release.ps1 mặc định xuất APK riêng cho arm64-v8a, armeabi-v7a và x86_64. Thêm -UniversalApk nếu cần bản chung. Model và ngưỡng nhận diện không thay đổi.')

page()
title('XÁC NHẬN & BƯỚC ĐO THẬT','Phạm vi đã kiểm chứng','Các ô thiếu số đo vẫn được giữ nguyên trạng thái chưa đo')
h('10. Kiểm tra hoàn tất')
table(['Kiểm tra','Kết quả'],[
('Flutter unit / widget tests',str(E['tests_passed'])+' test đạt. Mốc cũ có 5 test stale/fixture sai, đã cập nhật đúng luồng hiện tại; 24 ca mới được bổ sung.'),
('Phân tích tĩnh',f"{E['analysis']['errors']} lỗi; {E['analysis']['warnings']} cảnh báo; {E['analysis']['info']} thông tin deprecated của API Share cũ."),
('Build Android release ARM64','Đạt; artifact được kiểm tra ABI, kích thước và hash model.'),
('Chạy app chính / vòng đời camera','Đạt trên máy ảo; xem main-smoke.log và idle-memory.json.'),
('Build web','Đạt' if E['web_build_passed'] else 'Chưa có kết quả build web trong snapshot này.'),
])
h('11. Những chỉ số chưa có cơ sở kết luận')
table(['Chỉ số','Trạng thái / cách đo tiếp'],[
('RAM điện thoại thật: TB / đỉnh','Chưa đo; cùng thiết bị và kịch bản, lấy PSS nhiều thời điểm. Tách lúc quét, lúc nền và sau quay lại.'),
('Pin trong 20 phút','Chưa đo; cùng độ sáng, trạng thái sạc, flash, ánh sáng và số lần đọc; số liệu Batterystats cần ghi là ước tính.'),
('Đưa tiền vào → bắt đầu đọc','Chưa đo; dùng cùng bộ tiền, vị trí và lịch đưa/rút tiền, tính cả thời gian xác nhận 3 frame.'),
('TTS request → callback start / âm thanh','Chưa đo; cùng engine/giọng/tốc độ. Callback start và âm thanh thật ở loa là hai mốc khác nhau.'),
('Độ chính xác trên tiền thật','Chưa đo; kiểm tra riêng từng mệnh giá, ánh sáng và góc cầm. Chữ ký fixture khớp không chứng minh độ chính xác ngoài thực tế.'),
],font=18)
h('12. Chạy lại và nguồn phương pháp')
para('powershell -NoProfile -ExecutionPolicy Bypass -File scripts/benchmark_app.ps1 -Label after','Reference')
para('powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_idle_memory.ps1','Reference')
para('Sau bài đo detector, chạy flutter run để mở lại app chính. JSON kèm Word lưu mẫu thô, nguồn dữ liệu, hash source và giới hạn phép đo.','Note')
for line in [
'Flutter profile: https://docs.flutter.dev/perf/ui-performance',
'Android RAM / pin: https://developer.android.com/tools/dumpsys',
'Camera capabilities: https://developer.android.com/reference/android/hardware/camera2/CameraCharacteristics',
]:para(line,'Reference')
sec=el(body,'sectPr')
ref=el(sec,'headerReference',type='default');ref.set('{'+R+'}id','rIdHeader')
ref=el(sec,'footerReference',type='default');ref.set('{'+R+'}id','rIdFooter')
el(sec,'pgSz',w=11906,h=16838)
el(sec,'pgMar',top=960,right=1033,bottom=900,left=1033,header=400,footer=400,gutter=0)

styles=ET.Element(w('styles'))
defaults=el(styles,'docDefaults');rd=el(defaults,'rPrDefault');rp=el(rd,'rPr')
el(rp,'rFonts',ascii='Arial',hAnsi='Arial',eastAsia='Arial',cs='Arial');el(rp,'sz',val=20);el(rp,'lang',val='vi-VN')
pd=el(defaults,'pPrDefault');pp=el(pd,'pPr');el(pp,'spacing',after=90,line=250,lineRule='auto')
def style(sid,size=20,color='243B53',bold=False,before=0,after=90,keep=False):
    s=el(styles,'style',type='paragraph',styleId=sid)
    el(s,'name',val=sid)
    if sid!='Normal':el(s,'basedOn',val='Normal')
    p=el(s,'pPr');el(p,'spacing',before=before,after=after,line=240,lineRule='auto')
    if keep:el(p,'keepNext')
    r=el(s,'rPr');el(r,'sz',val=size);el(r,'color',val=color)
    if bold:el(r,'b')
    return s
style('Normal');style('Title',38,'17324D',True,after=90,keep=True)
style('Subtitle',22,'52677B',after=140,keep=True)
style('Kicker',17,'007F86',True,after=80,keep=True)
style('Heading2',23,'007F86',True,before=100,after=90,keep=True)
style('Meta',18,'52677B',after=130)
style('Note',18,'52677B',after=90)
style('ListText',20,after=90)
style('TableText',18,after=0)
style('Reference',16,'52677B',after=55)
header=ET.Element(w('hdr'));para('NHẬN DIỆN TIỀN VIỆT NAM  |  ĐÁNH GIÁ TỐI ƯU 04/11/2026','Reference',parent=header,bold=True,color='17324D')
footer=ET.Element(w('ftr'))
p=para('Đánh giá trước / sau tối ưu  •  Trang ','Reference',parent=footer)
field=el(p,'fldSimple',instr='PAGE');r=el(field,'r');el(r,'t').text='1'
settings=ET.Element(w('settings'));el(settings,'updateFields',val='true')
compat=el(settings,'compat');el(compat,'compatSetting',name='compatibilityMode',uri='http://schemas.microsoft.com/office/word',val='15')
rels_ns='http://schemas.openxmlformats.org/package/2006/relationships'
def rels(items):
    e=ET.Element('Relationships',xmlns=rels_ns)
    for rid,typ,target in items:ET.SubElement(e,'Relationship',Id=rid,Type=typ,Target=target)
    return xml(e)
ct=ET.Element('Types',xmlns='http://schemas.openxmlformats.org/package/2006/content-types')
ET.SubElement(ct,'Default',Extension='rels',ContentType='application/vnd.openxmlformats-package.relationships+xml')
ET.SubElement(ct,'Default',Extension='xml',ContentType='application/xml')
for part,typ in {
'/word/document.xml':'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
'/word/styles.xml':'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml',
'/word/settings.xml':'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml',
'/word/header1.xml':'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml',
'/word/footer1.xml':'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml',
'/docProps/core.xml':'application/vnd.openxmlformats-package.core-properties+xml',
'/docProps/app.xml':'application/vnd.openxmlformats-officedocument.extended-properties+xml'
}.items():ET.SubElement(ct,'Override',PartName=part,ContentType=typ)
core=ET.Element('cp:coreProperties',{'xmlns:cp':'http://schemas.openxmlformats.org/package/2006/metadata/core-properties','xmlns:dc':'http://purl.org/dc/elements/1.1/','xmlns:dcterms':'http://purl.org/dc/terms/','xmlns:xsi':'http://www.w3.org/2001/XMLSchema-instance'})
ET.SubElement(core,'dc:title').text='Đánh giá tối ưu - Ứng dụng nhận diện tiền Việt Nam'
ET.SubElement(core,'dc:creator').text='Project baseline'
ET.SubElement(core,'dc:description').text='Kết quả đo detector, APK, vòng đời RAM và kiểm thử; các chỉ số điện thoại thật được đánh dấu chưa đo.'
ET.SubElement(core,'dcterms:created',{'xsi:type':'dcterms:W3CDTF'}).text=datetime.fromisoformat(stamp).astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
app=ET.Element('Properties',xmlns='http://schemas.openxmlformats.org/officeDocument/2006/extended-properties')
ET.SubElement(app,'Application').text='Baseline document generator'
rbase='http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
parts={
'[Content_Types].xml':xml(ct),
'_rels/.rels':rels([('rId1',rbase+'officeDocument','word/document.xml'),('rId2','http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties','docProps/core.xml'),('rId3',rbase+'extended-properties','docProps/app.xml')]),
'word/document.xml':xml(document),'word/styles.xml':xml(styles),'word/settings.xml':xml(settings),
'word/header1.xml':xml(header),'word/footer1.xml':xml(footer),
'word/_rels/document.xml.rels':rels([('rIdStyles',rbase+'styles','styles.xml'),('rIdSettings',rbase+'settings','settings.xml'),('rIdHeader',rbase+'header','header1.xml'),('rIdFooter',rbase+'footer','footer1.xml')]),
'docProps/core.xml':xml(core),'docProps/app.xml':xml(app)
}
with zipfile.ZipFile(docx_path,'w',zipfile.ZIP_DEFLATED) as z:
    for name,content in parts.items():z.writestr(name,content)
json_path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
with zipfile.ZipFile(docx_path) as z:
    if z.testzip():raise RuntimeError('Corrupt DOCX archive')
    for name in z.namelist():
        if name.endswith('.xml') or name.endswith('.rels'):ET.fromstring(z.read(name))
    parsed=ET.fromstring(z.read('word/document.xml'))
    text='\n'.join(n.text or '' for n in parsed.iter(w('t')))
    for expected in ['Trước / sau tối ưu','Chưa đo',data['commit']]:
        if expected not in text:raise RuntimeError('Missing expected baseline value: '+expected)
    pages=1+len(parsed.findall('.//'+w('br')+'[@'+w('type')+'="page"]'))
print(json.dumps({'docx':str(docx_path),'evidence':str(json_path),'bytes':docx_path.stat().st_size,'planned_pages':pages,'tables':len(parsed.findall('.//'+w('tbl'))),'text_characters':len(text)},ensure_ascii=False))
