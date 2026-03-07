from rest_framework import serializers  
from .models import DaerahIrigasi, DetailLayananBangunan, Saluran, Bangunan
import json

class SaluranSerializer(serializers.ModelSerializer):
    nama_di = serializers.ReadOnlyField(source='daerah_irigasi.nama_di')
    geojson_url = serializers.SerializerMethodField()
    geometry_data = serializers.SerializerMethodField()
    # Field tambahan untuk kebutuhan mapping/display
    bangunan_hilir_otomatis = serializers.SerializerMethodField()
    bangunan_hulu_nama = serializers.SerializerMethodField()

    class Meta:
        model = Saluran
        # Pastikan 'surveyor' ada di sini Pak agar diizinkan masuk ke Database
        fields = [
            'id', 'daerah_irigasi', 'nama_di', 'nama_saluran', 'surveyor', 
            'kode_aset_saluran', 'tingkat_jaringan', 'kewenangan', 
            'panjang_saluran', 'path_koordinat', 'path_kondisi', 
            'panjang_baik', 'panjang_rr', 'panjang_rb', 'panjang_bap',
            'keterangan_baik', 'keterangan_rr', 'keterangan_rb','keterangan_bap', 
            'foto_baik', 'foto_rr', 'foto_rb', 'foto_bap',
            'is_approved', 'geojson_url', 'geometry_data',
            'bangunan_hilir_otomatis', 'bangunan_hulu_nama'
        ]

    def get_geometry_data(self, obj):
        if hasattr(obj, 'geom') and obj.geom:
            return json.loads(obj.geom.geojson) 
        return None

    def get_geojson_url(self, obj):
        if obj.geojson:
            return obj.geojson.url
        return None

    def get_bangunan_hilir_otomatis(self, obj):
        last_bangunan = Bangunan.objects.filter(saluran=obj).order_by('-id').first()
        if last_bangunan:
            nama_pai = getattr(last_bangunan.pai_bangunan, 'nama_bangunan', "-") if hasattr(last_bangunan, 'pai_bangunan') else "-"
            return f"{nama_pai} ({last_bangunan.nomenklatur_ruas})"
        return "-"

    def get_bangunan_hulu_nama(self, obj):
        if obj.nama_saluran and "INDUK" in obj.nama_saluran.upper():
            return obj.daerah_irigasi.bendung or "Bendung Tanpa Nama"
        
        first_bangunan = Bangunan.objects.filter(saluran=obj).order_by('id').first()
        if first_bangunan:
            nama_pai = getattr(first_bangunan.pai_bangunan, 'nama_bangunan', "") if hasattr(first_bangunan, 'pai_bangunan') else ""
            return f"{nama_pai} ({first_bangunan.nomenklatur_ruas})" if nama_pai else first_bangunan.nomenklatur_ruas
        return "-"
    
    

class DaerahIrigasiSerializer(serializers.ModelSerializer):
    saluran_list = SaluranSerializer(many=True, read_only=True)
    geojson_url = serializers.SerializerMethodField()

    class Meta:
        model = DaerahIrigasi
        fields = '__all__'

    def get_geojson_url(self, obj):
        if hasattr(obj, 'geojson') and obj.geojson:
            return obj.geojson.url
        return None
        
# 2. Serializer Saluran (UPDATE PENTING DI SINI)


class DetailLayananBangunanSerializer(serializers.ModelSerializer):
    nomenklatur_ruas = serializers.ReadOnlyField(source='bangunan.nomenklatur_ruas')
    nama_bangunan = serializers.ReadOnlyField(source='bangunan.pai_bangunan.nama_bangunan') 
    nama_saluran = serializers.ReadOnlyField(source='bangunan.saluran.nama_saluran')
    nama_jenis_pintu = serializers.ReadOnlyField(source='jenis_pintu.nama')

    class Meta:
        model = DetailLayananBangunan
        fields = '__all__'