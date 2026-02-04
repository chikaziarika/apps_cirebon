from django.contrib.gis import admin
from .models import DaerahIrigasi, TitikIrigasi , LayerPendukung
import zipfile
from fastkml import kml
from django.contrib import admin
from django.contrib.gis import admin as gis_admin
from django.shortcuts import render, redirect
from django.urls import path
from django.contrib import messages
from django.core.files.base import ContentFile
from django.contrib.gis.geos import GEOSGeometry
import json
import re
from django import forms
import pandas as pd 
import io

class FileImportForm(forms.Form):
    file_upload = forms.FileField(label="Pilih File (CSV atau Excel)")

import pandas as pd
import re
from django.contrib import admin, messages
from django.shortcuts import render, redirect
from django.urls import path
from .models import DaerahIrigasi, Saluran

@admin.register(DaerahIrigasi)
class DaerahIrigasiAdmin(admin.ModelAdmin):
    list_display = ('nama_di', 'bendung', 'sumber_air', 'luas_fungsional', 'total_panjang_saluran')
    change_list_template = "admin/daerah_irigasi_changelist.html"

    def get_urls(self):
        urls = super().get_urls()
        return [path('import-file/', self.import_file)] + urls

    def import_file(self, request):
        if request.method == "POST":
            file = request.FILES.get("file_upload")
            try:
                # Menggunakan skiprows=5 karena judul kolom aslinya ada di baris ke-5
                if file.name.lower().endswith('.csv'):
                    df = pd.read_csv(file, skiprows=5, header=None)
                else:
                    df = pd.read_excel(file, skiprows=5, header=None)

                count = 0
                for index, row in df.iterrows():
                    # SESUAIKAN INDEX BERDASARKAN HASIL CEK FILE BAPAK:
                    # Index 1 = Nomor (1, 2, 3)
                    # Index 2 = Nama D.I (D.I Ciwado, dll)
                    # Index 3 = Bendung
                    # Index 4 = Sumber Air
                    
                    nama_raw = row.iloc[2] # Kita ambil index 2 untuk Nama DI
                    if pd.isna(nama_raw) or str(nama_raw).strip().lower() in ['nan', '', 'total']:
                        continue
                        
                    nama_di = str(nama_raw).strip()

                    def to_f(val):
                        try:
                            if pd.isna(val) or str(val).strip() in ["", "-", "nan"]: return 0
                            cleaned = re.sub(r'[^\d.]', '', str(val).replace(',', '.'))
                            return float(cleaned)
                        except: return 0

                    # Mapping Data (Sudah digeser agar pas dengan kolom Excel Bapak)
                    DaerahIrigasi.objects.update_or_create(
                        nama_di=nama_di,
                        defaults={
                            'bendung': str(row.iloc[3]) if pd.notna(row.iloc[3]) else "-",
                            'sumber_air': str(row.iloc[4]) if pd.notna(row.iloc[4]) else "-",
                            'luas_baku_permen': to_f(row.iloc[5]),
                            'luas_fungsional': to_f(row.iloc[7]), # Sesuai kolom H di Excel
                            'luas_potensial': to_f(row.iloc[8]),  # Sesuai kolom I di Excel
                            
                            # Saluran Primer (Index 9, 10, 11, 12)
                            'primer_baik': to_f(row.iloc[9]),
                            'primer_rusak_ringan': to_f(row.iloc[10]),
                            'primer_rusak_berat': to_f(row.iloc[11]),
                            'primer_belum_pasang': to_f(row.iloc[12]),
                            'total_panjang_primer': to_f(row.iloc[13]),
                            
                            # Saluran Sekunder (Index 14, 15, 16, 17)
                            'sekunder_baik': to_f(row.iloc[14]),
                            'sekunder_rusak_ringan': to_f(row.iloc[15]),
                            'sekunder_rusak_berat': to_f(row.iloc[16]),
                            'sekunder_belum_pasang': to_f(row.iloc[17]),
                            'total_panjang_sekunder': to_f(row.iloc[18]),
                            
                            'total_panjang_saluran': to_f(row.iloc[19]),
                            
                            # Pintu Pengatur (Index 20, 21, 22, 23)
                            'pintu_baik': int(to_f(row.iloc[20])),
                            'pintu_rusak_ringan': int(to_f(row.iloc[21])),
                            'pintu_rusak_berat': int(to_f(row.iloc[22])),
                            'total_jumlah_pintu': int(to_f(row.iloc[23])),
                        }
                    )
                    count += 1

                messages.success(request, f"Mantap Pak! {count} data DI sudah rapi masuk ke kolomnya.")
                return redirect("..")

            except Exception as e:
                messages.error(request, f"Gagal total: {str(e)}")
                return redirect("..")

        return render(request, "admin/csv_form.html", {"form": FileImportForm()})


@admin.register(TitikIrigasi)
class TitikIrigasiAdmin(gis_admin.GISModelAdmin): # Gunakan alias gis_admin di sini
    list_display = ('nama_lokasi', 'surveyor', 'kondisi_umum', 'waktu_input')
    list_filter = ('kondisi_umum', 'waktu_input', 'nama_lokasi')
    search_fields = ('nama_lokasi', 'surveyor', 'keterangan')
    
    # Pengaturan peta di admin
    default_lat = -6.7
    default_lon = 108.5
    default_zoom = 12

@admin.register(LayerPendukung)
class LayerPendukungAdmin(admin.ModelAdmin):
    list_display = ('nama', 'kategori', 'aktif')
    list_filter = ('kategori',)


@admin.register(Saluran)
class SaluranAdmin(admin.ModelAdmin):
    # Kolom yang muncul di daftar tabel admin
    list_display = (
        'nama_saluran', 
        'daerah_irigasi', 
        'kode_saluran', 
        'panjang_saluran', 
        'kondisi_aset', 
        'nilai_persen'
    )
    
    # Menambahkan fitur filter di samping kanan
    list_filter = ('daerah_irigasi', 'kondisi_aset')
    
    # Menambahkan fitur pencarian
    search_fields = ('nama_saluran', 'kode_saluran', 'nomenklatur')
    
    # Mengelompokkan field saat input/edit
    fieldsets = (
        ('Relasi & Identitas', {
            'fields': ('daerah_irigasi', 'nama_saluran', 'nomenklatur', 'kode_saluran')
        }),
        ('Detail Teknis', {
            'fields': ('bangunan_hulu', 'bangunan_hilir', 'panjang_saluran', 'luas_layanan', 'jumlah_lining', 'foto')
        }),
        ('Fungsi & Prioritas', {
            'fields': ('fungsi_bangunan_sipil', 'fungsi_jalan_inspeksi', 'prioritas')
        }),
        ('Kondisi Aset', {
            'fields': ('kondisi_aset', 'nilai_persen')
        }),
    )    