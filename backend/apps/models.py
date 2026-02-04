from django.db import models
from django.contrib.gis.db import models
from django.contrib.gis.geos import Point, GEOSGeometry
from django.conf import settings
import os
import json
import kml2geojson
from django.conf import settings
from django.core.files.base import ContentFile
from fastkml import kml


class TitikIrigasi(models.Model):
    # Field baru dari Flutter
    nama_lokasi = models.CharField(max_length=100) # Ini di_name di Flutter
    surveyor = models.CharField(max_length=100, blank=True, null=True)
    kondisi_umum = models.CharField(max_length=50, blank=True, null=True) # Baik, Kurang Baik, Rusak
    keterangan = models.TextField() # Ini catatan di Flutter
    
    # Spasial
    koordinat = models.PointField(srid=4326) 
    
    # Foto
    foto = models.ImageField(upload_to='foto_irigasi/')
    
    waktu_input = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nama_lokasi} - {self.surveyor}"

from django.db import models

class DaerahIrigasi(models.Model):
    nama_di = models.CharField(max_length=255)
    bendung = models.CharField(max_length=255)
    sumber_air = models.CharField(max_length=255)
    
    # Luas Baku
    luas_baku_permen = models.FloatField(default=0) # Permen PU 14/2015
    luas_baku_onemap = models.FloatField(default=0) 
    
    luas_fungsional = models.FloatField(default=0)
    luas_potensial = models.FloatField(default=0)
    
    # Saluran Primer (Meters)
    primer_baik = models.FloatField(default=0)
    primer_rusak_ringan = models.FloatField(default=0)
    primer_rusak_berat = models.FloatField(default=0)
    primer_belum_pasang = models.FloatField(default=0)
    total_panjang_primer = models.FloatField(default=0)
    
    # Saluran Sekunder (Meters)
    sekunder_baik = models.FloatField(default=0)
    sekunder_rusak_ringan = models.FloatField(default=0)
    sekunder_rusak_berat = models.FloatField(default=0)
    sekunder_belum_pasang = models.FloatField(default=0)
    total_panjang_sekunder = models.FloatField(default=0)
    
    total_panjang_saluran = models.FloatField(default=0)
    
    # Pintu Pengatur (Units)
    pintu_baik = models.IntegerField(default=0)
    pintu_rusak_ringan = models.IntegerField(default=0)
    pintu_rusak_berat = models.IntegerField(default=0)
    total_jumlah_pintu = models.IntegerField(default=0)
    
    geojson = models.FileField(upload_to='geojson/di/')

    def __str__(self):
        return self.nama_di
    
from django.db import models

class Saluran(models.Model):
    daerah_irigasi = models.ForeignKey(
        'DaerahIrigasi', 
        on_delete=models.CASCADE, 
        related_name='saluran_aset'
    )
    
    # IDENTITAS & LOKASI
    nama_saluran = models.CharField(max_length=255) # Contoh: Saluran Primer Ciwado
    nomenklatur = models.CharField(max_length=100, blank=True, null=True) # Contoh: pr1
    bangunan_hulu = models.CharField(max_length=100, blank=True, null=True)
    bangunan_hilir = models.CharField(max_length=100, blank=True, null=True)
    kode_saluran = models.CharField(max_length=100, blank=True, null=True) # Contoh: S01
    
    # TEKNIS
    foto = models.ImageField(upload_to='saluran/foto/', blank=True, null=True)
    jumlah_lining = models.IntegerField(default=1, help_text="Jumlah lining saluran")
    panjang_saluran = models.FloatField(default=0, help_text="Dalam meter")
    luas_layanan = models.FloatField(default=0, help_text="Dalam Hektar (Ha)")
    
    # FUNGSI
    fungsi_bangunan_sipil = models.CharField(max_length=255, blank=True, null=True)
    fungsi_jalan_inspeksi = models.CharField(max_length=255, blank=True, null=True)
    
    # STATUS & KONDISI
    prioritas = models.IntegerField(default=1, help_text="Urutan prioritas (misal: 1, 2, 3)")
    
    KONDISI_CHOICES = [
        ('BAIK', 'BAIK'),
        ('SEDANG', 'SEDANG'),
        ('JELEK', 'JELEK'),
    ]
    kondisi_aset = models.CharField(max_length=20, choices=KONDISI_CHOICES)
    nilai_persen = models.FloatField(default=0, help_text="Nilai kondisi dalam persen (%)")

    def __str__(self):
        return f"{self.nama_saluran} - {self.daerah_irigasi.nama_di}"

    class Meta:
        verbose_name_plural = "Aset Saluran"


class Bangunan(models.Model):
    daerah_irigasi = models.ForeignKey(
        DaerahIrigasi, 
        on_delete=models.CASCADE, 
        related_name='bangunan_aset'
    )
    # Relasi ke Saluran (Sesuai kolom "SALURAN" di gambar Bapak)
    saluran = models.ForeignKey(
        Saluran,
        on_delete=models.SET_NULL,
        null=True,
        related_name='list_bangunan'
    )
    
    nama_bangunan = models.CharField(max_length=255) # Kolom NAMA
    nomenklatur = models.CharField(max_length=100)
    kode_aset = models.CharField(max_length=100) # Kolom K ASET (Contoh: A29 / Intake)
    
    # Koordinat dipisah sesuai permintaan
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    
    tgl_survey = models.DateField(null=True, blank=True)
    tim_survey = models.CharField(max_length=255, null=True, blank=True)
    foto_aset = models.ImageField(upload_to='foto_aset/bangunan/', null=True, blank=True)
    
    # Field Teknis dari Gambar
    luas_layanan_ha = models.FloatField(default=0)
    fungsi_bangunan_sipil = models.CharField(max_length=255, null=True, blank=True)
    fungsi_bangunan_me = models.CharField(max_length=255, null=True, blank=True) # M/E
    
    prioritas = models.IntegerField(default=0)
    kondisi_aset = models.CharField(max_length=50) # BAIK, SEDANG, JELEK
    nilai_persen = models.FloatField(default=0)

    def __str__(self):
        return f"{self.nama_bangunan} - {self.nomenklatur}"
    
class LayerPendukung(models.Model):
    # Tambahkan pilihan kategori di sini
    KATEGORI_CHOICES = (
        ('wilayah', 'Batas Wilayah'),
        ('jalan', 'Jaringan Jalan'),
        ('irigasi', 'Jaringan Irigasi (Saluran)'),
        ('bangunan', 'Bangunan Irigasi (Bagi/Sadap)'),
        ('bendung', 'Bendung / Headworks'),
        ('lahan', 'Luasan Areal Fungsional'),
        ('air', 'Sumber Air / Waduk'),
        
    )
    
    nama = models.CharField(max_length=100)
    # Gunakan KATEGORI_CHOICES yang baru
    kategori = models.CharField(max_length=50, choices=KATEGORI_CHOICES)
    file_geojson = models.FileField(upload_to='geojson/')
    warna_garis = models.CharField(max_length=7, default='#3388ff', help_text="Kode HEX warna")
    aktif = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.nama} ({self.get_kategori_display()})"
    
    