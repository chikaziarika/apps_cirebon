from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from .models import DaerahIrigasi, LayerPendukung, Saluran, Bangunan
from django.db.models import Sum
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, permission_classes
from django.contrib.auth import authenticate, login, logout
from django.contrib import messages
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.permissions import AllowAny
from django.views.decorators.csrf import csrf_exempt
from .models import TitikIrigasi
import json
from django.contrib.gis.geos import Point
from django.shortcuts import redirect


def dashboard(request):
    data_irigasi = DaerahIrigasi.objects.all() 
    

    rekap = {
        'baik': data_irigasi.aggregate(
            total=Sum('primer_baik') + Sum('sekunder_baik') + Sum('pintu_baik')
        )['total'] or 0,
        
        'rusak_ringan': data_irigasi.aggregate(
            total=Sum('primer_rusak_ringan') + Sum('sekunder_rusak_ringan') + Sum('pintu_rusak_ringan')
        )['total'] or 0,
        
        'rusak_berat': data_irigasi.aggregate(
            total=Sum('primer_rusak_berat') + Sum('sekunder_rusak_berat') + Sum('pintu_rusak_berat')
        )['total'] or 0,
    }
    
    context = {
        'data_irigasi': data_irigasi, 
        'rekap_kondisi': rekap,
        'total_di': data_irigasi.count(),
        'total_luas': data_irigasi.aggregate(Sum('luas_fungsional'))['luas_fungsional__sum'] or 0,
    }
    return render(request, 'dashboard.html', context)

def peta_irigasi(request):

    titik_irigasi = DaerahIrigasi.objects.all()
    
    # Layer pendukung (Jalan, Batas Kabupaten, dll) tetap ada
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
        # 1. Ambil data dari Flutter sesuai field baru
        # Kita gunakan .get(nama_field_flutter, default_value)
        nama = request.POST.get('di_name', 'Tanpa Nama D.I')
        surveyor = request.POST.get('surveyor', 'Anonim')
        kondisi = request.POST.get('kondisi_umum', 'Baik')
        catatan = request.POST.get('catatan', '-')
        
        lat = request.POST.get('lat')
        lng = request.POST.get('lng')
        foto = request.FILES.get('foto')

        # 2. Validasi koordinat
        if not lat or not lng:
            return JsonResponse({"status": "error", "message": "Koordinat GPS tidak ditemukan"}, status=400)

        # 3. Buat objek Point untuk GeoDjango (Longitude dulu baru Latitude)
        pnt = Point(float(lng), float(lat))

        # 4. Simpan ke model TitikIrigasi dengan field yang sudah diupdate
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
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            "token": token.key,
            "username": user.username,
            "status": "success"
        })
    return Response({"error": "Username atau Password Salah"}, status=400)


@login_required 
def dashboard_peta(request):
    # Logika menampilkan peta irigasi
    return render(request, 'dashboard.html')


def login_view(request):
    if request.method == "POST":
        user_val = request.POST.get('username')
        pass_val = request.POST.get('password')
        user = authenticate(request, username=user_val, password=pass_val)
        
        if user is not None:
            login(request, user)
            return redirect('dashboard') 
        else:
            messages.error(request, "Username atau Password salah.")
    
    return render(request, 'dashboard.html')

def logout_view(request):
    prev_url = request.META.get('HTTP_REFERER', '/')

    logout(request)
    return redirect(prev_url)

def generate_dummy_saluran(request):
    # Ambil satu DI sebagai contoh
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
    # Pastikan 'foto' dimasukkan ke dalam values()
    salurans = Saluran.objects.filter(daerah_irigasi_id=di_id).values(
        'nama_saluran', 'nomenklatur', 'bangunan_hulu', 'bangunan_hilir',
        'kode_saluran', 'foto', 'jumlah_lining', 'panjang_saluran', 
        'luas_layanan', 'fungsi_bangunan_sipil', 'fungsi_jalan_inspeksi', 
        'prioritas', 'kondisi_aset', 'nilai_persen'
    )
    
    data = list(salurans)
    
    # Tambahkan prefix media URL jika path foto tidak lengkap (opsional, tergantung setup Django)
    for item in data:
        if item['foto']:
            # Jika menggunakan FileField/ImageField, pastikan ini mengarah ke URL yang benar
            item['foto'] = f"/media/{item['foto']}" if not item['foto'].startswith('http') else item['foto']

    return JsonResponse({'data': data})


def get_bangunan_data(request, di_id):
    # Filter data berdasarkan ID Daerah Irigasi
    # Gunakan nama field sesuai yang ada di daftar 'Choices' error Anda
    bangunans = Bangunan.objects.filter(daerah_irigasi_id=di_id).values(
        'nama_bangunan',     # Ganti dari 'nama'
        'nomenklatur', 
        'kondisi_aset',      # Ganti dari 'kondisi'
        'foto_aset',         # Ganti dari 'foto'
        'latitude', 
        'longitude',
        'fungsi_bangunan_sipil'
    )
    
    data = list(bangunans)
    
    # Tambahkan dummy data khusus jika ID adalah 888 (atau ID Ciwado lainnya)
    if str(di_id) == "888" and not data:
        data = [
            {
                "nama_bangunan": "B.Cw.1 (Dummy)", 
                "nomenklatur": "Sadap", 
                "kondisi_aset": "BAIK", 
                "latitude": "-6.826", "longitude": "108.603", 
                "foto_aset": ""
            }
        ]

    return JsonResponse({'data': data})