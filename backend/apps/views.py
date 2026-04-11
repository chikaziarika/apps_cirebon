from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required
from .models import DaerahIrigasi, LayerPendukung, Saluran, Bangunan, DetailLayananBangunan, AsetSaluran, JenisPintu, DetailSegmenSaluran, UnitPintuBangunan
from .serializers import DaerahIrigasiSerializer, DetailLayananBangunanSerializer, SaluranSerializer
from django.db.models import Sum, F
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.core.cache import cache
from django.contrib import messages
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.permissions import AllowAny, IsAuthenticated, AllowAny
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from .models import TitikIrigasi
from django.db import models
import json, io, uuid
from django.contrib.gis.geos import Point
from django.shortcuts import redirect
from django.db.models import Q
from django.db import transaction

def dashboard(request):

    data_irigasi_list = DaerahIrigasi.objects.all()
    data_saluran_raw = Saluran.objects.select_related('daerah_irigasi').all().order_by('-id')
    data_saluran_list = list(data_saluran_raw)
    
    for s in data_saluran_list:
        total = s.panjang_saluran or 0
        if total > 0:
            s.pct_baik = round(((s.panjang_baik or 0) / total) * 100, 1)
            s.pct_rr = round(((s.panjang_rr or 0) / total) * 100, 1)
            s.pct_rb = round(((s.panjang_rb or 0) / total) * 100, 1)
            s.pct_bap = round(((s.panjang_bap or 0) / total) * 100, 1)
        else:
            s.pct_baik = s.pct_rr = s.pct_rb = s.pct_bap = 0



    rekap_di = DaerahIrigasi.objects.aggregate(
        t_baku_permen=Sum('luas_baku_permen'),
        t_baku_onemap=Sum('luas_baku_onemap'),
        t_potensial=Sum('luas_potensial')
    )
    
    rekap_detail = DetailLayananBangunan.objects.aggregate(
        p_baik=Sum('sal_induk_baik'),
        p_rr=Sum('sal_induk_rusak_ringan'),
        p_rb=Sum('sal_induk_rusak_berat'),
        p_bap=Sum('sal_induk_bap'),
        s_baik=Sum('sal_sekunder_baik'),
        s_rr=Sum('sal_sekunder_rusak_ringan'),
        s_rb=Sum('sal_sekunder_rusak_berat'),
        s_bap=Sum('sal_sekunder_bap'),
        total_fungsional=Sum('luas_areal'), # Ini Luas Fungsional Real
        pintu_baik=Sum('pintu_baik'),
        pintu_rr=Sum('pintu_rusak_ringan'),
        pintu_rb=Sum('pintu_rusak_berat')
    )

    rekap_di_total = DaerahIrigasi.objects.aggregate(
        total_p_baik=Sum('primer_baik'),
        total_p_rr=Sum('primer_rr'),
        total_p_rb=Sum('primer_rb'),
        total_p_bap=Sum('primer_bap'),
        total_s_baik=Sum('sekunder_baik'),
        total_s_rr=Sum('sekunder_rr'),
        total_s_rb=Sum('sekunder_rb'),
        total_s_bap=Sum('sekunder_bap'),

    )

    global_flow_str = "graph LR\n"
    has_any_connection = False
    for di in data_irigasi_list:

        di.js_sumber = di.sumber_air if di.sumber_air else "-"
        di.js_bendung = di.bendung if di.bendung else "-"
        di.js_p_baik = di.primer_baik or 0
        di.js_p_rr = di.primer_rr or 0
        di.js_p_rb = di.primer_rb or 0
        di.js_p_bap = di.primer_bap or 0
        
        di.js_s_baik = di.sekunder_baik or 0
        di.js_s_rr = di.sekunder_rr or 0
        di.js_s_rb = di.sekunder_rb or 0
        di.js_s_bap = di.sekunder_bap or 0
        di.js_jml_pintu = (di.pintu_baik or 0) + (di.pintu_rr or 0) + (di.pintu_rb or 0)

        bangunans = Bangunan.objects.filter(
            Q(daerah_irigasi=di) | Q(saluran__daerah_irigasi=di)
        ).select_related('terhubung_ke', 'saluran').distinct()
        
        flow_str = "graph LR\n"
        has_connection = False
        
        for b in bangunans:
            if b.terhubung_ke:
                has_connection = True
                has_any_connection = True
                hulu = b.terhubung_ke.nomenklatur_ruas.replace(" ", "_").replace(".", "_")
                hilir = b.nomenklatur_ruas.replace(" ", "_").replace(".", "_")
                detail = b.layanan_list.first()
                kode_hilir = detail.kode_aset if detail else "B99"
                detail_hulu = b.terhubung_ke.layanan_list.first()
                kode_hulu = detail_hulu.kode_aset if detail_hulu else "B99"
                
                label_sal = b.saluran.nama_saluran if b.saluran else "Saluran"
                line = f'    {hulu}["{b.terhubung_ke.nomenklatur_ruas}"] -->|{label_sal}| {hilir}["{b.nomenklatur_ruas}"]\n'
                classes = f"    class {hulu} type-{kode_hulu}\n"
                classes += f"    class {hilir} type-{kode_hilir}\n"

                flow_str += line + classes
                global_flow_str += line + classes # Masuk ke skema besar
        di.flowchart_definition = flow_str if has_connection else "graph TD\n    A[Data Skema Belum Diatur]"
    total_p_baik = rekap_detail['pintu_baik'] or 0
    total_p_total = (rekap_detail['pintu_baik'] or 0) + (rekap_detail['pintu_rr'] or 0) + (rekap_detail['pintu_rb'] or 0)
    persentase_sehat = round((total_p_baik / total_p_total * 100)) if total_p_total > 0 else 0
    total_primer = Saluran.objects.filter(kode_aset_saluran='S01').aggregate(total=Sum('panjang_saluran'))['total'] or 0
    total_sekunder = Saluran.objects.filter(kode_aset_saluran='S02').aggregate(total=Sum('panjang_saluran'))['total'] or 0
    total_tersier = Saluran.objects.filter(kode_aset_saluran='S15').aggregate(total=Sum('panjang_saluran'))['total'] or 0

    rekap_kondisi_saluran = Saluran.objects.aggregate(
        t_baik=Sum('panjang_baik'),
        t_rr=Sum('panjang_rr'),
        t_rb=Sum('panjang_rb'),
        t_bap=Sum('panjang_bap')
    )

    kombinasi_baik = (rekap_detail['p_baik'] or 0) + (rekap_detail['s_baik'] or 0)
    kombinasi_rr = (rekap_detail['p_rr'] or 0) + (rekap_detail['s_rr'] or 0)
    kombinasi_rb = (rekap_detail['p_rb'] or 0) + (rekap_detail['s_rb'] or 0)

    daftar_kode = DetailLayananBangunan.objects.values_list('kode_aset', flat=True).distinct()

    def hitung_persen(nilai, total):
        return round((nilai / total) * 100, 2) if total > 0 else 0
    agg_primer = Saluran.objects.filter(kode_aset_saluran='S01').aggregate(
        tot=Sum('panjang_saluran'), b=Sum('panjang_baik'), rr=Sum('panjang_rr'), rb=Sum('panjang_rb'), bap=Sum('panjang_bap')
    )
    total_primer = agg_primer['tot'] or 0
    primer_detail = {
        'baik': round(agg_primer['b'] or 0, 2), 'rr': round(agg_primer['rr'] or 0, 2),
        'rb': round(agg_primer['rb'] or 0, 2), 'bap': round(agg_primer['bap'] or 0, 2),
        'pct_baik': hitung_persen(agg_primer['b'] or 0, total_primer),
        'pct_rr': hitung_persen(agg_primer['rr'] or 0, total_primer),
        'pct_rb': hitung_persen(agg_primer['rb'] or 0, total_primer),
        'pct_bap': hitung_persen(agg_primer['bap'] or 0, total_primer),
    }
    agg_sekunder = Saluran.objects.filter(kode_aset_saluran='S02').aggregate(
        tot=Sum('panjang_saluran'), b=Sum('panjang_baik'), rr=Sum('panjang_rr'), rb=Sum('panjang_rb'), bap=Sum('panjang_bap')
    )
    total_sekunder = agg_sekunder['tot'] or 0
    sekunder_detail = {
        'baik': round(agg_sekunder['b'] or 0, 2), 'rr': round(agg_sekunder['rr'] or 0, 2),
        'rb': round(agg_sekunder['rb'] or 0, 2), 'bap': round(agg_sekunder['bap'] or 0, 2),
        'pct_baik': hitung_persen(agg_sekunder['b'] or 0, total_sekunder),
        'pct_rr': hitung_persen(agg_sekunder['rr'] or 0, total_sekunder),
        'pct_rb': hitung_persen(agg_sekunder['rb'] or 0, total_sekunder),
        'pct_bap': hitung_persen(agg_sekunder['bap'] or 0, total_sekunder),
    }
    agg_tersier = Saluran.objects.filter(kode_aset_saluran='S15').aggregate(
        tot=Sum('panjang_saluran'), b=Sum('panjang_baik'), rr=Sum('panjang_rr'), rb=Sum('panjang_rb'), bap=Sum('panjang_bap')
    )
    total_tersier = agg_tersier['tot'] or 0
    tersier_detail = {
        'baik': round(agg_tersier['b'] or 0, 2), 'rr': round(agg_tersier['rr'] or 0, 2),
        'rb': round(agg_tersier['rb'] or 0, 2), 'bap': round(agg_tersier['bap'] or 0, 2),
        'pct_baik': hitung_persen(agg_tersier['b'] or 0, total_tersier),
        'pct_rr': hitung_persen(agg_tersier['rr'] or 0, total_tersier),
        'pct_rb': hitung_persen(agg_tersier['rb'] or 0, total_tersier),
        'pct_bap': hitung_persen(agg_tersier['bap'] or 0, total_tersier),
    }
    rekap_kondisi_saluran = {
        'baik': round(primer_detail['baik'] + sekunder_detail['baik'] + tersier_detail['baik'], 2),
        'rr': round(primer_detail['rr'] + sekunder_detail['rr'] + tersier_detail['rr'], 2),
        'rb': round(primer_detail['rb'] + sekunder_detail['rb'] + tersier_detail['rb'], 2),
        'bap': round(primer_detail['bap'] + sekunder_detail['bap'] + tersier_detail['bap'], 2),
    }

    kombinasi_baik = rekap_kondisi_saluran['baik']
    kombinasi_rr = rekap_kondisi_saluran['rr']
    kombinasi_rb = rekap_kondisi_saluran['rb']

    labels_di = []
    data_baik = []
    data_rr = []
    data_rb = []
    data_bap = []
    for di in data_irigasi_list[:10]:  # Ambil 10 besar saja
        labels_di.append(di.nama_di)
        total = (di.panjang_primer or 0) + (di.panjang_sekunder or 0)
        
        if total > 0:
            data_baik.append(round(((di.primer_baik + di.sekunder_baik) / total) * 100, 1))
            data_rr.append(round(((di.primer_rr + di.sekunder_rr) / total) * 100, 1))
            data_rb.append(round(((di.primer_rb + di.sekunder_rb) / total) * 100, 1))
            data_bap.append(round(((di.primer_bap + di.sekunder_bap) / total) * 100, 1))
        else:
            data_baik.append(0); data_rr.append(0); data_rb.append(0); data_bap.append(0)


    query_bangunan = DetailLayananBangunan.objects.select_related(
        'bangunan__daerah_irigasi', 
        'bangunan__saluran'
    ).all().order_by('-id')
    data_bangunan_list = list(query_bangunan)
    bangunan_baik = 0; bangunan_rr = 0; bangunan_rb = 0
    jml_bendung = 0; jml_pintu = 0; jml_penunjang = 0
    jml_lainnya = 0
    for b in data_bangunan_list:
        if b.kondisi_bangunan == 'BAIK': bangunan_baik += 1
        elif b.kondisi_bangunan == 'RR': bangunan_rr += 1
        elif b.kondisi_bangunan == 'RB': bangunan_rb += 1
        kode = str(b.kode_aset).upper() if b.kode_aset else ""
        jenis = str(b.bangunan.jenis_bangunan).upper() if b.bangunan and b.bangunan.jenis_bangunan else ""
        
        if kode.startswith('B') or 'BENDUNG' in jenis:
            b.kategori_filter = 'Bendung'
            jml_bendung += 1
        elif kode.startswith('P') or 'BAGI' in jenis or 'SADAP' in jenis:
            b.kategori_filter = 'Pintu'
            jml_pintu += 1
        elif kode.startswith('C') or 'PELENGKAP' in jenis:
            b.kategori_filter = 'Penunjang'
            jml_penunjang += 1
        else:
            b.kategori_filter = 'Lainnya'
            jml_lainnya += 1

    total_bangunan = len(data_bangunan_list)
    catatan_penting = query_bangunan.exclude(
        Q(keterangan__isnull=True) | Q(keterangan__exact='') | Q(keterangan__exact='-')
    )[:5]



    context = {
        'js_labels_di': labels_di,
        'js_data_keandalan': {
            'baik': data_baik,
            'rr': data_rr,
            'rb': data_rb,
            'bap': data_bap,
        },
        'total_di': DaerahIrigasi.objects.count(),
        'total_luas': rekap_detail['total_fungsional'] or 0, # Fungsional
        'total_luas_permen': rekap_di['t_baku_permen'] or 0,
        'total_luas_onemap': rekap_di['t_baku_onemap'] or 0,
        'total_luas_potensial': rekap_di['t_potensial'] or 0,
        'data_irigasi': data_irigasi_list,
        'daftar_kode_epaksi': daftar_kode,
        'jaringan_baik': kombinasi_baik,
        'total_pintu': (rekap_detail['pintu_baik'] or 0) + (rekap_detail['pintu_rr'] or 0) + (rekap_detail['pintu_rb'] or 0),
        'total_primer': total_primer,
        'total_sekunder': total_sekunder,
        'total_tersier': total_tersier,
        'primer_detail': primer_detail,  
        'sekunder_detail': sekunder_detail,
        'tersier_detail': tersier_detail,
        'rekap_kondisi_saluran': rekap_kondisi_saluran,
        'total_bangunan': total_bangunan,
        'catatan_penting': catatan_penting,
        'data_saluran': data_saluran_list,
        'data_jaringan': {
            'p': [rekap_detail['p_baik'] or 0, rekap_detail['p_rr'] or 0, rekap_detail['p_rb'] or 0, rekap_detail['p_bap'] or 0],
            's': [rekap_detail['s_baik'] or 0, rekap_detail['s_rr'] or 0, rekap_detail['s_rb'] or 0, rekap_detail['s_bap'] or 0],
            'kombinasi': [kombinasi_baik, kombinasi_rr, kombinasi_rb]
        },
        'rekap_pintu': {
            'baik': rekap_detail['pintu_baik'] or 0,
            'rr': rekap_detail['pintu_rr'] or 0,
            'rb': rekap_detail['pintu_rb'] or 0
        },
        'data_irigasi': DaerahIrigasi.objects.all(),
        'data_irigasi': data_irigasi_list,
        'persentase_sehat': persentase_sehat,
        'pintu_baik_total': total_p_baik,
        'pintu_rusak_total': (rekap_detail['pintu_rr'] or 0) + (rekap_detail['pintu_rb'] or 0),

        'global_chart_def': global_flow_str if has_any_connection else "graph TD\n    A[Data Gabungan Belum Tersedia]",

        'data_bangunan': data_bangunan_list,
        'bangunan_baik': bangunan_baik,
        'bangunan_rr': bangunan_rr,
        'bangunan_rb': bangunan_rb,
        'total_bangunan': total_bangunan,
        'catatan_penting': catatan_penting,
        'jml_bendung': jml_bendung,
        'jml_pintu': jml_pintu,
        'jml_penunjang': jml_penunjang,
        'jml_lainnya': jml_lainnya,
    }


    return render(request, 'dashboard.html', context)

def peta_irigasi(request):

    titik_irigasi = DaerahIrigasi.objects.all()
    layers_pendukung = LayerPendukung.objects.filter(aktif=True)
    
    return render(request, 'peta.html', {
        'titik_irigasi': titik_irigasi,
        'layers_pendukung': layers_pendukung
    })


def pelaporan(request):
    return render(request, 'pelaporan.html')

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def api_upload_survey(request):
    try:
        nama = request.POST.get('di_name', 'Tanpa Nama D.I')
        surveyor = request.POST.get('surveyor', 'Anonim')
        kondisi = request.POST.get('kondisi_umum', 'Baik')
        catatan = request.POST.get('catatan', '-')
        
        lat = request.POST.get('lat')
        lng = request.POST.get('lng')
        foto = request.FILES.get('foto')
        if not lat or not lng:
            return JsonResponse({"status": "error", "message": "Koordinat GPS tidak ditemukan"}, status=400)
        pnt = Point(float(lng), float(lat))
        obj = TitikIrigasi.objects.create(
            nama_lokasi=nama,
            surveyor=surveyor,
            kondisi_umum=kondisi,
            keterangan=catatan,
            koordinat=pnt,
            foto=foto
        )

        print(f"✅ Berhasil menyimpan Survey di {nama} oleh {surveyor} (ID: {obj.id})")
        return JsonResponse({
            "status": "success", 
            "id": obj.id,
            "message": "Data berhasil masuk ke PostgreSQL"
        }, status=201)

    except Exception as e:
        print(f"❌ ERROR FATAL: {str(e)}")
        return JsonResponse({"status": "error", "message": str(e)}, status=400)
    
@api_view(['POST'])
@permission_classes([AllowAny])
def api_login(request):
    username = request.data.get('username')
    password = request.data.get('password')
    
    user = authenticate(username=username, password=password)
    if user:
        login(request, user) # Ini membuat session di browser
        
        token, _ = Token.objects.get_or_create(user=user)
        
        if request.accepted_renderer.format == 'html' or 'text/html' in request.headers.get('Accept', ''):
            from django.shortcuts import redirect
            return redirect('dashboard')
            
        return Response({
            "token": token.key,
            "username": user.username,
            "is_admin": user.is_staff,
            "status": "success"
        })
    return Response({"error": "Username atau Password Salah"}, status=400)

@login_required 
def dashboard_peta(request):
    return render(request, 'dashboard.html')


def login_view(request):
    if request.method == 'POST':
        u = request.POST.get('login') 
        p = request.POST.get('password')
        cache_key = f"login_lock_{u}"
        is_locked = cache.get(cache_key)

        if is_locked:
            messages.error(request, "Terlalu banyak percobaan login. Akun ditangguhkan sementara. Silakan tunggu 1 menit.")
            return redirect('dashboard')
        user_check = User.objects.filter(username=u).first()

        if not user_check:
            messages.error(request, "Maaf, User tidak ditemukan. Silakan hubungi Administrator untuk informasi lebih lanjut.")
            return redirect('dashboard')
        user = authenticate(request, username=u, password=p)

        if user is not None:
            login(request, user)
            cache.delete(f"tries_{u}") # Reset hitungan jika berhasil
            return redirect('dashboard')
        else:
            tries_key = f"tries_{u}"
            count = cache.get(tries_key, 0) + 1
            cache.set(tries_key, count, 300) # Simpan record percobaan selama 5 menit

            if count >= 3:
                cache.set(cache_key, True, 60)
                cache.delete(tries_key) # Reset hitungan tries
                messages.error(request, "Sandi salah 3x. Akses dikunci selama 1 menit.")
            else:
                messages.error(request, f"Maaf, Password yang anda masukan salah. (Percobaan ke-{count})")
            
            return redirect('dashboard')

    return redirect('dashboard')

def logout_view(request):
    prev_url = request.META.get('HTTP_REFERER', '/')

    logout(request)
    return redirect(prev_url)

def generate_dummy_saluran(request):
    di_obj = DaerahIrigasi.objects.first() 
    
    if not di_obj:
        return HttpResponse("Buat minimal satu Daerah Irigasi dulu!")

    data_dummy = [
        {
            "nama": "PRIMER 1", "nom": "pr1", "hulu": "ITK", "hilir": "bg1", 
            "kode": "S01 / Saluran Primer", "lining": 1, "pj": 22.70, "luas": 0, 
            "prioritas": 1, "kondisi": "BAIK", "nilai": 86.5
        },
        {
            "nama": "SEKUNDER 1", "nom": "sdr1", "hulu": "bg1", "hilir": "bg2", 
            "kode": "S02 / Saluran Sekunder", "lining": 1, "pj": 50.28, "luas": 0.3, 
            "prioritas": 2, "kondisi": "SEDANG", "nilai": 73.0
        },
        {
            "nama": "SEKUNDER 5", "nom": "sdr5", "hulu": "bg4", "hilir": "bg5", 
            "kode": "S02 / Saluran Sekunder", "lining": 2, "pj": 196.27, "luas": 1.22, 
            "prioritas": 3, "kondisi": "JELEK", "nilai": 33.25
        },
    ]

    for item in data_dummy:
        Saluran.objects.get_or_create(
            daerah_irigasi=di_obj,
            nama_saluran=item['nama'],
            defaults={
                'nomenklatur': item['nom'],
                'bangunan_hulu': item['hulu'],
                'bangunan_hilir': item['hilir'],
                'kode_saluran': item['kode'],
                'jumlah_lining': item['lining'],
                'panjang_saluran': item['pj'],
                'luas_layanan': item['luas'],
                'prioritas': item['prioritas'],
                'kondisi_aset': item['kondisi'],
                'nilai_persen': item['nilai'],
                'fungsi_bangunan_sipil': "Pembawa Air",
                'fungsi_jalan_inspeksi': "Akses Pemeliharaan"
            }
        )
    return HttpResponse("3 Data Dummy Berhasil Ditambahkan!")

def get_saluran_detail(request, di_id):
    salurans = Saluran.objects.filter(daerah_irigasi_id=di_id)
    data = []
    for s in salurans:
        data.append({
            "no": 1, # Bisa dihitung di frontend
            "nama": s.nama_saluran,
            "nomenklatur": s.nomenklatur or "-",
            "hulu": s.bangunan_hulu or "-",
            "hilir": s.bangunan_hilir or "-",
            "kode": s.kode_saluran or "-",
            "foto": s.foto.url if s.foto else "/static/img/no-image.png",
            "lining": s.jumlah_lining,
            "panjang": s.panjang_saluran,
            "luas": s.luas_layanan,
            "fungsi_sipil": s.fungsi_bangunan_sipil or "-",
            "fungsi_jalan": s.fungsi_jalan_inspeksi or "-",
            "prioritas": s.prioritas,
            "kondisi": s.kondisi_aset,
            "nilai": f"{s.nilai_persen}%",
        })
    return JsonResponse({'data': data})

def get_saluran_data(request, di_id):
    from .models import AsetSaluran
    aset_salurans = AsetSaluran.objects.filter(saluran__daerah_irigasi_id=di_id).select_related('saluran')
    
    data = []
    for s in aset_salurans:
        data.append({
            "id": s.id,
            "saluran_id": s.saluran.id,
            "nama_aset_saluran": s.nama_aset_saluran, 
            "nomenklatur": s.nomenklatur,
            "bangunan_hulu": s.bangunan_hulu,
            "bangunan_hilir": s.bangunan_hilir,
            "kode_saluran": s.kode_saluran,
            "foto": s.foto.url if s.foto else None,
            "jumlah_lining": s.jumlah_lining,
            "panjang_saluran_m": s.panjang_saluran_m, 
            "fungsi_bangunan_sipil": s.fungsi_bangunan_sipil,
            "fungsi_jalan_inspeksi": s.fungsi_jalan_inspeksi,
            "prioritas": s.prioritas,
            "kondisi_aset": s.kondisi_aset,
            "nilai_persen": s.nilai_persen
        })

    return JsonResponse({'data': data})


def get_bangunan_data(request, di_id):
    saluran_id = request.GET.get('saluran_id')
    query = Bangunan.objects.filter(daerah_irigasi_id=di_id).select_related('saluran')
    if saluran_id:
        query = query.filter(saluran_id=saluran_id)
    
    results = []
    for b in query:
        results.append({
            "id": b.id,
            "nama_bangunan": b.nama_bangunan,
            "nomenklatur": b.nomenklatur,
            "latitude": b.latitude,
            "longitude": b.longitude,
            "kode_aset": b.kode_aset or "-",
            "saluran_nomenklatur": b.saluran.nomenklatur if b.saluran else "-",
            "saluran_nama": b.saluran.nama_saluran if b.saluran else "-",
            "tgl_survey": b.tgl_survey.strftime('%d-%m-%Y') if b.tgl_survey else "-",
            "tim_survey": b.tim_survey or "-",
            "foto_aset": b.foto_aset.url if b.foto_aset else None,
            "luas_layanan_ha": b.luas_layanan_ha,
            "fungsi_bangunan_sipil": b.fungsi_bangunan_sipil or "-",
            "fungsi_bangunan_me": b.fungsi_bangunan_me or "-",
            "prioritas": b.prioritas,
            "kondisi_aset": b.kondisi_aset,
            "nilai_persen": b.nilai_persen,
        })
    return JsonResponse({"data": results})

@api_view(['GET']) 
@permission_classes([AllowAny])
def api_bangunan(request, di_id):
    saluran_id = request.GET.get('saluran_id')
    query = DetailLayananBangunan.objects.filter(bangunan_id=di_id).select_related(
        'bangunan', 'bangunan__saluran', 'bangunan__daerah_irigasi'
    ).prefetch_related('unit_pintu')
    if not query.exists():
        query = DetailLayananBangunan.objects.filter(
            models.Q(bangunan__daerah_irigasi_id=di_id) | 
            models.Q(bangunan__saluran__daerah_irigasi_id=di_id)
        ).select_related('bangunan', 'bangunan__saluran', 'bangunan__daerah_irigasi').prefetch_related('unit_pintu')
    
    results = []
    for b in query:
        all_photos = []
        for field_name in ['foto_aset', 'foto_aset_2', 'foto_aset_3', 'foto_aset_4', 'foto_aset_5']:
            foto_field = getattr(b, field_name, None)
            if foto_field and hasattr(foto_field, 'url'):
                try:
                    all_photos.append(foto_field.url)
                except ValueError:
                    continue
        daftar_pintu = []
        for p in b.unit_pintu.all():
            foto_url = None
            if p.foto_pintu and hasattr(p.foto_pintu, 'url'):
                try:
                    foto_url = request.build_absolute_uri(p.foto_pintu.url)
                except ValueError:
                    foto_url = p.foto_pintu.url # Fallback jika gagal

            daftar_pintu.append({
                "nama_pintu": getattr(p, 'nama_pintu', '-'),
                "kondisi": p.kondisi,
                "lebar_pintu": p.lebar_pintu,
                "tinggi_pintu": p.tinggi_pintu,
                "foto_pintu_url": foto_url, # <--- SEKARANG FOTONYA IKUT TERKIRIM!
            })

        results.append({
            "id": b.bangunan.id,
            "id_detail": b.id,
            "nama_aset_manual": b.nama_aset_manual or "-",
            "nomenklatur_pengatur": b.nomenklatur_pengatur or "-",
            "nomenklatur_ruas": b.bangunan.nomenklatur_ruas if b.bangunan else "-",
            "kode_aset": b.kode_aset or "-",
            "kode_aset_display": b.get_kode_aset_display() if hasattr(b, 'get_kode_aset_display') and b.kode_aset else (b.kode_aset or "-"),
            "nama_di": b.bangunan.daerah_irigasi.nama_di if b.bangunan and b.bangunan.daerah_irigasi else "-",
            "nama_saluran": b.bangunan.saluran.nama_saluran if b.bangunan and b.bangunan.saluran else "-",
            "surveyor": b.surveyor or "-",
            "kecamatan": b.kecamatan or "-",
            "desa": b.desa or "-",
            
            "pintu_list": daftar_pintu,
            "nomenklatur_kiri": b.nomenklatur_kiri or "-",
            "luas_kiri": b.luas_kiri or 0,
            "jenis_saluran_kiri": b.get_jenis_saluran_kiri_display() if hasattr(b, 'get_jenis_saluran_kiri_display') else "-",
            "saluran_manual_kiri": b.saluran_manual_kiri or "-",
            
            "nomenklatur_tengah": b.nomenklatur_tengah or "-",
            "luas_tengah": b.luas_tengah or 0,
            "jenis_saluran_tengah": b.get_jenis_saluran_tengah_display() if hasattr(b, 'get_jenis_saluran_tengah_display') else "-",
            "saluran_manual_tengah": b.saluran_manual_tengah or "-",
            
            "nomenklatur_kanan": b.nomenklatur_kanan or "-",
            "luas_kanan": b.luas_kanan or 0,
            "jenis_saluran_kanan": b.get_jenis_saluran_kanan_display() if hasattr(b, 'get_jenis_saluran_kanan_display') else "-",
            "saluran_manual_kanan": b.saluran_manual_kanan or "-",

            "luas_areal": b.luas_areal or 0,
            "lebar_saluran": b.lebar_saluran or 0,
            "tinggi_saluran": b.tinggi_saluran or 0,
            
            "pintu_total_unit": b.pintu_total_unit or 0,
            "pintu_baik": b.pintu_baik or 0,
            "pintu_rusak_ringan": b.pintu_rusak_ringan or 0,
            "pintu_rusak_berat": b.pintu_rusak_berat or 0,
            
            "latitude": float(b.latitude) if b.latitude else 0,
            "longitude": float(b.longitude) if b.longitude else 0,
            "kondisi_bangunan": b.kondisi_bangunan,
            "keterangan": b.keterangan or "-",
            "foto_aset": b.foto_aset.url if hasattr(b, 'foto_aset') and b.foto_aset else None,
            "all_photos": all_photos, 
        })
    
    return Response({"data": results})


@api_view(['GET']) # <--- WAJIB ADA INI
@permission_classes([AllowAny])
def api_semua_di(request):
    """
    List semua DI untuk Map Dashboard dengan data Saluran lengkap
    """
    query = DaerahIrigasi.objects.all().prefetch_related('saluran_list')
    serializer = DaerahIrigasiSerializer(query, many=True)
    return Response({
        "data": serializer.data
    })

import csv

def upload_konjar_view(request):
    if request.method == "POST":
        csv_file = request.FILES.get('file_csv')
        
        if not csv_file.name.endswith('.csv'):
            messages.error(request, 'Mohon upload file berformat .csv')
            return redirect('upload-konjar')
        target_di = ["CIWADO", "AGUNG", "KETOS", "CIMANIS"]
        
        data = csv_file.read().decode('utf-8')
        io_string = io.StringIO(data)
        reader = csv.DictReader(io_string)

        count = 0
        for row in reader:
            nama_di_raw = row.get('DAERAH IRIGASI /                 SALURAN', '').upper()
            if any(target in nama_di_raw for target in target_di):
                obj, created = DaerahIrigasi.objects.update_or_create(
                    nama_di=nama_di_raw.strip(),
                    defaults={
                        'luas_fungsional': float(row.get('AREAL FUNGSIONAL (ha)', 0) or 0),
                        'luas_baku_permen': float(row.get('AREAL FUNGSIONAL (ha)', 0) or 0), # Sementara disamakan
                        'primer_baik': float(row.get('B', 0) or 0), # Sesuaikan posisi kolom B di CSV
                        'primer_rusak_ringan': float(row.get('RR', 0) or 0),
                        'primer_rusak_berat': float(row.get('RB', 0) or 0),
                        'total_panjang_saluran': float(row.get('PANJANG SALURAN', 0) or 0),
                    }
                )
                count += 1

        messages.success(request, f'Berhasil mengimpor {count} Daerah Irigasi target.')
        return redirect('dashboard')

    return render(request, 'upload_konjar.html')


def upload_konjar_view(request):
    if request.method == "POST":
        csv_file = request.FILES.get('file_csv')
        
        if not csv_file.name.endswith('.csv'):
            messages.error(request, 'Mohon upload file berformat .csv')
            return redirect('upload-konjar')
        target_di = ["CIWADO", "AGUNG", "KETOS", "CIMANIS"]
        
        data = csv_file.read().decode('utf-8')
        io_string = io.StringIO(data)
        reader = csv.DictReader(io_string)

        count = 0
        for row in reader:
            nama_di_raw = row.get('DAERAH IRIGASI /                 SALURAN', '').upper()
            if any(target in nama_di_raw for target in target_di):
                obj, created = DaerahIrigasi.objects.update_or_create(
                    nama_di=nama_di_raw.strip(),
                    defaults={
                        'luas_fungsional': float(row.get('AREAL FUNGSIONAL (ha)', 0) or 0),
                        'luas_baku_permen': float(row.get('AREAL FUNGSIONAL (ha)', 0) or 0), # Sementara disamakan
                        'primer_baik': float(row.get('B', 0) or 0), # Sesuaikan posisi kolom B di CSV
                        'primer_rusak_ringan': float(row.get('RR', 0) or 0),
                        'primer_rusak_berat': float(row.get('RB', 0) or 0),
                        'total_panjang_saluran': float(row.get('PANJANG SALURAN', 0) or 0),
                    }
                )
                count += 1

        messages.success(request, f'Berhasil mengimpor {count} Daerah Irigasi target.')
        return redirect('dashboard')

    return render(request, 'upload_konjar.html')


def get_di_stats(request, di_id):
    try:
        di = DaerahIrigasi.objects.get(pk=di_id)
        di.update_totals() 
        return JsonResponse({
            'total_luas': di.total_luas_fungsional,
            'total_panjang': di.total_panjang_jaringan
        })
    except DaerahIrigasi.DoesNotExist:
        return JsonResponse({'error': 'DI not found'}, status=404)

from .serializers import (
    SaluranSerializer, 
    DetailLayananBangunanSerializer, 
    DaerahIrigasiSerializer
)
@api_view(['GET'])
@permission_classes([AllowAny])
def api_saluran_list(request, di_id):
    query = Saluran.objects.filter(daerah_irigasi_id=di_id)
    serializer = SaluranSerializer(query, many=True)
    return Response({'data': serializer.data})
@api_view(['GET'])
@permission_classes([AllowAny])
def api_bangunan_list(request, di_id):

    saluran_id = request.GET.get('saluran_id')
    query = DetailLayananBangunan.objects.filter(
        Q(bangunan__saluran__daerah_irigasi_id=di_id) | 
        Q(bangunan__daerah_irigasi_id=di_id)
    ).select_related('bangunan', 'bangunan__saluran', 'jenis_pintu')\
     .distinct()\
     .order_by('-id')

    if saluran_id:
        query = query.filter(bangunan__saluran_id=saluran_id)

    serializer = DetailLayananBangunanSerializer(query, many=True)
    return Response({'data': serializer.data})
@api_view(['GET'])
@permission_classes([AllowAny])
def api_daerah_irigasi_all(request):    
    """List semua DI untuk Map Dashboard"""
    query = DaerahIrigasi.objects.all()
    serializer = DaerahIrigasiSerializer(query, many=True)
    return Response(serializer.data)

def get_saluran_geojson(request, pk):
    saluran = Saluran.objects.get(pk=pk)
    with open(saluran.geojson.path, 'r') as f:
        data = json.load(f)
    return JsonResponse(data)

def api_get_geojson(request, type_source, data_id):
    try:
        if type_source == 'di':
            obj = DaerahIrigasi.objects.get(pk=data_id)
            related_points = Bangunan.objects.filter(daerah_irigasi=obj)
        else:
            obj = Saluran.objects.get(pk=data_id)
            related_points = Bangunan.objects.filter(saluran=obj)

        if not obj.geojson:
            return JsonResponse({'error': 'File GeoJSON tidak ditemukan'}, status=404)
        with obj.geojson.open('r') as f:
            geojson_data = json.load(f)
        geojson_data['properties'] = {
            "nama": obj.nama_di if type_source == 'di' else obj.nama_saluran,
            "tipe": type_source,
            "keterangan": getattr(obj, 'keterangan', 'Tidak ada catatan khusus.')
        }
        if 'features' in geojson_data:
            for feature in geojson_data['features']:
                feature['properties']['label_status'] = "- Saluran > Bangunan" if type_source != 'di' else "- Bangunan"
                
        return JsonResponse(geojson_data)

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
    
def cetak_rekap_aset(request, di_id):
    di = get_object_or_404(DaerahIrigasi, pk=di_id)
    saluran = Saluran.objects.filter(daerah_irigasi=di)
    
    return render(request, 'laporan/rekap_aset_pdf.html', {
        'di': di,
        'saluran': saluran
    })


@api_view(['POST'])
@permission_classes([AllowAny])
@authentication_classes([])
@csrf_exempt
def api_sync_di(request):
    try:
        data = request.data
        nama_di = data.get('nama_di')
        kode_di = data.get('kode_di')

        if not nama_di:
            return Response({"status": "error", "message": "Nama DI tidak boleh kosong"}, status=400)
        di_obj, created = DaerahIrigasi.objects.update_or_create(
            nama_di=nama_di, 
            defaults={
                'kode_di': kode_di if kode_di else None,
                'bendung': data.get('bendung', 'Blm Ada'),
                'sumber_air': data.get('sumber_air', 'Blm Ada'),
                'luas_fungsional': float(data.get('luas_fungsional', 0)), 
            }
        )
        
        status_msg = "Created" if created else "Updated"
        print(f"✅ Master DI {nama_di}: {status_msg} (ID: {di_obj.id})")

        return Response({
            "status": "success", 
            "id": di_obj.id,
            "kode_di": di_obj.kode_di,
            "nama_di": di_obj.nama_di,
            "bendung": di_obj.bendung,
            "sumber_air": di_obj.sumber_air,
            "info": status_msg
        }, status=200)

    except Exception as e:
        print(f"❌ GAGAL SYNC DI: {e}")
        return Response({"status": "error", "message": str(e)}, status=400)

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
@authentication_classes([])
def api_sync_bangunan(request):
    try:
        data = request.data
        files = request.FILES 

        def safe_float(val):
            try:
                if val and str(val).lower() not in ["null", "", "none"]:
                    return float(val)
            except:
                pass
            return 0.0

        lat_val = safe_float(data.get('lat'))
        lng_val = safe_float(data.get('lng'))
        lat_final = lat_val if lat_val != 0 else None
        lng_final = lng_val if lng_val != 0 else None


        jarak_hulu = safe_float(data.get('jarak_dari_hulu'))
        
        nama_hulu = str(data.get('hulu_nomenklatur', '')).strip()
        obj_hulu = None
        if nama_hulu and nama_hulu not in ["", "0", "null", "None"]:
            obj_hulu = Bangunan.objects.filter(
                nomenklatur_ruas__iexact=nama_hulu,
                daerah_irigasi_id=data.get('di_id')
            ).first()
            if not obj_hulu:
                obj_hulu = Bangunan.objects.filter(
                    nama_bangunan__iexact=nama_hulu,
                    daerah_irigasi_id=data.get('di_id')
                ).first()

        induk_bangunan, created_induk = Bangunan.objects.get_or_create(
            nomenklatur_ruas=data.get('nama_bangunan'),
            daerah_irigasi_id=data.get('di_id'),
            defaults={
                'saluran': Saluran.objects.filter(nama_saluran=data.get('nama_saluran')).first(),
                'terhubung_ke': obj_hulu, # <--- TEMPELKAN RELASI DI SINI
                'panjang_saluran_antar_ruas': safe_float(data.get('jarak_dari_hulu'))
            }
        )
        if not created_induk:
            if obj_hulu: 
                induk_bangunan.terhubung_ke = obj_hulu
            induk_bangunan.panjang_saluran_antar_ruas = safe_float(data.get('jarak_dari_hulu'))
            induk_bangunan.save() # Simpan perubahannya ke database
        nama_jenis_pintu = data.get('jenis_pintu', '').strip()
        jp_obj = None
        if nama_jenis_pintu and nama_jenis_pintu != "null":
            jp_obj, _ = JenisPintu.objects.get_or_create(nama=nama_jenis_pintu)

        is_berlanjut_str = str(data.get('is_saluran_berlanjut', 'true')).lower()
        is_berlanjut = is_berlanjut_str in ['true', '1', 't', 'y', 'yes']
        detail, created_detail = DetailLayananBangunan.objects.update_or_create(
            bangunan=induk_bangunan,
            defaults={
                'kondisi_bangunan': data.get('kondisi_bangunan', 'BAIK').upper(), 
                'surveyor': data.get('surveyor', 'admin'),
                'latitude': lat_final,
                'longitude': lng_final,
                'kecamatan': data.get('kecamatan', ''),
                'desa': data.get('desa', ''),
                'kode_aset': data.get('kode_aset'),
                'nama_aset_manual': data.get('nama_bangunan'),
                'keterangan': data.get('keterangan', ''), 
                
                'lebar_saluran': safe_float(data.get('lebar_saluran')),
                'tinggi_saluran': safe_float(data.get('tinggi_saluran')),
                
                'pintu_baik': int(safe_float(data.get('pintu_baik'))),
                'pintu_rusak_ringan': int(safe_float(data.get('pintu_rr'))),
                'pintu_rusak_berat': int(safe_float(data.get('pintu_rb'))),
                'jenis_pintu': jp_obj, 
                'jenis_saluran_kiri': data.get('jenis_saluran_kiri', 'TERSIER'),
                'saluran_manual_kiri': data.get('saluran_manual_kiri', ''),
                'nomenklatur_kiri': data.get('nomenklatur_kiri', ''),
                'luas_kiri': safe_float(data.get('luas_kiri')),

                'jenis_saluran_tengah': data.get('jenis_saluran_tengah', 'INDUK'),
                'saluran_manual_tengah': data.get('saluran_manual_tengah', ''),
                'nomenklatur_tengah': data.get('nomenklatur_tengah', ''),
                'luas_tengah': safe_float(data.get('luas_tengah')),

                'jenis_saluran_kanan': data.get('jenis_saluran_kanan', 'TERSIER'),
                'saluran_manual_kanan': data.get('saluran_manual_kanan', ''),
                'nomenklatur_kanan': data.get('nomenklatur_kanan', ''),
                'luas_kanan': safe_float(data.get('luas_kanan')),

                'jumlah_cabang_sekunder': int(safe_float(data.get('jumlah_cabang_sekunder'))), 
                'jumlah_cabang_tersier': int(safe_float(data.get('jumlah_cabang_tersier'))),
                'is_saluran_berlanjut': is_berlanjut,
            }
        )
        kondisi = data.get('kondisi_bangunan', 'BAIK').upper()
        prefix = "baik"
        if "RR" in kondisi or "RINGAN" in kondisi: prefix = "rr"
        elif "RB" in kondisi or "BERAT" in kondisi: prefix = "rb"

        for i in range(1, 6):
            key_foto = f'foto{i}' 
            if key_foto in files:
                setattr(detail, f'foto_{prefix}{i}', files[key_foto]) 
        
        detail.save()
        UnitPintuBangunan.objects.filter(detail_layanan=detail).delete()

        p_baik = int(safe_float(data.get('pintu_baik')))
        p_rr = int(safe_float(data.get('pintu_rr')))
        p_rb = int(safe_float(data.get('pintu_rb')))
        
        l_pintu = safe_float(data.get('lebar_pintu'))
        t_pintu = safe_float(data.get('tinggi_pintu'))
        
        nomor = 1

        def buat_pintu(kondisi_pintu):
            nonlocal nomor
            idx_foto = nomor if nomor <= 3 else 3 
            foto_file = files.get(f'foto_pintu{idx_foto}') 
            
            UnitPintuBangunan.objects.create(
                detail_layanan=detail, 
                nomor_pintu=nomor, 
                nama_pintu=f"{induk_bangunan.nomenklatur_ruas} - Pintu {nomor}", 
                kondisi=kondisi_pintu, 
                lebar_pintu=l_pintu, 
                tinggi_pintu=t_pintu,
                jenis_pintu=jp_obj,
                foto_pintu=foto_file 
            )
            nomor += 1
        for _ in range(p_baik): buat_pintu('BAIK')
        for _ in range(p_rr): buat_pintu('RR')
        for _ in range(p_rb): buat_pintu('RB')
            
        detail.pintu_total_unit = p_baik + p_rr + p_rb
        detail.save()
        if detail.bangunan.daerah_irigasi:
            detail.bangunan.daerah_irigasi.update_totals()

        return Response({"status": "success", "message": "Data Bangunan & Pintu Terupdate", "id": detail.id}, status=201)

    except Exception as e:
        import traceback
        print(f"❌ ERROR SYNC BANGUNAN: {str(e)}")
        traceback.print_exc() # Print error lengkap ke terminal
        return Response({"status": "error", "message": str(e)}, status=400)

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
@authentication_classes([])
def api_sync_saluran(request):
    try:
        data = request.data
        files = request.FILES
        di_id = data.get('di_id')
        di_obj = DaerahIrigasi.objects.filter(id=di_id).first()
        
        if not di_obj:
            return Response({
                "status": "error", 
                "message": f"D.I. ID {di_id} tidak ditemukan di server. Harap Sync Master Data di HP."
            }, status=400)

        nama_surveyor = data.get('surveyor')
        kondisi_fix = data.get('kondisi') or data.get('kondisi_aset') or 'BAIK'
        jaringan_fix = data.get('tingkat_jaringan') or data.get('kode_aset_saluran') or 'S01'
        def simpan_foto_survey(file_obj):
            if file_obj:
                ext = file_obj.name.split('.')[-1]
                filename = f"survey_{uuid.uuid4().hex[:8]}.{ext}"
                path = default_storage.save(f'survey/{filename}', ContentFile(file_obj.read()))
                return path 
            return ""
        with transaction.atomic():
            
            path_foto_baik = simpan_foto_survey(files.get('foto_baik'))
            path_foto_rr = simpan_foto_survey(files.get('foto_rr'))
            path_foto_rb = simpan_foto_survey(files.get('foto_rb'))
            path_foto_bap = simpan_foto_survey(files.get('foto_bap'))

            json_foto_baik = json.dumps([path_foto_baik]) if path_foto_baik else data.get('foto_baik', '[]')
            json_foto_rr = json.dumps([path_foto_rr]) if path_foto_rr else data.get('foto_rr', '[]')
            json_foto_rb = json.dumps([path_foto_rb]) if path_foto_rb else data.get('foto_rb', '[]')
            json_foto_bap = json.dumps([path_foto_bap]) if path_foto_bap else data.get('foto_bap', '[]')
            baik, rr, rb, bap = 0, 0, 0, 0
            path_kondisi_raw = data.get('path_kondisi')
            
            if path_kondisi_raw:
                segmen_list = json.loads(path_kondisi_raw)
                for segmen in segmen_list:
                    kondisi = str(segmen.get('kondisi', '')).upper()
                    panjang = float(segmen.get('panjang', 0))
                    if 'BAIK' in kondisi: baik += panjang
                    elif 'RR' in kondisi or 'RINGAN' in kondisi: rr += panjang
                    elif 'RB' in kondisi or 'BERAT' in kondisi: rb += panjang
                    elif 'BAP' in kondisi or 'PASANGAN' in kondisi: bap += panjang
            path_raw = data.get('path_koordinat', '')
            validated_geom = None

            if path_raw:
                try:
                    points = []
                    for pt in path_raw.split('|'):
                        coords = pt.split(',')
                        if len(coords) >= 2:
                            lat = float(coords[0].strip())
                            lng = float(coords[1].strip())
                            points.append((lng, lat)) 
                    
                    if len(points) >= 2:
                        single_line = LineString(points)
                        validated_geom = MultiLineString(single_line) 
                except Exception as e:
                    print(f"⚠️ Geometri Saluran Korup dari Mobile: {e}")
                    validated_geom = None
            saluran_obj = Saluran.objects.create(
                daerah_irigasi=di_obj,
                surveyor=nama_surveyor,
                nama_saluran=data.get('nama_saluran'),
                panjang_saluran=round(float(data.get('panjang_saluran', 0)), 2),
                panjang_baik=round(baik, 2),
                panjang_rr=round(rr, 2),
                panjang_rb=round(rb, 2),
                panjang_bap=round(bap, 2),
                path_kondisi=path_kondisi_raw,
                path_koordinat=validated_geom, 
                kondisi_aset=kondisi_fix, 
                kode_aset_saluran=jaringan_fix,
                is_approved=False,
                foto_baik=json_foto_baik,
                foto_rr=json_foto_rr,
                foto_rb=json_foto_rb,
                foto_bap=json_foto_bap
            )
            if path_kondisi_raw:
                segmen_list = json.loads(path_kondisi_raw)
                for idx, s in enumerate(segmen_list):
                    segmen_obj = DetailSegmenSaluran.objects.create(
                        saluran=saluran_obj,
                        kondisi=s.get('kondisi'),
                        panjang=s.get('panjang', 0),
                        keterangan=s.get('keterangan'),
                        titik_awal=s.get('titik_awal'),
                        titik_akhir=s.get('titik_akhir'),
                        foto=json.dumps(s.get('fotos', [])) 
                    )
                    for f_idx in range(5):
                        file_key = f'segmen_{idx}_foto_{f_idx}'
                        if file_key in files:
                            if f_idx == 0: segmen_obj.foto_admin = files[file_key]
                            elif f_idx == 1: segmen_obj.foto_admin_2 = files[file_key]
                            elif f_idx == 2: segmen_obj.foto_admin_3 = files[file_key]
                            elif f_idx == 3: segmen_obj.foto_admin_4 = files[file_key]
                            elif f_idx == 4: segmen_obj.foto_admin_5 = files[file_key]
                    
                    segmen_obj.save()
            
            di_obj.update_totals()
        return Response({"status": "success", "id": saluran_obj.id}, status=201)
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({"status": "error", "message": str(e)}, status=400)


@api_view(['GET'])
@permission_classes([AllowAny])
def api_layer_pendukung_all(request):
    """Mengambil semua layer pendukung (Jalan, Batas Fungsional, dll)"""
    layers = LayerPendukung.objects.filter(aktif=True)
    data = []
    for l in layers:
        data.append({
            "id": l.id,
            "nama": l.nama,
            "kategori": l.kategori,
            "file_geojson": l.file_geojson.url if l.file_geojson else None,
            "warna_garis": l.warna_garis,
        })
    return Response(data)


@api_view(['GET'])
@permission_classes([AllowAny])
def api_bangunan_all(request):
    """Mengambil SEMUA titik bangunan dengan logika poligon yang aman (netral)"""
    query = DetailLayananBangunan.objects.select_related(
        'bangunan__daerah_irigasi'
    ).all()

    data = []
    for b in query:
        nama_poligon = "-"
        try:
            if hasattr(b.poligon_layanan, 'all'):
                poligons = b.poligon_layanan.all()
                if poligons.exists():
                    nama_poligon = ", ".join([p.nama for p in poligons])
            else:
                if b.poligon_layanan:
                    nama_poligon = b.poligon_layanan.nama
        except Exception:
            nama_poligon = "-"
        data.append({
            "id": b.bangunan.id if b.bangunan else b.id, 
            "nomenklatur": b.bangunan.nomenklatur_ruas if b.bangunan else b.nama_aset_manual,
            "latitude": b.latitude,
            "longitude": b.longitude,
            "kondisi": b.kondisi_bangunan, 
            "di": b.bangunan.daerah_irigasi.nama_di if b.bangunan and b.bangunan.daerah_irigasi else "-",
            "surveyor": b.surveyor or "Admin",
            "foto_aset": b.foto_aset.url if b.foto_aset else None,
            "kode_aset": b.kode_aset or "-",
            "kode_aset_display": b.get_kode_aset_display() if hasattr(b, 'get_kode_aset_display') and b.kode_aset else (b.kode_aset or "-"),
            "luas_areal": b.luas_areal if b.luas_areal else 0,
            "nama_poligon": nama_poligon,
            "keterangan": b.keterangan or "Tidak ada catatan khusus."
        })
        
    return Response(data)

def peta_irigasi(request):
    titik_irigasi = DaerahIrigasi.objects.filter(is_approved=True)
    layers_pendukung = LayerPendukung.objects.filter(aktif=True)
    
    return render(request, 'peta.html', {
        'titik_irigasi': titik_irigasi,
        'layers_pendukung': layers_pendukung
    })

def privacy_policy(request):
    return render(request, 'privacy_policy.html')