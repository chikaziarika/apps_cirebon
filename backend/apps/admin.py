from django.contrib.gis import admin
from .models import DaerahIrigasi, TitikIrigasi , LayerPendukung, Bangunan
from django.views.decorators.csrf import csrf_exempt
import zipfile
from fastkml import kml
from django.contrib import admin
from django.contrib.gis import admin as gis_admin
from django.shortcuts import render, redirect
from django.urls import path , reverse
from django.utils.html import format_html
from django.contrib import messages
from django.core.files.base import ContentFile
from django.contrib.gis.geos import GEOSGeometry
import json
import re
from django import forms
from leaflet.forms.widgets import LeafletWidget
import pandas as pd 
import io
import openpyxl
from django.utils.safestring import mark_safe
import json, zipfile, re, io
import pandas as pd
import openpyxl
from django.contrib import admin
from django.contrib.gis import admin as gis_admin
from django.shortcuts import render, redirect
from django.urls import path
from django.contrib import messages
from .models import DaerahIrigasi, UnitPintuBangunan, LayerPendukung, Saluran, Bangunan, DetailLayananBangunan, PelaporanAset, JenisPintu, LaporanIksiSaluran, RuasIksiSaluran, Paisaluran, DetailSegmenSaluran
from django.http import HttpResponse, JsonResponse
from leaflet.admin import LeafletGeoAdmin
from django.http import HttpResponseRedirect
import nested_admin

from django.forms import Media
# Paksa urutan global
Media.js = [
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
] + list(Media.js) if hasattr(Media, 'js') else []


# ==========================================
# ADMIN: DAERAH IRIGASI
# ==========================================
@admin.register(DaerahIrigasi)
class DaerahIrigasiAdmin(admin.ModelAdmin):
    fieldsets = (
        ('Informasi Utama', {
            'fields': ('kode_di', 'nama_di', 'kelompok_di', 'debit_awal', 'is_approved')
        }),
        ('Data Teknis & Sumber Air', {
            'fields': ('bendung', 'sumber_air', 'luas_baku_permen', 'luas_baku_onemap')
        }),
        ('Statistik Jaringan Primer (Otomatis)', {
            'fields': (('primer_baik', 'primer_rr', 'primer_rb', 'primer_bap'), 'panjang_primer'),
            'description': 'Nilai ini dihitung otomatis dari detail layanan bangunan'
        }),
        ('Statistik Jaringan Sekunder (Otomatis)', {
            'fields': (('sekunder_baik', 'sekunder_rr', 'sekunder_rb', 'sekunder_bap'), 'panjang_sekunder'),
        }),
        ('Statistik Pintu & Luas', {
            'fields': (('pintu_baik', 'pintu_rr', 'pintu_rb'), 'jumlah_pintu', 'total_luas_fungsional'),
        }),
        ('Data Spasial', {
            'fields': ('geojson', 'path_koordinat'),
        }),
    )
    
    # list_display = ('nama_di', 'kode_di', 'bendung', 'total_luas_fungsional', 'is_approved')
    list_display = ('nama_di', 'kode_di', 'get_luas_format', 'get_primer_format', 'is_approved')
    
    list_filter = ('kelompok_di', 'is_approved')
    search_fields = ('nama_di', 'kode_di')
    # Membuat field statistik menjadi Read Only agar tidak diubah manual
    readonly_fields = (
        'primer_baik', 'primer_rr', 'primer_rb', 'primer_bap', 'panjang_primer',
        'sekunder_baik', 'sekunder_rr', 'sekunder_rb', 'sekunder_bap', 'panjang_sekunder',
        'pintu_baik', 'pintu_rr', 'pintu_rb', 'jumlah_pintu', 'total_luas_fungsional'
    )
    
    actions = ['approve_di', 'force_update_stats']

    def force_update_stats(self, request, queryset):
        count = 0
        for di in queryset:
            # Panggil fungsi update_totals yang sudah Bapak buat di models.py
            di.update_totals()
            count += 1
        self.message_user(request, f"Berhasil menghitung ulang statistik untuk {count} D.I.")
    force_update_stats.short_description = "🔄 Hitung Ulang Statistik (Refresh Total)"

    @admin.display(description='Luas Baku (Ha)')
    def get_luas_format(self, obj):
        return f"{round(obj.luas_baku_permen, 2)} Ha"

    @admin.display(description='Total Primer (m)')
    def get_primer_format(self, obj):
        return f"{round(obj.panjang_primer, 2)} m"

    def approve_di(self, request, queryset):
        queryset.update(is_approved=True)
        self.message_user(request, "Daerah Irigasi berhasil disetujui!")
    approve_di.short_description = "Setujui D.I. yang dipilih"

    def get_urls(self):
        urls = super().get_urls()
        return [path('import-excel/', self.import_excel, name='import-excel')] + urls

    def import_excel(self, request):
        if request.method == "POST":
            excel_file = request.FILES.get('excel_file')
            try:
                wb = openpyxl.load_workbook(excel_file, data_only=True)
                sheet = wb.active
                target_di = ["CIWADO", "AGUNG", "KETOS", "CIMANIS"]
                count = 0

                for row in sheet.iter_rows(min_row=9, values_only=True):
                    nama_raw = str(row[2]).upper() if row[2] else ""
                    if any(target in nama_raw for target in target_di):
                        # Import ke Master D.I.
                        DaerahIrigasi.objects.update_or_create(
                            kode_di=str(row[1]).strip() if row[1] else f"DI-{row[2]}",
                            defaults={'nama_di': str(row[2]).strip()}
                        )
                        count += 1
                messages.success(request, f"Berhasil mengimpor {count} Master D.I.")
                return redirect("..")
            except Exception as e:
                messages.error(request, f"Gagal Import: {str(e)}")
                return redirect("..")
        return render(request, "admin/excel_upload.html")

# ==========================================
# ADMIN: SALURAN
# ==========================================

class PaiSaluranInline(admin.StackedInline):
    model = Paisaluran
    can_delete = False
    verbose_name = "Informasi PAI (Pengelolaan Aset Irigasi)"
    fieldsets = (
        ('Identitas Aset', {'fields': (('jenis_aset_kode', 'nama_aset', 'nomenklatur'), ('bangunan_hulu', 'bangunan_hilir'))}),
        ('Kapasitas & Pintu', {'fields': (('luas_layanan_ha', 'q_desain', 'panjang_saluran_m'), ('pintu_jumlah', 'pintu_lebar_m', 'pintu_tinggi_m'))}),
        # ('Dimensi Desain vs Nyata', {
        #     'fields': (('desain_b', 'desain_h', 'desain_kemiringan'), ('nyata_b', 'nyata_h'))
        # }),
    )

class LaporanIksiInline(admin.TabularInline):
    model = LaporanIksiSaluran
    extra = 0
    fields = ('tahun', 'total_nilai_iksi') 
    readonly_fields = ('total_nilai_iksi',) 
    verbose_name = "Riwayat IKSI"
    verbose_name_plural = "Riwayat Kondisi IKSI (Per Tahun)"


class DetailSegmenForm(forms.ModelForm):
    class Meta:
        model = DetailSegmenSaluran
        fields = '__all__'
        widgets = {
            'geom': LeafletWidget(), # Memunculkan peta untuk field geom
        }


class DetailSegmenInline(admin.StackedInline):
    model = DetailSegmenSaluran
    form = DetailSegmenForm
    extra = 1  
    fields = ('kondisi', 'panjang', 'titik_awal', 'titik_akhir', 'geom', 'foto_admin', 'display_foto_segmen', 'keterangan')
    readonly_fields = ('display_foto_segmen',)
    classes = ('collapse',)

    verbose_name = "Detail Ruas Per Segmen Kondisi"
    verbose_name_plural = "DAFTAR SEGMEN KONDISI (Banyak Segmen)"

    @admin.display(description='Preview Foto (Hybrid)')
    def display_foto_segmen(self, obj):
        html_output = '<div style="display: flex; gap: 10px;">'
        
        # 1. Render Foto dari Admin (jika ada)
        if hasattr(obj, 'foto_admin') and obj.foto_admin:
            html_output += f'<img src="{obj.foto_admin.url}" style="height: 60px; width: 90px; object-fit: cover; border: 2px solid #28a745;"/>'
            
        # 2. Render Foto dari Mobile App (jika ada JSON)
        if obj.foto and obj.foto not in ["[]", "null", ""]:
            try:
                path = obj.foto.replace('[', '').replace(']', '').replace('"', '').replace("'", "").split(',')[0].strip()
                if path:
                    full_url = f"/media/{path}" if not path.startswith(('http', '/media/')) else path
                    html_output += f'<img src="{full_url}" style="height: 60px; width: 90px; object-fit: cover; border: 2px solid #007bff;"/>'
            except:
                pass
                
        html_output += '</div>'
        if html_output == '<div style="display: flex; gap: 10px;"></div>':
            return mark_safe('<span style="color: #999; font-size: 0.8rem;">Tidak ada foto</span>')
        return mark_safe(html_output)


    def get_formset(self, request, obj=None, **kwargs):
        formset = super().get_formset(request, obj, **kwargs)
        # Menambahkan CSS sederhana untuk warna teks kondisi
        return formset

    @admin.display(description='Preview Foto')
    def display_foto_segmen(self, obj):
        if obj.foto and obj.foto not in ["[]", "null", ""]:
            try:
                # Bersihkan string JSON jika ada (menangani ["path/ke/foto.jpg"])
                path = obj.foto.replace('[', '').replace(']', '').replace('"', '').replace("'", "").split(',')[0].strip()
                
                if path:
                    # Cek apakah path sudah punya /media/ atau belum
                    full_url = f"/media/{path}" if not path.startswith(('http', '/media/')) else path
                    return mark_safe(f'<img src="{full_url}" style="height: 60px; width: 90px; object-fit: cover; border-radius: 4px; border: 1px solid #ccc;"/>')
            except:
                pass
        return mark_safe('<span style="color: #999; font-size: 0.8rem;">Tidak ada foto</span>')

from leaflet.admin import LeafletGeoAdminMixin
from leaflet.forms.widgets import LeafletWidget



@admin.register(Saluran)
class SaluranAdmin(LeafletGeoAdminMixin, admin.ModelAdmin):

    change_form_template = "admin/saluran_change_form.html"
    settings_overrides = {
        'DEFAULT_CENTER': (-6.826, 108.604),
        'DEFAULT_ZOOM': 18,
        'MAX_ZOOM': 21,
    }
    search_fields = ('nama_saluran', 'surveyor')
    actions = ['approve_saluran']
    # list_display = ('nama_saluran', 'daerah_irigasi', 'tingkat_jaringan', 'tombol_pilih_kmz', 'is_approved') # Tambahkan tombol di list
    # list_display = ('nama_saluran', 'daerah_irigasi', 'surveyor', 'tingkat_jaringan', 'get_panjang_format', 'is_approved') 
    # readonly_fields = ('areal_fungsional', 'panjang_saluran', 'tombol_pilih_kmz')

    inlines = [DetailSegmenInline, PaiSaluranInline, LaporanIksiInline]

    list_display = (
        'nama_saluran', 
        'daerah_irigasi', 
        'surveyor', 
        'tingkat_jaringan',    
        'get_panjang_format', 
        'is_approved',   
    )
    
    
    fieldsets = (
        ('Informasi Utama', {
            'fields': ('nama_saluran', 'daerah_irigasi', 'surveyor', 'tingkat_jaringan', 'is_approved')
        }),
        ('Data Geospasial', {
            'fields': ('panjang_saluran', 'geom', 'geojson', 'tombol_pilih_kmz')
        }),
        ('Rekap Kondisi (Meter)', {
            'fields': (
                ('panjang_baik', 'panjang_rr', 'panjang_rb', 'panjang_bap'),
            )
        }),
    )

    # PENTING: Semua yang berawal 'display_' harus masuk ke sini
    # readonly_fields = (
    #     'display_foto_baik', 
    #     'display_foto_rr', 
    #     'display_foto_rb', 
    #     'display_foto_bap',
    #     # 'panjang_saluran',
    # )
    readonly_fields = ()

    
    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        # Setelah semua segmen disimpan, panggil fungsi update total
        obj = form.instance
        if hasattr(obj, 'update_from_segments'):
            obj.update_from_segments()
        elif hasattr(obj, 'refresh_summary'):
            obj.refresh_summary()

    def recalculate_segments(self, request, queryset):
        count = 0
        for obj in queryset:
            obj.refresh_summary() # Fungsi yang kita buat di models.py
            count += 1
        self.message_user(request, f"Berhasil menghitung ulang panjang dari segmen untuk {count} saluran.")
    recalculate_segments.short_description = "🔄 Hitung Ulang Panjang dari Segmen"



    # 4. Fungsi untuk memformat angka panjang agar ada satuan 'm'
    @admin.display(description='Panjang (m)', ordering='panjang_saluran')
    def get_panjang_format(self, obj):
        if obj.panjang_saluran:
            return f"{round(obj.panjang_saluran, 2)} m"
        return "0 m"

    
    def approve_saluran(self, request, queryset):
        queryset.update(is_approved=True)
        self.message_user(request, f"{queryset.count()} saluran berhasil disetujui.")
    approve_saluran.short_description = "Setujui saluran yang dipilih"
    
    @admin.display(description='Dokumentasi Saluran Baik')
    def display_foto_baik(self, obj):
        return self._generate_photo_preview(obj.foto_baik)

    @admin.display(description='Dokumentasi Saluran Rusak Ringan')
    def display_foto_rr(self, obj):
        return self._generate_photo_preview(obj.foto_rr)

    @admin.display(description='Dokumentasi Saluran Rusak Berat')
    def display_foto_rb(self, obj):
        return self._generate_photo_preview(obj.foto_rb)
    
    @admin.display(description='Dokumentasi Saluran Belum Ada Pasangan')
    def display_foto_bap(self, obj):
        return self._generate_photo_preview(obj.foto_bap)

    def _generate_photo_preview(self, json_photo_data):
        if not json_photo_data or json_photo_data in ["[]", "null", ""]:
            return mark_safe('<div style="color:gray;">Tidak ada foto</div>')
        
        try:
            # 1. Bersihkan karakter aneh jika data dikirim sebagai string mentah
            clean_data = json_photo_data.replace("'", '"')
            
            # 2. Parse JSON
            import json
            photo_list = json.loads(clean_data) if clean_data.startswith('[') else [clean_data]
            
            html_output = '<div style="display: flex; flex-wrap: wrap; gap: 10px;">'
            for path in photo_list:
                if not path: continue
                # Tambahkan /media/ jika path tidak diawali /media/
                url = f"/media/{path}" if not path.startswith(('/media/', 'http')) else path
                html_output += format_html(
                    '<div style="text-align:center;">'
                    '<img src="{}" style="height: 100px; border-radius: 8px; border: 1px solid #ccc;"/>'
                    '</div>', url
                )
            html_output += '</div>'
            return mark_safe(html_output)
        except Exception as e:
            return mark_safe(f'<span style="color:red;">Format Error: {e}</span>')

    @admin.display(description='Panjang (m)', ordering='panjang_saluran')
    def get_panjang_format(self, obj):
        return f"{round(obj.panjang_saluran, 2)} m"
    
    def get_readonly_fields(self, request, obj=None):

        readonly = list(self.readonly_fields)
        

        if 'tombol_pilih_kmz' not in readonly:
            readonly.append('tombol_pilih_kmz')

        return tuple(readonly)

    def approve_saluran(self, request, queryset):

        queryset.update(is_approved=True)
        

        for obj in queryset:
            if obj.daerah_irigasi:
                obj.daerah_irigasi.update_totals()
                
        self.message_user(request, f"{queryset.count()} Survey Saluran telah disetujui dan masuk ke statistik D.I.")
    approve_saluran.short_description = "Setujui Survey Saluran (Update Statistik DI)"

    @admin.display(description='Aksi Geospasial')
    def tombol_pilih_kmz(self, obj):
        if obj.pk and obj.geojson and obj.geojson.name.lower().endswith('.kmz'):
            # Generate URL ke view selector yang sudah Bapak buat
            url = reverse('admin:saluran-kmz-selector', args=[obj.pk])
            return format_html(
                '<a class="button" href="{}" style="background-color: #417690; color: white; padding: 5px 15px; border-radius: 4px;">'
                'Pilih Objek dari File KMZ</a>', 
                url
            )
        return mark_safe('<span style="color: gray;">Simpan file KMZ terlebih dahulu</span>')


    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('<int:object_id>/import-kmz/', self.admin_site.admin_view(self.kmz_selector_view), name='saluran-kmz-selector'),
        ]
        return custom_urls + urls


    def kmz_selector_view(self, request, object_id):
        import zipfile
        import xml.etree.ElementTree as ET
        from django.contrib.gis.geos import GEOSGeometry, MultiLineString, LineString
        from django.shortcuts import render
        
        obj = self.get_object(request, object_id)
        features_found = []

        if obj.geojson and obj.geojson.name.lower().endswith('.kmz'):
            try:
                with zipfile.ZipFile(obj.geojson.path, 'r') as zf:
                    content = zf.read('doc.kml')
                    utf8_content = content.decode('utf-8', errors='ignore')
                    root = ET.fromstring(utf8_content)
                    ns = {'kml': 'http://www.opengis.net/kml/2.2'}
                    
                    # Gunakan enumerate() agar idx dan pm bisa terbaca (expected 2)
                    for idx, pm in enumerate(root.findall('.//kml:Placemark', ns)):
                        name_node = pm.find('kml:name', ns)
                        name = name_node.text if name_node is not None else f"Objek {idx}"
                        
                        ls_node = pm.find('.//kml:LineString', ns)
                        if ls_node is not None:
                            coord_node = ls_node.find('.//kml:coordinates', ns)
                            if coord_node is not None:
                                features_found.append({
                                    'id': idx,
                                    'name': name,
                                    'coords': coord_node.text.strip()
                                })


                if request.method == 'POST':
                    selected_indices = request.POST.getlist('selected_features')
                    all_lines = []
                    total_panjang_kml = 0

                    for idx_str in selected_indices:
                        idx = int(idx_str)
                        feature = features_found[idx]
                        
                        points = []
                        for p in feature['coords'].split():
                            c = p.split(',')
                            if len(c) >= 2:
                                points.append((float(c[0]), float(c[1])))
                        
                        if len(points) >= 2:
                            line = LineString(points)
                            # all_lines.append(LineString(points))
                            all_lines.append(line)
                            
                            # from django.contrib.gis.geos import GEOSGeometry
                            total_panjang_kml += line.length * 111320

                    if all_lines:
                        obj.geom = MultiLineString(all_lines)
                        obj.panjang_saluran = round(total_panjang_kml, 2)

                        obj.save()

                        if not obj.segments.exists():
                            DetailSegmenSaluran.objects.create(
                                saluran=obj,
                                kondisi='BAIK',
                                panjang=obj.panjang_saluran,
                                keterangan="Import dari KMZ"
                            )

                        if obj.daerah_irigasi:
                            obj.daerah_irigasi.update_totals()

                        self.message_user(request, f"Sukses menggabungkan {len(all_lines)} segmen pilihan ke peta!")
                        return HttpResponseRedirect("../change/")
                    else:
                        self.message_user(request, "Peringatan: Tidak ada segmen yang dipilih atau data koordinat tidak valid.", level='WARNING')

            except Exception as e:
                print(f"DEBUG ERROR: {str(e)}")
                self.message_user(request, f"Terjadi kesalahan: {e}", level='ERROR')

        return render(request, 'admin/kmz_selector.html', {
            'obj': obj,
            'features': features_found,
            'opts': self.model._meta,
        })
    
    def change_view(self, request, object_id, form_url='', extra_context=None):
        extra_context = extra_context or {}
        obj = self.get_object(request, object_id)
        
        # Jika saluran utama sudah punya garis peta (geom), kirim format JSON-nya
        if obj and obj.geom:
            extra_context['parent_saluran_geojson'] = obj.geom.json
        else:
            extra_context['parent_saluran_geojson'] = 'null'
            
        return super().change_view(request, object_id, form_url, extra_context=extra_context)
    

    def save_model(self, request, obj, form, change):
        if obj.geom:
            try:

                obj.panjang_saluran = round(obj.geom.transform(32749, clone=True).length, 2)
            except:
                # Fallback jika transformasi gagal
                obj.panjang_saluran = round(obj.geom.length * 111320, 2)
        
        super().save_model(request, obj, form, change)
        
        # Update total ke DI
        if obj.is_approved and obj.daerah_irigasi:
            obj.daerah_irigasi.update_totals()

    


# ==========================================
# ADMIN: BANGUNAN
# ==========================================

@admin.register(JenisPintu)
class JenisPintuAdmin(admin.ModelAdmin):
    search_fields = ['nama']


class UnitPintuInline(nested_admin.NestedTabularInline):
    model = UnitPintuBangunan
    extra = 1  # Baris kosong untuk input pintu baru
    fields = ('nomor_pintu', 'jenis_pintu', 'kondisi', 'lebar_pintu', 'tinggi_pintu', 'foto_pintu')



class DetailLayananInline(nested_admin.NestedStackedInline):
    model = DetailLayananBangunan
    autocomplete_fields = ['jenis_pintu']
    readonly_fields = ('pintu_total_unit', 'display_foto_galeri')
    extra = 0
    inlines = [UnitPintuInline]


    def update_pintu_stats(self):
        unit = self.unit_pintu.all()
        self.pintu_total_unit = unit.count()
        self.pintu_baik = unit.filter(kondisi='BAIK').count()
        self.pintu_rusak_ringan = unit.filter(kondisi='RR').count()
        self.pintu_rusak_berat = unit.filter(kondisi='RB').count()
        self.save()
    
    def display_foto_galeri(self, obj):
        from django.utils.html import format_html
        html_output = '<div style="display: flex; gap: 10px; flex-wrap: wrap;">'
        
        if obj.foto_aset:
             html_output += format_html(
                '<div style="text-align:center;">'
                '<img src="{}" style="height: 120px; border-radius: 8px; border: 2px solid #417690;"/>'
                '<br/><small style="color:#417690; font-weight:bold;">Upload Admin</small></div>',
                obj.foto_aset.url
            )

        kategori_foto = ['baik', 'rr', 'rb']
        found_any = False
        for kat in kategori_foto:
            for i in range(1, 6):
                field_name = f'foto_{kat}{i}'
                foto_field = getattr(obj, field_name, None)
                if foto_field:
                    found_any = True
                    html_output += format_html(
                        '<div style="text-align:center;">'
                        '<img src="{}" style="height: 100px; border-radius: 5px; border: 2px solid {};"/>'
                        '<br/><small>{} {}</small></div>',
                        foto_field.url,
                        'green' if kat == 'baik' else 'orange' if kat == 'rr' else 'red',
                        kat.upper(), i
                    )
        
        html_output += '</div>'
        return mark_safe(html_output) if found_any else "Belum ada foto survey."
    
    display_foto_galeri.short_description = "Galeri Foto Survey (Kondisi Terakhir)"

    fieldsets = (
        ('Data Teknis Survey', {
            'fields': (
                ('kode_aset', 'nama_aset_manual'), 
                'surveyor',
                'foto_aset',
                ('luas_areal', 'poligon_layanan'), 
                'display_foto_galeri'
            )
        }),
        # ('Kondisi Pintu (Multi-Pintu)', {
        #     'description': 'Jika jumlah pintu > 1, maka otomatis dianggap sebagai bangunan pengatur/bagi.',
        #     'fields': (
        #         'jenis_pintu',
        #         ('pintu_baik', 'pintu_rusak_ringan', 'pintu_rusak_berat'),
        #         'pintu_total_unit' # Otomatis jumlah dari 3 field di atas
        #     )
        # }),
        ('Data Percabangan & Kelanjutan', {
            'fields': (
                ('jumlah_cabang_sekunder', 'jumlah_cabang_tersier'),
                'is_saluran_berlanjut',
            ),
            'description': 'Informasi teknis koneksi jaringan di titik bangunan ini.'
        }),
        ('Data Teknis Lainnya', {
            'classes': ('collapse',),
            'fields': (
                ('lebar_saluran', 'tinggi_saluran'),
                ('latitude', 'longitude'),
                ('kecamatan', 'desa'),
                'kondisi_bangunan',
                'keterangan'
            )
        }),
    )

    class Media:
        css = {
            'all': (
                'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
                'https://api.mapbox.com/mapbox.js/plugins/leaflet-fullscreen/v1.0.1/leaflet.fullscreen.css', # TAMBAHKAN INI
            )
        }
        js = (
            'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
            'https://api.mapbox.com/mapbox.js/plugins/leaflet-fullscreen/v1.0.1/Leaflet.fullscreen.min.js', # TAMBAHKAN INI
            'admin/js/inline_map_editor.js',
            'admin/js/bangunan_admin.js',
        )

        

class BangunanForm(forms.ModelForm):
    class Meta:
        model = Bangunan
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
    
        if self.instance.pk:
            if self.instance.daerah_irigasi:
                self.fields['terhubung_ke'].queryset = Bangunan.objects.filter(
                    daerah_irigasi=self.instance.daerah_irigasi
                ).exclude(pk=self.instance.pk)
            elif self.instance.saluran:
                self.fields['terhubung_ke'].queryset = Bangunan.objects.filter(
                    saluran__daerah_irigasi=self.instance.saluran.daerah_irigasi
                ).exclude(pk=self.instance.pk)




@admin.register(Bangunan)
class BangunanAdmin(nested_admin.NestedModelAdmin):

    list_display = ('nomenklatur_ruas', 'jenis_bangunan', 'daerah_irigasi', 'saluran')
    list_filter = ('jenis_bangunan', 'daerah_irigasi')
    search_fields = ('nomenklatur_ruas',)
    autocomplete_fields = ['terhubung_ke', 'daerah_irigasi', 'saluran']
    change_list_template = "admin/bangunan_changelist.html"
    inlines = [DetailLayananInline]

    def get_full_nomenklatur(self, obj):
        return obj.get_full_nomenklatur()
    get_full_nomenklatur.short_description = 'Data Aset Bangunan'

    def display_skema(self, obj):
        if obj.terhubung_ke:
            return format_html('<span style="color: #28a745; font-weight:bold;">⬅ Hulu: {}</span>', obj.terhubung_ke.nomenklatur_ruas)
        return format_html('<span style="color: #999; font-style:italic;">(Titik Awal / Bendung)</span>')
    display_skema.short_description = 'Koneksi Skema'

    def display_icon(self, obj):
        if obj.icon_png:
            return format_html('<img src="{}" style="height: 30px; width: auto;"/>', obj.icon_png.url)
        return "No Icon"
    display_icon.short_description = 'Simbol ePAKSI'

    def get_induk(self, obj):
        if obj.daerah_irigasi:
            return f"DI: {obj.daerah_irigasi.nama_di}"
        if obj.saluran:
            return f"Sal: {obj.saluran.nama_saluran}"
        return "-"
    get_induk.short_description = 'Terikat Pada'

    # def get_induk(self, obj):
    #     if obj.saluran:
    #         url = reverse('admin:apps_saluran_change', args=[obj.saluran.id])
    #         return format_html('<a href="{}" style="font-weight: bold; color: #264b5d;">Sal: {}</a>', url, obj.saluran.nama_saluran)
        
    #     if obj.daerah_irigasi:
    #         url = reverse('admin:apps_daerahirigasi_change', args=[obj.daerah_irigasi.id])
    #         return format_html('<a href="{}" style="font-weight: bold; color: #70401b;">DI: {}</a>', url, obj.daerah_irigasi.nama_di)
            
    #     return "-"
    
    get_induk.short_description = 'Terikat Pada (Klik untuk Cek Update)'

    # 4. Susunan Form Input (Fieldsets)
    fieldsets = (
        ('Informasi Utama', {
            'fields': (('daerah_irigasi', 'saluran'), 'nomenklatur_ruas')
        }),
        ('Skema Jaringan (Relasi Hulu-Hilir)', {
            'fields': (('terhubung_ke', 'panjang_saluran_antar_ruas'),),
            'description': 'Tentukan hulu dari bangunan ini agar sistem dapat menggambar alur flowchart secara otomatis.'
        }),
        # ('Custom Asset', {
        #     'fields': ('icon_png',),
        #     'description': 'Upload icon PNG transparan standar ePAKSI untuk visualisasi di flowchart.'
        # }),
    )


    class Media:
        js = ('admin/js/bangunan_admin.js',)

    def changelist_view(self, request, extra_context=None):
        extra_context = extra_context or {}
        extra_context['map_editor_url'] = reverse('admin:bangunan-map-editor')
        return super().changelist_view(request, extra_context=extra_context)
    
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            # Tambahkan path ini. 
            # Menggunakan <path:di_id> atau <int:di_id>
            path('get-di-stats/<int:di_id>/', self.admin_site.admin_view(self.get_di_stats), name='get-di-stats'),
            path('map-editor/', self.admin_site.admin_view(self.map_editor_view), name='bangunan-map-editor'),
            path('update-skema-api/', self.admin_site.admin_view(self.update_skema_api), name='update-skema-api'),
            path('get-poligon-luas/<int:layer_id>/', self.admin_site.admin_view(self.get_poligon_luas), name='get-poligon-luas'),
        ]
        return custom_urls + urls

    def get_poligon_luas(self, request, layer_id):
        import json
        try:
            layer = LayerPendukung.objects.get(pk=layer_id)
            luas_val = 0.0
            
            if layer.file_geojson:
                try:
                    # Buka dan baca file GeoJSON dari storage
                    file_data = layer.file_geojson.read().decode('utf-8')
                    geo_json = json.loads(file_data)
                    
                    # Cek features dan ambil properti luas_fungsional
                    if 'features' in geo_json and len(geo_json['features']) > 0:
                        props = geo_json['features'][0].get('properties', {})
                        # Mengambil dari key 'luas_fungsional' atau 'Luas_Fung' (sesuai script kmz Bapak)
                        luas_val = props.get('luas_fungsional', props.get('Luas_Fung', 0.0))
                except Exception as e:
                    print(f"Error membaca JSON Layer: {e}")
                    
            return JsonResponse({'luas_areal': round(float(luas_val), 2)})
            
        except LayerPendukung.DoesNotExist:
            return JsonResponse({'error': 'Layer tidak ditemukan'}, status=404)

    def get_di_stats(self, request, di_id):
        try:
            di = DaerahIrigasi.objects.get(pk=di_id)
            return JsonResponse({
                'total_luas': float(di.luas_baku_permen or 0),
                'nama_di': di.nama_di
            })
        except DaerahIrigasi.DoesNotExist:
            return JsonResponse({'error': 'DI tidak ditemukan'}, status=404)
        

    def update_skema_api(self, request):
        if request.method == "POST":
            import json
            try:
                data = json.loads(request.body)
                hilir_id = data.get('hilir_id')
                hulu_id = data.get('hulu_id')
                
                # Gunakan update() agar cepat
                Bangunan.objects.filter(id=hilir_id).update(terhubung_ke_id=hulu_id)
                
                return JsonResponse({"status": "success", "message": "Relasi berhasil diperbarui!"})
            except Exception as e:
                return JsonResponse({"status": "error", "message": str(e)}, status=400)
        return JsonResponse({"status": "error", "message": "Method not allowed"}, status=405)

    def map_editor_view(self, request):
        semua_di = DaerahIrigasi.objects.all().prefetch_related('saluran_list__bangunan_list__layanan_list')
        daftar_skema = []

        for di in semua_di:
            mermaid_lines = ["graph TD"] # Memastikan arah Atas ke Bawah
            mermaid_lines.append("  classDef alertKritis fill:#ffcccc,stroke:#e60000,stroke-width:2px;")
            mermaid_lines.append("  classDef normal fill:#ffffff,stroke:#333,stroke-width:1px;")

            q_berjalan = getattr(di, 'debit_awal', 1140.48)
            a_berjalan = di.luas_baku_permen or 990

            for sal in di.saluran_list.all():
                sal_name = sal.nama_saluran.replace('"', '').replace("'", "")
                mermaid_lines.append(f'    S{sal.id}[["SALURAN: {sal_name.upper()}"]]')
                
                bangunans = sal.bangunan_list.all().order_by('id')
                for b in bangunans:
                    detail = b.layanan_list.first()
                    q_diambil = getattr(detail, 'debit_keluar', 0) or 0
                    a_diambil = getattr(detail, 'luas_areal', 0) or 0
                    
                    q_berjalan = round(q_berjalan - q_diambil, 2)
                    a_berjalan = round(a_berjalan - a_diambil, 2)

                    node_id = f"B{b.id}"
                    label_text = f"{b.nomenklatur_ruas} <br/> Q: {q_berjalan} l/d <br/> A: {a_berjalan} ha"
                    
                    status_warna = ":::alertKritis" if q_berjalan < 0 else ":::normal"
                    
                    mermaid_lines.append(f'      {node_id}["{label_text}"]{status_warna}')

                    if b.terhubung_ke:
                        edge_label = f"Q_ambil:{q_diambil}_A:{a_diambil}"
                        mermaid_lines.append(f'      B{b.terhubung_ke_id} -->| {edge_label} | {node_id}')
                    else:
                        mermaid_lines.append(f'      S{sal.id} --> {node_id}')

                    if q_berjalan < 0:
                        msg = f"DEFISIT AIR: {abs(q_berjalan)} l/d! Segera tutup pintu sadap."
                    else:
                        msg = f"Kondisi Aman. Sisa Debit: {q_berjalan} l/d"
                    
                    mermaid_lines.append(f'      click {node_id} call callback("{msg}")')

            daftar_skema.append({
                'nama_di': di.nama_di,
                'chart_code': "\n".join(mermaid_lines)
            })

        context = dict(
            self.admin_site.each_context(request),
            daftar_skema=daftar_skema,
            bangunan_list=Bangunan.objects.all(),
            title="Skema Irigasi Digital",
        )
        return render(request, "admin/bangunan_map_editor.html", context)
        

# ==========================================
# @admin.register(TitikIrigasi)
# class TitikIrigasiAdmin(gis_admin.GISModelAdmin):
#     list_display = ('nama_lokasi', 'surveyor', 'kondisi_umum', 'waktu_input')
#     list_filter = ('kondisi_umum', 'waktu_input')
#     search_fields = ('nama_lokasi', 'surveyor')
#     default_lat = -6.7
#     default_lon = 108.5
#     default_zoom = 12

# admin.py

@admin.register(LayerPendukung)
class LayerPendukungAdmin(admin.ModelAdmin):
    list_display = ('nama', 'kategori', 'aktif', 'tombol_pilih_fungsional')
    readonly_fields = ('tombol_pilih_fungsional',)

    @admin.display(description='Aksi KMZ')
    def tombol_pilih_fungsional(self, obj):
        if obj.pk and obj.file_geojson and obj.file_geojson.name.lower().endswith('.kmz'):
            url = reverse('admin:layer-kmz-selector', args=[obj.pk])
            return format_html(
                '<a class="button" href="{}" style="background-color: #28a745; color: white; padding: 5px 15px; border-radius: 4px;">'
                'Pilih Objek dari KMZ</a>', url
            )
        return mark_safe('<span style="color: gray;">Upload file KMZ & Simpan dahulu</span>')

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('<int:object_id>/pilih-kmz/', self.admin_site.admin_view(self.kmz_selector_view), name='layer-kmz-selector'),
        ]
        return custom_urls + urls

    def kmz_selector_view(self, request, object_id):
        import zipfile
        import xml.etree.ElementTree as ET
        import json
        from django.contrib.gis.geos import Polygon, MultiPolygon, GEOSGeometry
        from django.shortcuts import render
        from django.http import HttpResponseRedirect
        from django.core.files.base import ContentFile
        from .models import DaerahIrigasi

        obj = self.get_object(request, object_id)
        features_found = []

        # --- LANGKAH 1: EKSTRAKSI DATA ---
        if obj.file_geojson and obj.file_geojson.name.lower().endswith('.kmz'):
            try:
                with zipfile.ZipFile(obj.file_geojson.path, 'r') as zf:
                    kml_filename = next((f for f in zf.namelist() if f.endswith('.kml')), 'doc.kml')
                    content = zf.read(kml_filename)
                    root = ET.fromstring(content)
                    ns = {'kml': 'http://www.opengis.net/kml/2.2'}
                    
                    for idx, pm in enumerate(root.findall('.//kml:Placemark', ns)):
                        name_node = pm.find('kml:name', ns)
                        pure_name = name_node.text if name_node is not None else f"Objek {idx}"
                        
                        obj_id_info = ""
                        attr_data = {'luas_fung': 0, 'shape_leng': 0, 'shape_area': 0}

                        extended_data = pm.find('.//kml:ExtendedData', ns)
                        if extended_data is not None:
                            simple_data = extended_data.findall('.//kml:SimpleData', ns)
                            for sd in simple_data:
                                attr_name = sd.get('name', '')
                                val = sd.text if sd.text else "0"

                                if attr_name.upper() in ['OBJECTID', 'ID', 'NAMA_DI', 'NM_INF']:
                                    if attr_name.upper() in ['OBJECTID', 'ID']:
                                        obj_id_info = f" [{val}]"
                                    if attr_name.upper() in ['NAMA_DI', 'NM_INF']:
                                        pure_name = val

                                if attr_name == 'Luas_Fung':
                                    attr_data['luas_fung'] = float(val)
                                elif attr_name == 'Shape_Leng':
                                    attr_data['shape_leng'] = float(val)
                                elif attr_name == 'Shape_Area':
                                    attr_data['shape_area'] = float(val)

                        display_name = f"{pure_name}{obj_id_info}"
                        poly_node = pm.find('.//kml:Polygon', ns)
                        if poly_node is not None:
                            coord_node = poly_node.find('.//kml:coordinates', ns)
                            if coord_node is not None:
                                features_found.append({
                                    'id': len(features_found),
                                    'name': display_name,
                                    'pure_name': pure_name,
                                    'coords': coord_node.text.strip(),
                                    'metadata': attr_data
                                })
            except Exception as e:
                self.message_user(request, f"Gagal membaca file KMZ: {e}", level='ERROR')

        # --- LANGKAH 2: PROSES PENYIMPANAN ---
        if request.method == 'POST':
            selected_indices = request.POST.getlist('selected_features')
            geojson_features = [] # List untuk menampung fitur-fitur pilihan
            
            try:
                for idx_str in selected_indices:
                    idx = int(idx_str)
                    if 0 <= idx < len(features_found):
                        feature = features_found[idx]
                        m = feature['metadata']

                        # 1. Update Luas ke Daerah Irigasi
                        DaerahIrigasi.objects.filter(nama_di__icontains=feature['pure_name'].strip()).update(
                            luas_baku_onemap=m['luas_fung'],
                            luas_fungsional=m['luas_fung']
                        )
                        
                        # 2. Parsing Geometri
                        points = []
                        coords_parts = feature['coords'].split()
                        for p in coords_parts:
                            c = p.split(',')
                            if len(c) >= 2:
                                points.append((float(c[0]), float(c[1])))
                        
                        if len(points) >= 3:
                            if points[0] != points[-1]: points.append(points[0])
                            
                            poly = Polygon(points)
                            if not poly.valid: poly = poly.buffer(0)
                            
                            # 3. Masukkan ke list fitur GeoJSON dengan Properti Lengkap
                            if isinstance(poly, Polygon):
                                geojson_features.append({
                                    "type": "Feature",
                                    "geometry": json.loads(poly.json),
                                    "properties": {
                                        "nama": feature['pure_name'],
                                        "luas_fungsional": m['luas_fung'],
                                        "shape_leng": m['shape_leng'],
                                        "shape_area": m['shape_area']
                                    }
                                })

                if geojson_features:
                    # Buat objek GeoJSON utuh
                    geojson_content = {
                        "type": "FeatureCollection",
                        "features": geojson_features
                    }
                    
                    # Simpan sebagai file baru
                    new_filename = obj.file_geojson.name.replace('.kmz', '_selected.json')
                    obj.file_geojson.save(new_filename, ContentFile(json.dumps(geojson_content)))
                    
                    self.message_user(request, f"Sukses! {len(geojson_features)} poligon disimpan dengan atribut lengkap.")
                    return HttpResponseRedirect("../change/")

            except Exception as e:
                self.message_user(request, f"Gagal memproses geometri: {str(e)}", level='ERROR')

        return render(request, 'admin/kmz_layer_selector.html', {
            'obj': obj,
            'features': features_found,
            'opts': self.model._meta,
        })



# @admin.register(PelaporanAset)
# class PelaporanAsetAdmin(admin.ModelAdmin):
#     list_display = ('daerah_irigasi', 'tahun', 'get_utama', 'get_tersier', 'get_gabungan')
#     readonly_fields = ('luas_fungsional',)
    
#     fieldsets = (
#         ('Informasi Umum', {
#             'fields': ('daerah_irigasi', 'tahun', 'luas_fungsional')
#         }),
#         ('IKSI Jaringan Utama', {
#             'classes': ('wide',),
#             'fields': (
#                 ('utama_prasarana_fisik', 'utama_produktivitas_tanam', 'utama_sarana_penunjang'),
#                 ('utama_organisasi_personalia', 'utama_dokumentasi', 'utama_gp3a_ip3a'),
#             )
#         }),
#         ('IKSI Jaringan Tersier', {
#             'classes': ('wide',),
#             'fields': (
#                 ('tersier_prasarana_fisik', 'tersier_produktivitas_tanam', 'tersier_kondisi_op'),
#                 ('tersier_petugas_pembagi_air', 'tersier_dokumentasi', 'tersier_p3a'),
#             )
#         }),
#     )

#     def get_utama(self, obj): return f"{obj.total_utama():.2f}"
#     get_utama.short_description = 'IKSI Utama'

#     def get_tersier(self, obj): return f"{obj.total_tersier():.2f}"
#     get_tersier.short_description = 'IKSI Tersier'

#     def get_gabungan(self, obj): return f"{obj.total_gabungan():.2f}"
#     get_gabungan.short_description = 'Gabungan'


class RuasIksiInline(admin.TabularInline):
    model = RuasIksiSaluran
    extra = 1 # Bapak bisa tambah baris ruas sebanyak kebutuhan
    fields = ('kode_item', 'nama_ruas_item', 'nilai_kondisi', 'bobot_pengaruh', 'nilai_akhir', 'foto_kondisi')

@admin.register(LaporanIksiSaluran)
class LaporanIksiSaluranAdmin(admin.ModelAdmin):
    list_display = ('saluran', 'tahun', 'total_nilai_iksi')
    search_fields = ('saluran__nama_saluran',)
    inlines = [RuasIksiInline]

