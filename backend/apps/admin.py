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
from django.contrib.sites.models import Site
from django.contrib.auth.models import Group # Jika ingin hide Groups juga
from allauth.socialaccount.models import SocialAccount, SocialApp, SocialToken
from rest_framework.authtoken.models import TokenProxy
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
from django.forms.widgets import ClearableFileInput
from django.forms import Media
Media.js = [
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
] + list(Media.js) if hasattr(Media, 'js') else []


class ImagePreviewWidget(ClearableFileInput):
    def render(self, name, value, attrs=None, renderer=None):
        output = super().render(name, value, attrs, renderer)
        if value and hasattr(value, 'url'):
            preview = f'''
                <div style="margin-bottom: 10px;">
                    <img src="{value.url}" style="max-height: 150px; border-radius: 6px; border: 2px solid #ccc; box-shadow: 0 2px 5px rgba(0,0,0,0.1);"/>
                </div>
            '''
            return mark_safe(preview + output)
        return output
@admin.register(DaerahIrigasi)
class DaerahIrigasiAdmin(admin.ModelAdmin):
    fieldsets = (
        ('Informasi Utama', {
            'fields': ('kode_di', 'nama_di', 'kelompok_di', 'debit_awal', 'is_approved')
        }),
        ('Data Teknis & Sumber Air', {
            'fields': ('bendung', 'sumber_air', 'luas_baku_permen', 'luas_baku_onemap', 'luas_potensial')
        }),
        ('Statistik Jaringan Primer (Otomatis)', {
            'fields': (('primer_baik', 'primer_rr', 'primer_rb', 'primer_bap'), 'panjang_primer'),
            'description': 'Nilai ini dihitung otomatis dari detail layanan bangunan'
        }),
        ('Statistik Jaringan Sekunder (Otomatis)', {
            'fields': (('sekunder_baik', 'sekunder_rr', 'sekunder_rb', 'sekunder_bap'), 'panjang_sekunder'),
        }),
        ('Statistik Jaringan Tersier (Otomatis)', {
            'fields': (('tersier_baik', 'tersier_rr', 'tersier_rb', 'tersier_bap'), 'panjang_tersier'),
        }),
        ('Statistik Pintu & Luas', {
            'fields': (('pintu_baik', 'pintu_rr', 'pintu_rb'), 'jumlah_pintu', 'total_luas_fungsional'),
        }),
        ('Data Spasial', {
            'fields': ('geojson', 'path_koordinat'),
        }),
    )
    list_display = ('nama_di', 'kode_di', 'luas_baku_permen', 'luas_baku_onemap', 'luas_fungsional', 'luas_potensial' ,'is_approved')
    
    list_filter = ('kelompok_di', 'is_approved')
    search_fields = ('nama_di', 'kode_di')
    readonly_fields = (
        'primer_baik', 'primer_rr', 'primer_rb', 'primer_bap', 'panjang_primer',
        'sekunder_baik', 'sekunder_rr', 'sekunder_rb', 'sekunder_bap', 'panjang_sekunder',
        'tersier_baik', 'tersier_rr', 'tersier_rb', 'tersier_bap', 'panjang_tersier',
        'pintu_baik', 'pintu_rr', 'pintu_rb', 'jumlah_pintu', 'total_luas_fungsional'
    )
    
    actions = ['approve_di', 'force_update_stats']

    def force_update_stats(self, request, queryset):
        count = 0
        for di in queryset:
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

class PaiSaluranInline(admin.StackedInline):
    model = Paisaluran
    can_delete = False
    extra = 0
    classes = ('collapse',)
    verbose_name = "Informasi PAI (Pengelolaan Aset Irigasi)"
    fieldsets = (
        ('Identitas Aset', {'fields': (('jenis_aset_kode', 'nama_aset', 'nomenklatur'), ('bangunan_hulu', 'bangunan_hilir'))}),
        ('Kapasitas & Pintu', {'fields': (('luas_layanan_ha', 'q_desain', 'panjang_saluran_m'), ('pintu_jumlah', 'pintu_lebar_m', 'pintu_tinggi_m'))}),
    )

class LaporanIksiInline(admin.TabularInline):
    model = LaporanIksiSaluran
    extra = 0
    classes = ('collapse',)
    fields = ('tahun', 'total_nilai_iksi') 
    readonly_fields = ('total_nilai_iksi',) 
    verbose_name = "Riwayat IKSI"
    verbose_name_plural = "Riwayat Kondisi IKSI (Per Tahun)"


class DetailSegmenForm(forms.ModelForm):
    class Meta:
        model = DetailSegmenSaluran
        fields = '__all__'
        widgets = {
            'geom': LeafletWidget(), 
            'foto_admin': ImagePreviewWidget(),
            'foto_admin_2': ImagePreviewWidget(),
            'foto_admin_3': ImagePreviewWidget(),
            'foto_admin_4': ImagePreviewWidget(),
            'foto_admin_5': ImagePreviewWidget(),
        }



class DetailSegmenInline(admin.StackedInline):
    model = DetailSegmenSaluran
    form = DetailSegmenForm
    extra = 0
    classes = ('collapse',)
    fields = (
        'kondisi', 'panjang', 'titik_awal', 'titik_akhir', 'geom', 
        'foto_admin', 'foto_admin_2', 'foto_admin_3', 'foto_admin_4', 'foto_admin_5',
        'display_foto_segmen', 'keterangan'
    )
    readonly_fields = ('display_foto_segmen',)
    classes = ('collapse',)

    

    verbose_name = "Detail Ruas Per Segmen Kondisi"
    verbose_name_plural = "DAFTAR SEGMEN KONDISI"

    @admin.display(description='Preview Foto (Web & Mobile)')
    def display_foto_segmen(self, obj):
        import json
        html_output = '<div style="display: flex; gap: 10px; flex-wrap: wrap;">'
        found_any = False
        foto_fields = [
            obj.foto_admin, getattr(obj, 'foto_admin_2', None), 
            getattr(obj, 'foto_admin_3', None), getattr(obj, 'foto_admin_4', None), getattr(obj, 'foto_admin_5', None)
        ]
        
        for idx, foto in enumerate(foto_fields, start=1):
            if foto and hasattr(foto, 'url'):
                found_any = True
                html_output += f'''
                    <div style="text-align:center;">
                        <img src="{foto.url}" style="height: 80px; width: 120px; object-fit: cover; border: 2px solid #28a745; border-radius: 4px;"/>
                        <br/><small style="color:#28a745; font-weight:bold;">Admin {idx}</small>
                    </div>
                '''
        if obj.foto and obj.foto not in ["[]", "null", ""]:
            try:
                paths = obj.foto.replace('[', '').replace(']', '').replace('"', '').replace("'", "").split(',')
                
                mob_idx = 1
                for path in paths:
                    path = path.strip()
                    if path and not path.startswith('/data/user/'):
                        found_any = True
                        full_url = f"/media/{path}" if not path.startswith(('http', '/media/')) else path
                        html_output += f'''
                            <div style="text-align:center;">
                                <img src="{full_url}" style="height: 80px; width: 120px; object-fit: cover; border: 2px solid #007bff; border-radius: 4px;"/>
                                <br/><small style="color:#007bff; font-weight:bold;">Mobile {mob_idx}</small>
                            </div>
                        '''
                        mob_idx += 1
            except Exception as e:
                pass
                
        html_output += '</div>'
        if not found_any:
            return mark_safe('<span style="color: #ff9800; font-style: italic; font-size: 0.85rem;">Tidak ada foto (Atau foto belum di-sync dari HP surveyor)</span>')
            
        return mark_safe(html_output)


    def get_formset(self, request, obj=None, **kwargs):
        formset = super().get_formset(request, obj, **kwargs)
        return formset

    

from leaflet.admin import LeafletGeoAdminMixin
from leaflet.forms.widgets import LeafletWidget



@admin.register(Saluran)
class SaluranAdmin(LeafletGeoAdminMixin, admin.ModelAdmin):
    list_per_page = 10
    change_form_template = "admin/saluran_change_form.html"
    settings_overrides = {
        'DEFAULT_CENTER': (-6.826, 108.604),
        'DEFAULT_ZOOM': 18,
        'MAX_ZOOM': 21,
    }
    search_fields = ('nama_saluran', 'surveyor')
    actions = ['approve_saluran']

    inlines = [DetailSegmenInline, PaiSaluranInline, LaporanIksiInline]

    list_display = (
        'nama_saluran', 
        'kode_aset_saluran',
        'daerah_irigasi', 
        'surveyor', 
        'tingkat_jaringan',    
        'get_panjang_format', 
        'is_approved',   
        'lebar_saluran', 'tinggi_saluran',
    )
    
    
    fieldsets = (
        ('Informasi Utama', {
            'fields': ('nama_saluran', 'kode_aset_saluran', 'daerah_irigasi', 'surveyor', 'tingkat_jaringan', 'is_approved')
        }),
        ('Data Geospasial', {
            'fields': ('panjang_saluran', 'lebar_saluran', 'tinggi_saluran', 'geom', 'geojson', 'tombol_pilih_kmz')
        }),
        ('Rekap Kondisi (Meter)', {
            'fields': (
                ('panjang_baik', 'panjang_rr', 'panjang_rb', 'panjang_bap'),
            )
        }),
    )

    
    readonly_fields = (
        'display_foto_baik', 
        'display_foto_rr', 
        'display_foto_rb', 
        'display_foto_bap',
    )
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
            clean_data = json_photo_data.replace("'", '"')
            import json
            photo_list = json.loads(clean_data) if clean_data.startswith('[') else [clean_data]
            
            html_output = '<div style="display: flex; flex-wrap: wrap; gap: 10px;">'
            found = False
            
            for path in photo_list:
                if not path or path.startswith('/data/user/'): 
                    continue
                    
                found = True
                url = f"/media/{path}" if not path.startswith(('/media/', 'http')) else path
                html_output += f'''
                    <div style="text-align:center;">
                        <img src="{url}" style="height: 100px; border-radius: 8px; border: 1px solid #ccc; box-shadow: 0 2px 4px rgba(0,0,0,0.1);"/>
                    </div>
                '''
            html_output += '</div>'
            
            if not found:
                return mark_safe('<div style="color:#ff9800; font-size:12px; font-style:italic;">Foto ada di memori HP, namun belum berhasil di-upload ke server.</div>')
                
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
                            all_lines.append(line)
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
        if obj and obj.geom:
            extra_context['parent_saluran_geojson'] = obj.geom.json
        else:
            extra_context['parent_saluran_geojson'] = 'null'
            
        return super().change_view(request, object_id, form_url, extra_context=extra_context)
    

    def save_model(self, request, obj, form, change):
        panjang_diedit_manual = 'panjang_saluran' in form.changed_data
        
        if obj.geom:
            peta_diubah = 'geom' in form.changed_data
            if (peta_diubah and not panjang_diedit_manual) or not obj.panjang_saluran:
                try:
                    obj.panjang_saluran = round(obj.geom.transform(32749, clone=True).length, 2)
                except:
                    obj.panjang_saluran = round(obj.geom.length * 111320, 2)
        super().save_model(request, obj, form, change)


    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        
        obj = form.instance
        panjang_saluran_asli = form.cleaned_data.get('panjang_saluran')
        if hasattr(obj, 'refresh_summary'):
            obj.refresh_summary()
        if panjang_saluran_asli and panjang_saluran_asli > 0:
            obj.panjang_saluran = panjang_saluran_asli
        total_rusak = (obj.panjang_rr or 0) + (obj.panjang_rb or 0) + (obj.panjang_bap or 0)
        
        if obj.panjang_saluran >= total_rusak:
            sisa_baik = obj.panjang_saluran - total_rusak
            obj.panjang_baik = round(sisa_baik, 2)
        else:
            obj.panjang_saluran = round(total_rusak, 2)
            obj.panjang_baik = 0
        obj.save(update_fields=['panjang_baik', 'panjang_saluran'])
        if obj.is_approved and obj.daerah_irigasi:
            obj.daerah_irigasi.update_totals()

@admin.register(JenisPintu)
class JenisPintuAdmin(admin.ModelAdmin):
    search_fields = ['nama']


class UnitPintuInline(nested_admin.NestedTabularInline):
    model = UnitPintuBangunan
    extra = 0 
    fields = ('nama_pintu', 'jenis_pintu', 'kondisi', 'lebar_pintu', 'tinggi_pintu', 'foto_pintu')

class DetailLayananForm(forms.ModelForm):
    class Meta:
        model = DetailLayananBangunan
        fields = '__all__'
        widgets = {
            'foto_aset': ImagePreviewWidget(),
            'foto_aset_2': ImagePreviewWidget(),
            'foto_aset_3': ImagePreviewWidget(),
            'foto_aset_4': ImagePreviewWidget(),
            'foto_aset_5': ImagePreviewWidget(),
        }

class DetailLayananInline(nested_admin.NestedStackedInline):
    model = DetailLayananBangunan
    form = DetailLayananForm
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

        foto_admin_fields = [
            obj.foto_aset, 
            getattr(obj, 'foto_aset_2', None),
            getattr(obj, 'foto_aset_3', None),
            getattr(obj, 'foto_aset_4', None),
            getattr(obj, 'foto_aset_5', None)
        ]
        
        for idx, foto in enumerate(foto_admin_fields, start=1):
            if foto:
                found_any = True
                html_output += format_html(
                    '<div style="text-align:center;">'
                    '<img src="{}" style="height: 120px; border-radius: 8px; border: 2px solid #417690;"/>'
                    '<br/><small style="color:#417690; font-weight:bold;">Upload Admin {}</small></div>',
                    foto.url, idx
                )
        
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
                ('luas_areal', 'poligon_layanan'), 
                'foto_aset', 'foto_aset_2', 'foto_aset_3', 'foto_aset_4', 'foto_aset_5',
                'display_foto_galeri'
            )
        }),
        ('Data Percabangan & Kelanjutan', {
            'fields': (
                ('jenis_saluran_kiri', 'nomenklatur_kiri', 'luas_kiri'),
                ('jenis_saluran_tengah', 'nomenklatur_tengah', 'luas_tengah'),
                ('jenis_saluran_kanan', 'nomenklatur_kanan', 'luas_kanan'),
                ('jumlah_cabang_sekunder', 'jumlah_cabang_tersier'),
                'is_saluran_berlanjut',
            ),
            'description': 'Tentukan jenis saluran, nama, dan luas layanan untuk masing-masing sisi.'
        }),
        ('Data Teknis Lainnya', {
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
    list_per_page = 10
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
    
    get_induk.short_description = 'Terikat Pada (Klik untuk Cek Update)'
    fieldsets = (
        ('Informasi Utama', {
            'fields': (('daerah_irigasi', 'saluran'), 'nomenklatur_ruas')
        }),
        ('Skema Jaringan (Relasi Hulu-Hilir)', {
            'fields': (('terhubung_ke', 'panjang_saluran_antar_ruas'),),
            'description': 'Tentukan hulu dari bangunan ini agar sistem dapat menggambar alur flowchart secara otomatis.'
        }),
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
                    file_data = layer.file_geojson.read().decode('utf-8')
                    geo_json = json.loads(file_data)
                    if 'features' in geo_json and len(geo_json['features']) > 0:
                        props = geo_json['features'][0].get('properties', {})
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
        from django.contrib.gis.geos import Polygon, MultiPolygon
        from django.shortcuts import render
        from django.http import HttpResponseRedirect
        from django.core.files.base import ContentFile
        from .models import DaerahIrigasi

        obj = self.get_object(request, object_id)
        features_found = []
        if obj.file_geojson and obj.file_geojson.name.lower().endswith('.kmz'):
            try:
                with zipfile.ZipFile(obj.file_geojson.path, 'r') as zf:
                    kml_filename = next((f for f in zf.namelist() if f.endswith('.kml')), 'doc.kml')
                    content = zf.read(kml_filename)
                    root = ET.fromstring(content)
                    ns = {'kml': 'http://www.opengis.net/kml/2.2'}
                    
                    all_coords_list = []
                    attr_data = {'luas_fung': 0, 'shape_leng': 0, 'shape_area': 0}
                    for pm in root.findall('.//kml:Placemark', ns):
                        extended_data = pm.find('.//kml:ExtendedData', ns)
                        if extended_data is not None:
                            for sd in extended_data.findall('.//kml:SimpleData', ns):
                                attr_name = sd.get('name', '')
                                val = sd.text if sd.text else "0"
                                if attr_name == 'Luas_Fung': attr_data['luas_fung'] = float(val)
                                elif attr_name == 'Shape_Leng': attr_data['shape_leng'] = float(val)
                                elif attr_name == 'Shape_Area': attr_data['shape_area'] = float(val)
                        for poly_node in pm.findall('.//kml:Polygon', ns):
                            coord_node = poly_node.find('.//kml:coordinates', ns)
                            if coord_node is not None:
                                all_coords_list.append(coord_node.text.strip())
                    if all_coords_list:
                        features_found.append({
                            'id': 0,
                            'name': f"Gabungan Seluruh Poligon ({len(all_coords_list)} potongan area)",
                            'pure_name': obj.nama, # Gunakan nama dari Admin (misal: BTkl. 4)
                            'coords_list': all_coords_list,
                            'metadata': attr_data
                        })
            except Exception as e:
                self.message_user(request, f"Gagal membaca file KMZ: {e}", level='ERROR')
        if request.method == 'POST':
            selected_indices = request.POST.getlist('selected_features')
            geojson_features = []
            
            try:
                for idx_str in selected_indices:
                    idx = int(idx_str)
                    if 0 <= idx < len(features_found):
                        feature = features_found[idx]
                        m = feature['metadata']
                        polygons = []
                        for coord_string in feature['coords_list']:
                            points = []
                            coords_parts = coord_string.split()
                            for p in coords_parts:
                                c = p.split(',')
                                if len(c) >= 2:
                                    points.append((float(c[0]), float(c[1])))
                            
                            if len(points) >= 3:
                                if points[0] != points[-1]: points.append(points[0])
                                poly = Polygon(points)
                                if not poly.valid: poly = poly.buffer(0)
                                polygons.append(poly)
                        if polygons:
                            multi_poly = MultiPolygon(polygons)
                            geojson_features.append({
                                "type": "Feature",
                                "geometry": json.loads(multi_poly.json),
                                "properties": {
                                    "nama_di": feature['pure_name'], 
                                    "nama": feature['pure_name'],
                                    "luas_fungsional": m['luas_fung'],
                                    "shape_leng": m['shape_leng'],
                                    "shape_area": m['shape_area']
                                }
                            })

                if geojson_features:
                    geojson_content = {
                        "type": "FeatureCollection",
                        "features": geojson_features
                    }
                    
                    new_filename = obj.file_geojson.name.replace('.kmz', '_selected.json')
                    obj.file_geojson.save(new_filename, ContentFile(json.dumps(geojson_content)))
                    
                    self.message_user(request, f"Sukses! {len(polygons)} potongan area digabungkan menjadi 1 kesatuan.")
                    return HttpResponseRedirect("../change/")

            except Exception as e:
                self.message_user(request, f"Gagal memproses geometri: {str(e)}", level='ERROR')

        return render(request, 'admin/kmz_layer_selector.html', {
            'obj': obj,
            'features': features_found,
            'opts': self.model._meta,
        })


class RuasIksiInline(admin.TabularInline):
    model = RuasIksiSaluran
    fields = ('kode_item', 'nama_ruas_item', 'nilai_kondisi', 'bobot_pengaruh', 'nilai_akhir', 'foto_kondisi')

@admin.register(LaporanIksiSaluran)
class LaporanIksiSaluranAdmin(admin.ModelAdmin):
    list_display = ('saluran', 'tahun', 'total_nilai_iksi')
    search_fields = ('saluran__nama_saluran',)
    inlines = [RuasIksiInline]

admin.site.unregister(Site)
admin.site.unregister(SocialAccount)
admin.site.unregister(SocialApp)
admin.site.unregister(SocialToken)
admin.site.unregister(TokenProxy)
admin.site.unregister(Group)

from django.contrib.auth.models import User
admin.site._registry[User].model._meta.verbose_name_plural = "1. MANAJEMEN SUPERUSER"

from django.apps import apps


try:
    apps.get_app_config('account').verbose_name = "3. MANAJEMEN AKUN & EMAIL"
except LookupError:

    try:
        apps.get_app_config('allauth').verbose_name = "3. MANAJEMEN AKUN & EMAIL"
    except LookupError:
        pass


try:
    apps.get_app_config('auth').verbose_name = "2. PENGATURAN HAK AKSES"
except LookupError:
    pass

from allauth.account.models import EmailAddress

EmailAddress._meta.verbose_name = "Email User"
EmailAddress._meta.verbose_name_plural = "1. MANAJEMEN USER"