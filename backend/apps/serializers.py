from rest_framework import serializers  
from .models import DaerahIrigasi, DetailLayananBangunan, Saluran, Bangunan, UnitPintuBangunan
import json

class SaluranSerializer(serializers.ModelSerializer):
    nama_di = serializers.ReadOnlyField(source='daerah_irigasi.nama_di')
    geojson_url = serializers.SerializerMethodField()
    geometry_data = serializers.SerializerMethodField()
    bangunan_hilir_otomatis = serializers.SerializerMethodField()
    bangunan_hulu_nama = serializers.SerializerMethodField()
    all_photos = serializers.SerializerMethodField()
    segmen_list = serializers.SerializerMethodField()
    kode_aset_saluran_display = serializers.CharField(source='get_kode_aset_saluran_display', read_only=True)

    class Meta:
        model = Saluran
        fields = [
            'id', 'daerah_irigasi', 'nama_di', 'nama_saluran', 'surveyor', 
            'kode_aset_saluran','kode_aset_saluran_display' , 'tingkat_jaringan', 'kewenangan', 
            'panjang_saluran', 'path_koordinat', 'path_kondisi', 
            'panjang_baik', 'panjang_rr', 'panjang_rb', 'panjang_bap',
            'keterangan_baik', 'keterangan_rr', 'keterangan_rb','keterangan_bap', 
            'foto_baik', 'foto_rr', 'foto_rb', 'foto_bap',
            'is_approved', 'geojson_url', 'geometry_data',
            'bangunan_hilir_otomatis', 'bangunan_hulu_nama',
            'all_photos', 'segmen_list'
        ]

    def get_geometry_data(self, obj):
        if hasattr(obj, 'geom') and obj.geom:
            return json.loads(obj.geom.geojson) 
        return None

    def get_geojson_url(self, obj):
        if obj.geojson: return obj.geojson.url
        return None

    def get_bangunan_hulu_nama(self, obj):
        # 1. Cek apakah Admin sudah mengetik manual di field bangunan_hulu pada tabel Saluran
        manual_hulu = getattr(obj, 'bangunan_hulu', None)
        if manual_hulu and str(manual_hulu).strip() not in ["", "-", "None"]:
            return manual_hulu

        # 2. Jika kosong, gunakan logika Otomatis (Jika saluran Induk -> Hulu adalah Bendung)
        if obj.nama_saluran and "INDUK" in str(obj.nama_saluran).upper():
            return obj.daerah_irigasi.bendung if obj.daerah_irigasi and obj.daerah_irigasi.bendung else "Bendung"
        
        # 3. Otomatis untuk Sekunder/Tersier (Ambil bangunan ID terkecil/pertama diinput)
        first_bangunan = Bangunan.objects.filter(saluran=obj).order_by('id').first()
        if first_bangunan:
            return first_bangunan.nomenklatur_ruas
            
        return "-"

    def get_bangunan_hilir_otomatis(self, obj):
        # 1. Cek apakah Admin sudah mengetik manual di field bangunan_hilir pada tabel Saluran
        manual_hilir = getattr(obj, 'bangunan_hilir', None)
        if manual_hilir and str(manual_hilir).strip() not in ["", "-", "None"]:
            return manual_hilir

        # 2. Jika kosong, cari otomatis bangunan terakhir di saluran tersebut.
        # TAPI FILTER CERDAS: Abaikan bangunan yang namanya mengandung "BD" atau "Bendung"
        # karena Bendung tidak mungkin berada di ujung hilir!
        last_bangunan = Bangunan.objects.filter(
            saluran=obj
        ).exclude(
            nomenklatur_ruas__icontains='BD'
        ).order_by('-id').first()
        
        if last_bangunan:
            return last_bangunan.nomenklatur_ruas
            
        return "-"
    def get_all_photos(self, obj):
        request = self.context.get('request') 
        photo_urls = []
        segments = obj.segments.all() 
        for seg in segments:
            for i in range(1, 6):
                field_name = f'foto_admin_{i}' if i > 1 else 'foto_admin'
                photo_field = getattr(seg, field_name, None)
                if photo_field:
                    url = photo_field.url
                    if request is not None: url = request.build_absolute_uri(url)
                    photo_urls.append(url)
            
            if seg.foto:
                try:
                    mobile_photos = json.loads(seg.foto)
                    if isinstance(mobile_photos, list):
                        for p in mobile_photos:
                            if p: photo_urls.append(p)
                except:
                    pass
        return list(set(photo_urls))
    
    def get_segmen_list(self, obj):
        segmen_data = []
        segments = obj.segments.filter(geom__isnull=False) 
        for seg in segments:
            try:
                geom_json = json.loads(seg.geom.geojson)
                segmen_data.append({
                    "id": seg.id,
                    "kondisi": seg.kondisi,
                    "panjang": seg.panjang,
                    "geometry_data": geom_json
                })
            except Exception as e:
                pass
        return segmen_data
    
class DaerahIrigasiSerializer(serializers.ModelSerializer):
    saluran_list = SaluranSerializer(many=True, read_only=True)
    geojson_url = serializers.SerializerMethodField()

    class Meta:
        model = DaerahIrigasi
        fields = '__all__'

    def get_geojson_url(self, obj):
        if hasattr(obj, 'geojson') and obj.geojson: return obj.geojson.url
        return None
    
    def get_total_saluran(self, obj):
        return obj.saluran_set.filter(is_approved=True).count()
    
    def get_total_bangunan(self, obj):
        return Bangunan.objects.filter(saluran__daerah_irigasi=obj).count()

# --- SERIALIZER BARU UNTUK PINTU ---
class UnitPintuBangunanSerializer(serializers.ModelSerializer):
    jenis_pintu_nama = serializers.ReadOnlyField(source='jenis_pintu.nama')

    foto_pintu_url = serializers.SerializerMethodField()
    
    # Tambahkan SerializerMethodField agar kita bisa memanipulasi output fotonya
    foto_pintu_url = serializers.SerializerMethodField()

    class Meta:
        model = UnitPintuBangunan
        fields = [
            'id', 'nama_pintu', 'kondisi', 'lebar_pintu', 'tinggi_pintu', 
            'foto_pintu', 'foto_pintu_url', 'jenis_pintu_nama'
        ]

    # Fungsi untuk memastikan URL foto valid dan absolut
    def get_foto_pintu_url(self, obj):
        request = self.context.get('request')
        if obj.foto_pintu and hasattr(obj.foto_pintu, 'url'):
            url = obj.foto_pintu.url
            if request is not None:
                return request.build_absolute_uri(url)
            return url
        return None

class DetailLayananBangunanSerializer(serializers.ModelSerializer):
    nomenklatur_ruas = serializers.ReadOnlyField(source='bangunan.nomenklatur_ruas')
    nama_di = serializers.ReadOnlyField(source='bangunan.daerah_irigasi.nama_di') 
    nama_saluran = serializers.ReadOnlyField(source='bangunan.saluran.nama_saluran')
    all_photos = serializers.SerializerMethodField()
    
    unit_pintu = UnitPintuBangunanSerializer(many=True, read_only=True)
    

    class Meta:
        model = DetailLayananBangunan
        fields = [
            'id', 'nomenklatur_pengatur', 'nama_aset_manual', 'kode_aset',
            'nama_di', 'nama_saluran', 'nomenklatur_ruas',
            'unit_pintu',
            
            # --- KEMBALIKAN FIELD KIRI, TENGAH, KANAN KE SINI ---
            'nomenklatur_kiri', 'luas_kiri', 'jenis_saluran_kiri', 'saluran_manual_kiri',
            'nomenklatur_tengah', 'luas_tengah', 'jenis_saluran_tengah', 'saluran_manual_tengah',
            'nomenklatur_kanan', 'luas_kanan', 'jenis_saluran_kanan', 'saluran_manual_kanan',

            'luas_areal', 'lebar_saluran', 'tinggi_saluran', 'kondisi_bangunan',
            'pintu_total_unit', 'pintu_baik', 'pintu_rusak_ringan', 'pintu_rusak_berat',
            'latitude', 'longitude', 'kecamatan', 'desa', 'surveyor', 'keterangan',
            'all_photos'
        ]

    def get_all_photos(self, obj):
        photo_urls = []
        for i in range(1, 6):
            field_name = 'foto_aset' if i == 1 else f'foto_aset_{i}'
            photo = getattr(obj, field_name, None)
            if photo: photo_urls.append(photo.url)
        return photo_urls