from django.contrib.gis.db import models as gis_models
from django.contrib.gis.geos import LineString, MultiLineString, GEOSGeometry, MultiPolygon, Polygon
from django.db import models
from django.db.models import Sum, Q
import json
from geopy.geocoders import Nominatim, ArcGIS

KODE_SALURAN_MASTER = [
    ('S01', 'S01 - Saluran Primer'),
    ('S02', 'S02 - Saluran Sekunder'),
    ('S03', 'S03 - Saluran Suplesi'),
    ('S04', 'S04 - Saluran Muka'),
    ('S11', 'S11 - Saluran Pembuang'),
    ('S12', 'S12 - Saluran Gendong'),
    ('S13', 'S13 - Saluran Pengelak Banjir'),
    ('S15', 'S15 - Saluran Tersier'),
    ('S16', 'S16 - Saluran Kuarter'),
    ('S17', 'S17 - Saluran Pembuang (Tersier)'),
    ('P99', 'P99 - Saluran Lain-lain'),
]

KODE_BANGUNAN_MASTER = [
    ('B01', 'B01 - Bendung'),
    ('B02', 'B02 - Bendung Gerak'),
    ('B03', 'B03 - Pengambilan Bebas'),
    ('B04', 'B04 - Pompa Hidrolik'),
    ('B06', 'B06 - Bendungan'),
    ('B07', 'B07 - Pompa Elektrik'),
    ('B99', 'B99 - Pangkal Saluran (Tanpa Bangunan)'),
    ('C01', 'C01 - Pengukur Debit'),
    ('C02', 'C02 - Siphon'),
    ('C03', 'C03 - Gorong-gorong'),
    ('C04', 'C04 - Talang'),
    ('C05', 'C05 - Kantong Lumpur'),
    ('C06', 'C06 - Jembatan'),
    ('C07', 'C07 - Terjunan'),
    ('C08', 'C08 - Pelimpah Samping'),
    ('C09', 'C09 - Tempat Cuci'),
    ('C10', 'C10 - Tempat Mandi Hewan'),
    ('C11', 'C11 - Got Miring'),
    ('C12', 'C12 - Gorong-gorong Silang'),
    ('C13', 'C13 - Pelimpah Corong'),
    ('C14', 'C14 - Pintu Pembuang'),
    ('C15', 'C15 - Oncoran'),
    ('C16', 'C16 - Bangunan Inlet'),
    ('C17', 'C17 - Terowongan'),
    ('C18', 'C18 - Cross Drain'),
    ('C19', 'C19 - Pintu Klep'),
    ('C20', 'C20 - Outlet'),
    ('C21', 'C21 - Krib'),
    ('C22', 'C22 - Tanggul'),
    ('P01', 'P01 - Bagi'),
    ('P02', 'P02 - Bagi Sadap'),
    ('P03', 'P03 - Sadap'),
    ('P04', 'P04 - Sadap Langsung'),
    ('P11', 'P11 - Bangunan Pertemuan'),
    ('P21', 'P21 - Box Tersier'),
    ('P22', 'P22 - Box Kuarter'),
    ('P99', 'P99 - Ujung Saluran (Tanpa Bangunan)'),
]

class TitikIrigasi(models.Model):
    nama_lokasi = models.CharField(max_length=100)
    surveyor = models.CharField(max_length=100, blank=True, null=True)
    kondisi_umum = models.CharField(max_length=50, blank=True, null=True)
    keterangan = models.TextField()
    koordinat = gis_models.PointField(srid=4326)
    foto = models.ImageField(upload_to='foto_irigasi/')
    waktu_input = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nama_lokasi} - {self.surveyor}"

class DaerahIrigasi(models.Model):
    kode_di = models.CharField(max_length=50, unique=True)
    nama_di = models.CharField(max_length=255)
    bendung = models.CharField(max_length=255)
    sumber_air = models.CharField(max_length=255)
    luas_baku_permen = models.FloatField(default=0, verbose_name="Luas Baku Permen PU No. 14/2015 (Ha)")
    luas_baku_onemap = models.FloatField(default=0, verbose_name="Luas Baku OneMap (Ha)")
    luas_fungsional = models.FloatField(default=0, verbose_name="Luas Fungsional (Ha)")
    luas_potensial = models.FloatField(default=0, verbose_name="Luas Potensial (Ha)")
    path_koordinat = models.TextField(help_text="Data koordinat tracking", null=True, blank=True)
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    debit_awal = models.FloatField(default=0, verbose_name="Debit Awal Bendung (l/dt)")

    KELOMPOK_DI_CHOICES = [
        ('1', 'Kelompok 1 (> 1000 ha) - Bobot Utama 80%:Tersier 20%'),
        ('2', 'Kelompok 2 (150 - 1000 ha) - Bobot Utama 60%:Tersier 40%'),
        ('3', 'Kelompok 3 (< 150 ha) - Bobot Utama 50%:Tersier 50%'),
    ]
    kelompok_di = models.CharField(max_length=1, choices=KELOMPOK_DI_CHOICES, default='3')

    # Statistik Jaringan PRIMER (Otomatis)
    primer_baik = models.FloatField(default=0, verbose_name="Primer Baik (m)")
    primer_rr = models.FloatField(default=0, verbose_name="Primer Rusak Ringan (m)")
    primer_rb = models.FloatField(default=0, verbose_name="Primer Rusak Berat (m)")
    primer_bap = models.FloatField(default=0, verbose_name="Primer Belum Ada Pasangan (m)")
    panjang_primer = models.FloatField(default=0, verbose_name="Total Panjang Primer (m)")

    # Statistik Jaringan SEKUNDER (Otomatis)
    sekunder_baik = models.FloatField(default=0, verbose_name="Sekunder Baik (m)")
    sekunder_rr = models.FloatField(default=0, verbose_name="Sekunder Rusak Ringan (m)")
    sekunder_rb = models.FloatField(default=0, verbose_name="Sekunder Rusak Berat (m)")
    sekunder_bap = models.FloatField(default=0, verbose_name="Sekunder Belum Ada Pasangan (m)")
    panjang_sekunder = models.FloatField(default=0, verbose_name="Total Panjang Sekunder (m)")

    # Statistik PINTU (Otomatis)
    pintu_baik = models.IntegerField(default=0, verbose_name="Pintu Baik")
    pintu_rr = models.IntegerField(default=0, verbose_name="Pintu Rusak Ringan")
    pintu_rb = models.IntegerField(default=0, verbose_name="Pintu Rusak Berat")
    jumlah_pintu = models.IntegerField(default=0, verbose_name="Total Jumlah Pintu")

    tersier_baik = models.FloatField(default=0, verbose_name="Tersier Baik (m)")
    tersier_rr = models.FloatField(default=0, verbose_name="Tersier Rusak Ringan (m)")
    tersier_rb = models.FloatField(default=0, verbose_name="Tersier Rusak Berat (m)")
    tersier_bap = models.FloatField(default=0, verbose_name="Tersier Belum Ada Pasangan (m)")
    panjang_tersier = models.FloatField(default=0, verbose_name="Total Panjang Tersier (m)")

    # 2. Field Otomatis (Akan di-set Read Only di Admin)
    total_luas_fungsional = models.FloatField(default=0, verbose_name="Total Luas Fungsional (Ha)")
    total_panjang_jaringan = models.FloatField(default=0, verbose_name="Total Panjang Jaringan (m)")

    geojson = models.FileField(upload_to='geojson/di/', null=True, blank=True)

    def update_totals(self):
        from django.db.models import Q, Sum, Count
        
        # 1. Jalur Kabel: Cari semua detail yang terhubung ke DI ini 
        qs_detail = DetailLayananBangunan.objects.filter(
            Q(bangunan__saluran__daerah_irigasi=self) | 
            Q(bangunan__daerah_irigasi=self)
        ).distinct()

        # --- HITUNG LUAS ---
        total_luas = qs_detail.aggregate(Sum('luas_areal'))['luas_areal__sum'] or 0
        self.luas_fungsional = total_luas
        self.total_luas_fungsional = total_luas

        # --- HITUNG PINTU ---
        manual_pintu = qs_detail.aggregate(
            baik=Sum('pintu_baik'),
            rr=Sum('pintu_rusak_ringan'),
            rb=Sum('pintu_rusak_berat')
        )

        inline_pintu = UnitPintuBangunan.objects.filter(detail_layanan__in=qs_detail).aggregate(
            baik=Count('id', filter=Q(kondisi='BAIK')),
            rr=Count('id', filter=Q(kondisi='RR')),
            rb=Count('id', filter=Q(kondisi='RB'))
        )

        self.pintu_baik = (manual_pintu['baik'] or 0) + (inline_pintu['baik'] or 0)
        self.pintu_rr = (manual_pintu['rr'] or 0) + (inline_pintu['rr'] or 0)
        self.pintu_rb = (manual_pintu['rb'] or 0) + (inline_pintu['rb'] or 0)
        self.jumlah_pintu = self.pintu_baik + self.pintu_rr + self.pintu_rb

        # --- HITUNG SALURAN ---
        salurans = Saluran.objects.filter(daerah_irigasi=self)

        primers = salurans.filter(kode_aset_saluran='S01')
        self.primer_baik = round(sum(s.panjang_baik for s in primers), 2)
        self.primer_rr = round(sum(s.panjang_rr for s in primers), 2)
        self.primer_rb = round(sum(s.panjang_rb for s in primers), 2)
        self.primer_bap = round(sum(s.panjang_bap for s in primers) if hasattr(primers.first(), 'panjang_bap') else 0, 2)
        self.panjang_primer = self.primer_baik + self.primer_rr + self.primer_rb + self.primer_bap
        
        sekunders = salurans.filter(kode_aset_saluran='S02')
        self.sekunder_baik = round(sum(s.panjang_baik for s in sekunders), 2)
        self.sekunder_rr = round(sum(s.panjang_rr for s in sekunders), 2)
        self.sekunder_rb = round(sum(s.panjang_rb for s in sekunders), 2)
        self.sekunder_bap = round(sum(s.panjang_bap for s in sekunders) if hasattr(sekunders.first(), 'panjang_bap') else 0, 2)
        self.panjang_sekunder = self.sekunder_baik + self.sekunder_rr + self.sekunder_rb + self.sekunder_bap

        tersiers = salurans.filter(kode_aset_saluran='S15')
        self.tersier_baik = round(sum(s.panjang_baik for s in tersiers), 2)
        self.tersier_rr = round(sum(s.panjang_rr for s in tersiers), 2)
        self.tersier_rb = round(sum(s.panjang_rb for s in tersiers), 2)
        self.tersier_bap = round(sum(s.panjang_bap for s in tersiers) if hasattr(tersiers.first(), 'panjang_bap') else 0, 2)
        self.panjang_tersier = self.tersier_baik + self.tersier_rr + self.tersier_rb + self.tersier_bap

        # --- UPDATE DATABASE ---
        DaerahIrigasi.objects.filter(pk=self.pk).update(
            luas_fungsional=self.luas_fungsional,
            total_luas_fungsional=self.total_luas_fungsional,
            primer_baik=self.primer_baik, primer_rr=self.primer_rr, 
            primer_rb=self.primer_rb, primer_bap=self.primer_bap,
            panjang_primer=self.panjang_primer,
            sekunder_baik=self.sekunder_baik, sekunder_rr=self.sekunder_rr,
            sekunder_rb=self.sekunder_rb, sekunder_bap=self.sekunder_bap,
            panjang_sekunder=self.panjang_sekunder,
            tersier_baik=self.tersier_baik, tersier_rr=self.tersier_rr,
            tersier_rb=self.tersier_rb, tersier_bap=self.tersier_bap,
            panjang_tersier=self.panjang_tersier,
            pintu_baik=self.pintu_baik, pintu_rr=self.pintu_rr,
            pintu_rb=self.pintu_rb, jumlah_pintu=self.jumlah_pintu
        )
        self.save()

    def save(self, *args, **kwargs):
        # =======================================================
        # 1. LOGIKA EKSTRAK KOORDINAT DARI GEOJSON SAJA
        # (TIDAK ADA LOGIKA LATITUDE, LONGITUDE, DESA, ATAU KECAMATAN DI SINI)
        # =======================================================
        if self.geojson:
            try:
                # Buka dan baca file
                content = self.geojson.open('r')
                raw_data = content.read()
                
                # Cek jika file kosong
                if not raw_data:
                    print("File GeoJSON kosong!")
                else:
                    data = json.loads(raw_data)
                    content.seek(0) 

                    # Cek struktur GeoJSON
                    features = data.get('features', [])
                    if features:
                        geom = features[0].get('geometry', {})
                        coords = geom.get('coordinates', [])
                        g_type = geom.get('type')

                        lon, lat = None, None

                        if g_type == 'Point':
                            lon, lat = coords
                        elif g_type == 'LineString':
                            lon, lat = coords[0]
                        elif g_type == 'Polygon':
                            # Polygon: [[[lng, lat], [lng, lat]]]
                            lon, lat = coords[0][0]
                        elif g_type == 'MultiPolygon':
                            # MultiPolygon: [[[[lng, lat]]]]
                            lon, lat = coords[0][0][0]

                        # Update jika koordinat ditemukan
                        if lat and lon:
                            self.path_koordinat = f"{lat},{lon}"
                            print(f"Berhasil ekstrak GeoJSON D.I! Lat: {lat}, Lon: {lon}")
                        else:
                            print("Koordinat tidak ditemukan di dalam struktur geometry.")
                    else:
                        print("Format GeoJSON tidak memiliki 'features'.")

            except Exception as e:
                print(f"Error Ekstrak GeoJSON Detail: {str(e)}")

        # =======================================================
        # 2. LANJUTKAN PROSES SAVE KE DATABASE
        # =======================================================
        super().save(*args, **kwargs)

    class Meta:
        verbose_name = "Data Daerah Irigasi"
        verbose_name_plural = "1. DATA DAERAH IRIGASI"


    def to_json(self):
        # Mengambil semua field DI dan daftar salurannya dalam bentuk JSON
        from .serializers import DaerahIrigasiSerializer
        serializer = DaerahIrigasiSerializer(self)
        return json.dumps(serializer.data)
    
    def __str__(self):
        return self.nama_di


class Saluran(models.Model):
    daerah_irigasi = models.ForeignKey(DaerahIrigasi, on_delete=models.CASCADE, related_name='saluran_list')
    nama_saluran = models.CharField(max_length=255)
    surveyor = models.CharField(max_length=100, blank=True, null=True, verbose_name="Surveyor")
    is_approved = models.BooleanField(default=False)
    kode_aset_saluran = models.CharField(
        max_length=50, 
        choices=KODE_SALURAN_MASTER, 
        default='S01'
    )

    geojson = models.FileField(
        upload_to='geojson/saluran/', 
        null=True, 
        blank=True, 
        verbose_name="File Spasial (KMZ/GeoJSON)"
    )
    geom = gis_models.MultiLineStringField(srid=4326, null=True, blank=True)
    areal_fungsional = models.FloatField(default=0)
    panjang_saluran = models.FloatField(default=0)
    lebar_saluran = models.FloatField(default=0, verbose_name="Lebar Saluran (m)")
    tinggi_saluran = models.FloatField(default=0, verbose_name="Tinggi Saluran (m)")
    tingkat_jaringan = models.CharField(max_length=50, choices=[('Teknis', 'Teknis')], default='Teknis')
    kewenangan = models.CharField(max_length=100, default="Kabupaten")
    kondisi_aset = models.CharField(max_length=50, default='BAIK')
    path_koordinat = gis_models.MultiLineStringField(null=True, blank=True, srid=4326)
    keterangan = models.TextField(blank=True, null=True)

    panjang_baik = models.FloatField(
        verbose_name="Panjang Saluran Kondisi Baik", 
        default=0,
        help_text="Total panjang kondisi Baik (m)"
    )
    panjang_rr = models.FloatField(
        verbose_name="Panjang Saluran Kondisi Rusak Ringan", 
        default=0,
    )
    panjang_rb = models.FloatField(
        verbose_name="Panjang Saluran Kondisi Rusak Berat", 
        default=0,
        help_text="Total panjang kondisi Rusak Berat (m)"
    )

    panjang_bap = models.FloatField(
        verbose_name="Panjang Belum Ada Pasangan", 
        default=0,
        help_text="Total panjang kondisi belum ada pasangan (m)"
    )

    keterangan_baik = models.TextField(verbose_name="Keterangan Saluran Baik", null=True, blank=True)
    keterangan_rr = models.TextField(verbose_name="Keterangan Saluran Rusak Ringan", null=True, blank=True)
    keterangan_rb = models.TextField(verbose_name="Keterangan Saluran Rusak Berat", null=True, blank=True)
    keterangan_bap = models.TextField(verbose_name="Keterangan Saluran Belum Ada Pasangan", null=True, blank=True)

    foto_baik = models.TextField(verbose_name="Dokumentasi Saluran Baik", blank=True, null=True)
    foto_rr = models.TextField(verbose_name="Dokumentasi Saluran Rusak Ringan", blank=True, null=True)
    foto_rb = models.TextField(verbose_name="Dokumentasi Saluran Rusak Berat", blank=True, null=True)
    foto_bap = models.TextField(verbose_name="Dokumentasi Belum Ada Pasangan", blank=True, null=True)
    
    path_kondisi = models.TextField(null=True, blank=True)

    STATUS_KINERJA = [
        ('B', 'Baik'),
        ('RR', 'Rusak Ringan'),
        ('RS', 'Rusak Sedang'),
        ('RB', 'Rusak Berat'),
        ('RT', 'Rusak Total'),
    ]
    kinerja_individu = models.CharField(max_length=2, choices=STATUS_KINERJA, default='B')

    @property
    def get_latest_iksi(self):
        laporan = self.laporan_iksi.first()
        return laporan.total_nilai_iksi if laporan else 0

    @property
    def get_tkr(self):
        return 100 - self.get_latest_iksi

    def refresh_summary(self):
        semua_segmen = self.segments.all()
        
        p_rr = semua_segmen.filter(kondisi='RR').aggregate(Sum('panjang'))['panjang__sum'] or 0
        p_rb = semua_segmen.filter(kondisi='RB').aggregate(Sum('panjang'))['panjang__sum'] or 0
        p_bap = semua_segmen.filter(kondisi='BAP').aggregate(Sum('panjang'))['panjang__sum'] or 0
        
        total_rusak = round(p_rr + p_rb + p_bap, 2)

        if self.panjang_saluran > 0:
            if self.panjang_saluran >= total_rusak:
                self.panjang_baik = round(self.panjang_saluran - total_rusak, 2)
            else:
                self.panjang_saluran = total_rusak
                self.panjang_baik = 0
        else:
            p_baik = semua_segmen.filter(kondisi='BAIK').aggregate(Sum('panjang'))['panjang__sum'] or 0
            self.panjang_saluran = round(p_baik + total_rusak, 2)
            self.panjang_baik = round(p_baik, 2)

        self.panjang_rr = round(p_rr, 2)
        self.panjang_rb = round(p_rb, 2)
        self.panjang_bap = round(p_bap, 2)

        super(Saluran, self).save(update_fields=['panjang_saluran', 'panjang_baik', 'panjang_rr', 'panjang_rb', 'panjang_bap'])
        
        if self.daerah_irigasi:
            self.daerah_irigasi.update_totals()
    
    def update_panjang_total(self):
        total = self.bangunan_set.aggregate(total=Sum('panjang_saluran_antar_ruas'))['total'] or 0
        Saluran.objects.filter(pk=self.pk).update(panjang_saluran=total)
        if self.daerah_irigasi:
            self.daerah_irigasi.update_luas_fungsional()

    class Meta:
        verbose_name = "Data Saluran"
        verbose_name_plural = "2. DATA SALURAN"

    def __str__(self):
        return self.nama_saluran

    def save(self, *args, **kwargs):
        total_kondisi = (self.panjang_baik or 0) + (self.panjang_rr or 0) + (self.panjang_rb or 0) + (self.panjang_bap or 0)
        
        if self.panjang_saluran == 0 and total_kondisi > 0:
            self.panjang_saluran = total_kondisi

        if self.panjang_saluran > 0 and total_kondisi == 0:
            self.panjang_baik = self.panjang_saluran

        if self.path_koordinat and not self.geom:
            try:
                if hasattr(self.path_koordinat, 'geom_type'):
                    self.geom = self.path_koordinat
                elif isinstance(self.path_koordinat, str) and '|' in self.path_koordinat:
                    points = []
                    for coord in self.path_koordinat.split('|'):
                        if ',' in coord:
                            lat_str, lng_str = coord.split(',')
                            points.append((float(lng_str), float(lat_str)))
                    if len(points) > 1:
                        self.geom = MultiLineString([LineString(points)])
            except Exception as e:
                print(f"Gagal konversi koordinat survey: {e}")

        if self.geom and self.panjang_saluran == 0:
            try:
                self.panjang_saluran = self.geom.transform(32749, clone=True).length
            except Exception as e:
                print(f"Gagal hitung panjang presisi: {e}")
                self.panjang_saluran = self.geom.length * 111320

        self.panjang_saluran = round(self.panjang_saluran or 0, 2)
        self.panjang_baik = round(self.panjang_baik or 0, 2)
        self.panjang_rr = round(self.panjang_rr or 0, 2)
        self.panjang_rb = round(self.panjang_rb or 0, 2)
        self.panjang_bap = round(self.panjang_bap or 0, 2)

        super(Saluran, self).save(*args, **kwargs)
        
        if self.daerah_irigasi and self.is_approved:
            self.daerah_irigasi.update_totals() 


from django.core.exceptions import ValidationError
class Bangunan(models.Model):
    daerah_irigasi = models.ForeignKey(
        DaerahIrigasi, 
        on_delete=models.CASCADE, 
        related_name='bangunan_langsung', 
        null=True, blank=True,
        verbose_name="Daerah Irigasi (Pilih jika Bangunan Utama)"
    )
    saluran = models.ForeignKey(
        Saluran, 
        on_delete=models.CASCADE, 
        related_name='bangunan_list', 
        null=True, blank=True,
        verbose_name="Saluran Irigasi (Pilih jika Bangunan Ruas)"
    )
    nomenklatur_ruas = models.CharField(max_length=100, verbose_name="Nomenklatur Ruas Bangunan")
    
    terhubung_ke = models.ForeignKey(
        'self', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='ruas_berikutnya',
        verbose_name="Terhubung ke Ruas (Hulu)"
    )

    JENIS_BANGUNAN = [
        ('BENDUNG', 'Bendung'),
        ('POMPA', 'Pompa/Pumping'),
        ('BAGI', 'Bangunan Bagi'),
        ('SADAP', 'Bangunan Sadap'),
        ('BAGISADAP', 'Bangunan Bagi Sadap'),
        ('PELENGKAP', 'Bangunan Pelengkap'),
    ]
    jenis_bangunan = models.CharField(max_length=20, choices=JENIS_BANGUNAN, default='PELENGKAP')
    
    panjang_saluran_antar_ruas = models.FloatField(default=0, verbose_name="Panjang Ruas (m)")

    icon_png = models.ImageField(upload_to='icons_epaksi/', null=True, blank=True, help_text="Upload icon PNG transparan (B01, P01, dll)")

    def get_mermaid_class(self):
        detail = self.layanan_list.first()
        return f"type-{detail.kode_aset}" if detail else "type-default"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if self.saluran:
            self.saluran.refresh_summary()
    
    class Meta:
        verbose_name = "Data Aset Bangunan"
        verbose_name_plural = "3. DATA ASET BANGUNAN"

    def __str__(self):
        return self.nomenklatur_ruas

    def get_full_nomenklatur(self):
        if self.terhubung_ke:
            return f"{self.terhubung_ke.nomenklatur_ruas} - {self.nomenklatur_ruas}"
        return self.nomenklatur_ruas
    

class JenisPintu(models.Model):
    nama = models.CharField(max_length=100, unique=True)
    def __str__(self):
        return self.nama
    
    class Meta:
        verbose_name = "5. JENIS PINTU" 
        verbose_name_plural = "5. JENIS PINTU"

JENIS_SALURAN_CHOICES = [
        ('INDUK', 'Saluran Induk'),
        ('SEKUNDER', 'Saluran Sekunder'),
        ('TERSIER', 'Saluran Tersier'),
        ('PENGURAS', 'Saluran Penguras'),
        ('MANUAL', 'Input Manual'),
    ]

class DetailLayananBangunan(models.Model):
    KONDISI_CHOICES = [
        ('BAIK', 'Baik'),
        ('RR', 'Rusak Ringan'),
        ('RB', 'Rusak Berat'),
    ]

    kondisi_bangunan = models.CharField(max_length=10, choices=KONDISI_CHOICES, default='BAIK', verbose_name="Kondisi Fisik Bangunan")
    bangunan = models.ForeignKey(Bangunan, on_delete=models.CASCADE, related_name='layanan_list')
    surveyor = models.CharField(max_length=100, blank=True, null=True)
    latitude = models.FloatField(default=0, verbose_name="Latitude")
    longitude = models.FloatField(default=0, verbose_name="Longitude")
    foto_aset = models.ImageField(upload_to='foto_aset/bangunan/', null=True, blank=True, verbose_name="Foto Survey Admin 1")
    foto_aset_2 = models.ImageField(upload_to='foto_aset/bangunan/', null=True, blank=True, verbose_name="Foto Survey Admin 2")
    foto_aset_3 = models.ImageField(upload_to='foto_aset/bangunan/', null=True, blank=True, verbose_name="Foto Survey Admin 3")
    foto_aset_4 = models.ImageField(upload_to='foto_aset/bangunan/', null=True, blank=True, verbose_name="Foto Survey Admin 4")
    foto_aset_5 = models.ImageField(upload_to='foto_aset/bangunan/', null=True, blank=True, verbose_name="Foto Survey Admin 5")
    
    debit_keluar = models.FloatField(default=0, verbose_name="Debit yang Diambil (l/dt)")
    kecamatan = models.CharField(max_length=100, blank=True, null=True)
    desa = models.CharField(max_length=100, blank=True, null=True)
    nomenklatur_pengatur = models.CharField(max_length=100, blank=True, null=True, verbose_name="NOMENKLATUR BANGUNAN PENGATUR")

    lebar_saluran = models.FloatField(default=0, verbose_name="Lebar Saluran (m)")
    tinggi_saluran = models.FloatField(default=0, verbose_name="Tinggi Saluran (m)")
    
    kode_aset = models.CharField(max_length=5, choices=KODE_BANGUNAN_MASTER, null=True, blank=True)
    nama_aset_manual = models.CharField(max_length=150, verbose_name="Nama Aset")
    keterangan_aset = models.CharField(max_length=255, verbose_name="Keterangan", help_text="Contoh: Ciwado")
    
    ket_baik = models.TextField(blank=True, null=True)
    ket_rr = models.TextField(blank=True, null=True)
    ket_rb = models.TextField(blank=True, null=True)

    foto_baik1 = models.ImageField(upload_to='survey/baik/', null=True, blank=True)
    foto_baik2 = models.ImageField(upload_to='survey/baik/', null=True, blank=True)
    foto_baik3 = models.ImageField(upload_to='survey/baik/', null=True, blank=True)
    foto_baik4 = models.ImageField(upload_to='survey/baik/', null=True, blank=True)
    foto_baik5 = models.ImageField(upload_to='survey/baik/', null=True, blank=True)

    foto_rr1 = models.ImageField(upload_to='survey/rr/', null=True, blank=True)
    foto_rr2 = models.ImageField(upload_to='survey/rr/', null=True, blank=True)
    foto_rr3 = models.ImageField(upload_to='survey/rr/', null=True, blank=True)
    foto_rr4 = models.ImageField(upload_to='survey/rr/', null=True, blank=True)
    foto_rr5 = models.ImageField(upload_to='survey/rr/', null=True, blank=True)

    foto_rb1 = models.ImageField(upload_to='survey/rb/', null=True, blank=True)
    foto_rb2 = models.ImageField(upload_to='survey/rb/', null=True, blank=True)
    foto_rb3 = models.ImageField(upload_to='survey/rb/', null=True, blank=True)
    foto_rb4 = models.ImageField(upload_to='survey/rb/', null=True, blank=True)
    foto_rb5 = models.ImageField(upload_to='survey/rb/', null=True, blank=True)

    luas_areal = models.FloatField(default=0, verbose_name="Luas Areal Fungsional(Ha)")

    # poligon_layanan = models.ForeignKey(
    #     'LayerPendukung', 
    #     on_delete=models.SET_NULL, 
    #     null=True, 
    #     blank=True, 
    #     limit_choices_to={'kategori': 'lahan'}, 
    #     verbose_name="Poligon Area Layanan Fungsional",
    #     help_text="Pilih peta area yang dilayani oleh bangunan ini"
    # )

    poligon_layanan = models.ManyToManyField(
        'LayerPendukung', 
        blank=True, 
        limit_choices_to={'kategori': 'lahan'}, 
        verbose_name="Poligon Area Layanan Fungsional",
        help_text="Tahan tombol CTRL (Windows) atau CMD (Mac) saat mengklik untuk memilih lebih dari 1 poligon."
    )
    
    jenis_pintu = models.ForeignKey(JenisPintu, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="Jenis Pintu")
    pintu_total_unit = models.IntegerField(default=0, verbose_name="Pintu Total Unit")
    pintu_baik = models.IntegerField(default=0)
    pintu_rusak_ringan = models.IntegerField(default=0)
    pintu_rusak_berat = models.IntegerField(default=0)

    nomenklatur_kiri = models.CharField(max_length=100, blank=True, null=True, verbose_name="Nomenklatur")
    luas_kiri = models.FloatField(default=0, verbose_name="Luas Areal (Ha)")
    jenis_saluran_kiri = models.CharField(
        max_length=20, choices=JENIS_SALURAN_CHOICES, default='TERSIER', verbose_name="Jenis Saluran"
    )
    saluran_manual_kiri = models.CharField(max_length=100, blank=True, null=True, verbose_name="Input Nama")

    # SISI TENGAH 
    nomenklatur_tengah = models.CharField(max_length=100, blank=True, null=True, verbose_name="Nomenklatur")
    luas_tengah = models.FloatField(default=0, verbose_name="Luas Areal (Ha)")
    jenis_saluran_tengah = models.CharField(
        max_length=20, choices=JENIS_SALURAN_CHOICES, default='INDUK', verbose_name="Jenis Saluran"
    )
    saluran_manual_tengah = models.CharField(max_length=100, blank=True, null=True, verbose_name="Input Nama")

    # SISI KANAN
    nomenklatur_kanan = models.CharField(max_length=100, blank=True, null=True, verbose_name="Nomenklatur")
    luas_kanan = models.FloatField(default=0, verbose_name="Luas Areal (Ha)")
    jenis_saluran_kanan = models.CharField(
        max_length=20, choices=JENIS_SALURAN_CHOICES, default='TERSIER', verbose_name="Jenis Saluran"
    )
    saluran_manual_kanan = models.CharField(max_length=100, blank=True, null=True, verbose_name="Input Nama")
    
    sal_induk_baik = models.FloatField(default=0)
    sal_induk_rusak_ringan = models.FloatField(default=0)
    sal_induk_rusak_berat = models.FloatField(default=0)
    sal_induk_bap = models.FloatField(default=0)

    sal_sekunder_baik = models.FloatField(default=0)
    sal_sekunder_rusak_ringan = models.FloatField(default=0)
    sal_sekunder_rusak_berat = models.FloatField(default=0)
    sal_sekunder_bap = models.FloatField(default=0)

    keterangan = models.TextField(blank=True, null=True)

    jumlah_cabang_sekunder = models.IntegerField(default=0, verbose_name="Jumlah Cabang Sekunder")
    jumlah_cabang_tersier = models.IntegerField(default=0, verbose_name="Jumlah Cabang Tersier")
    is_saluran_berlanjut = models.BooleanField(default=True, verbose_name="Saluran Berlanjut")

    class Meta:
        verbose_name = "Detail Ruas & Layanan"
        verbose_name_plural = "DAFTAR NOMENKLATUR BANGUNAN PENGATUR"

    def save(self, *args, **kwargs):
        # 1. Otomatis update luas_areal total
        self.luas_areal = (self.luas_kiri or 0) + (self.luas_tengah or 0) + (self.luas_kanan or 0)
        
        # 2. Hitung Pintu Total
        self.pintu_total_unit = (self.pintu_baik or 0) + (self.pintu_rusak_ringan or 0) + (self.pintu_rusak_berat or 0)
        
        # =======================================================
        # 3. LOGIKA DUAL-SATELIT (OSM + ARCGIS) UNTUK ALAMAT
        # =======================================================
        print("\n--- 🛰️ MEMULAI RADAR KOORDINAT BANGUNAN ---")
        
        desa_kosong = not self.desa or str(self.desa).strip() == '' or str(self.desa).strip().lower() == 'none'
        kec_kosong = not self.kecamatan or str(self.kecamatan).strip() == '' or str(self.kecamatan).strip().lower() == 'none'
        
        if self.latitude and self.longitude and float(self.latitude) != 0 and float(self.longitude) != 0:
            if desa_kosong or kec_kosong:
                try:
                    lat_str = str(self.latitude).replace(',', '.')
                    lng_str = str(self.longitude).replace(',', '.')
                    
                    # ----------------------------------------------------
                    # SATELIT 1: OpenStreetMap (Nominatim)
                    # ----------------------------------------------------
                    print(">> Menghubungi Satelit 1 (OpenStreetMap)...")
                    osm_geo = Nominatim(user_agent="sirigasi_cirebon_1")
                    loc_osm = osm_geo.reverse(f"{lat_str}, {lng_str}", exactly_one=True, timeout=5)
                    
                    if loc_osm and loc_osm.raw.get('address'):
                        addr_osm = loc_osm.raw['address']
                        
                        if desa_kosong:
                            n_desa = addr_osm.get('village') or addr_osm.get('hamlet') or addr_osm.get('residential') or addr_osm.get('neighbourhood') or ''
                            self.desa = str(n_desa).replace('Desa ', '').replace('Kelurahan ', '').strip()
                            if self.desa: desa_kosong = False # Tandai kalau desa sudah ketemu
                            
                        if kec_kosong:
                            n_kec = addr_osm.get('city_district') or addr_osm.get('state_district') or addr_osm.get('municipality') or addr_osm.get('suburb') or addr_osm.get('town') or ''
                            self.kecamatan = str(n_kec).replace('Kecamatan ', '').strip()
                            if self.kecamatan: kec_kosong = False # Tandai kalau kec sudah ketemu

                    # ----------------------------------------------------
                    # SATELIT 2: ArcGIS ESRI (Jika Satelit 1 Gagal/Kurang)
                    # ----------------------------------------------------
                    if desa_kosong or kec_kosong:
                        print(">> OpenStreetMap kurang lengkap. Ganti ke Satelit 2 (ArcGIS)...")
                        arcgis_geo = ArcGIS()
                        loc_arc = arcgis_geo.reverse(f"{lat_str}, {lng_str}", exactly_one=True, timeout=5)
                        
                        if loc_arc and loc_arc.raw.get('address'):
                            addr_arc = loc_arc.raw['address']
                            print(f">> Balasan ArcGIS: {addr_arc}")
                            
                            # Di ArcGIS: Desa biasanya masuk ke 'Neighborhood' atau 'District'
                            if desa_kosong:
                                n_desa2 = addr_arc.get('Neighborhood') or addr_arc.get('District') or ''
                                self.desa = str(n_desa2).replace('Desa ', '').replace('Kelurahan ', '').strip()
                                
                            # Di ArcGIS: Kecamatan biasanya masuk ke 'City'
                            if kec_kosong:
                                n_kec2 = addr_arc.get('City') or addr_arc.get('District') or ''
                                self.kecamatan = str(n_kec2).replace('Kecamatan ', '').replace('Kec. ', '').strip()
                                
                    print(f"✅ HASIL FINAL -> Desa: '{self.desa}', Kec: '{self.kecamatan}'")
                
                except Exception as e:
                    print(f"⚠️ Gagal menghubungi kedua satelit: {e}")
        
        print("------------------------------------------\n")

        # 4. Panggil save utama
        super().save(*args, **kwargs)
        
        # 5. Trigger Update Daerah Irigasi
        target_di = None
        if self.bangunan.saluran:
            target_di = self.bangunan.saluran.daerah_irigasi
        elif hasattr(self.bangunan, 'daerah_irigasi'):
            target_di = self.bangunan.daerah_irigasi
            
        if target_di:
            target_di.update_totals()

    def get_full_nomenclature(self):
        return f"{self.kode_aset} - {self.nama_aset_manual} - {self.keterangan_aset}"
    
    def __str__(self):
        nama = self.nama_aset_manual or "Tanpa Nama"
        kode = self.kode_aset or "---"
        ket = f" ({self.keterangan_aset})" if self.keterangan_aset else ""
        return f"{kode} - {nama}{ket}"

import zipfile
import xml.etree.ElementTree as ET
    
class LayerPendukung(models.Model):
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
    kategori = models.CharField(max_length=50, choices=KATEGORI_CHOICES)
    file_geojson = models.FileField(upload_to='geojson/')
    warna_garis = models.CharField(max_length=7, default='#3388ff')
    aktif = models.BooleanField(default=True)

    class Meta:
        verbose_name = "6. LAYER PENDUKUNG"
        verbose_name_plural = "6. LAYER PENDUKUNG"

    def save(self, *args, **kwargs):
        # Jalankan penyimpanan file terlebih dahulu
        super().save(*args, **kwargs)

        # Logika Ekstraksi Khusus Luas Fungsional dari KMZ
        if self.kategori == 'lahan' and self.file_geojson.name.endswith('.kmz'):
            self.ekstrak_fungsional_kmz()

    def ekstrak_fungsional_kmz(self):
        try:
            with zipfile.ZipFile(self.file_geojson.path, 'r') as zf:
                content = zf.read('doc.kml')
                root = ET.fromstring(content)
                ns = {'kml': 'http://www.opengis.net/kml/2.2'}

                # Cari semua Placemark
                for pm in root.findall('.//kml:Placemark', ns):
                    name_node = pm.find('kml:name', ns)
                    nama_objek = name_node.text.upper() if name_node is not None else ""

                    # Filter: Hanya proses jika nama mengandung "IGT_CIREBON_FUNGSIONAL"
                    # atau jika format namanya "IGT_Cirebon_fungsional [NAMA DI]"
                    if "IGT_CIREBON_FUNGSIONAL" in nama_objek:
                        
                        # Ambil geometri Polygon
                        poly_node = pm.find('.//kml:Polygon', ns)
                        if poly_node is not None:
                            coord_node = poly_node.find('.//kml:coordinates', ns)
                            if coord_node is not None:
                                coords_text = coord_node.text.strip()
                                
                                # Konversi koordinat KML ke format List GEOS
                                points = []
                                for p in coords_text.split():
                                    c = p.split(',')
                                    if len(c) >= 2:
                                        points.append((float(c[0]), float(c[1])))
                                
                                if len(points) > 3:
                                    geom = Polygon(points)
                                    
                                    # Hitung Luas (Hektar) menggunakan transformasi UTM 49S (32749)
                                    # agar akurat dalam satuan meter/hektar
                                    luas_m2 = GEOSGeometry(geom.wkt, srid=4326).transform(32749, clone=True).area
                                    luas_ha = round(luas_m2 / 10000, 2)

                                    # Cari Daerah Irigasi yang cocok berdasarkan nama objek
                                    # Contoh nama di KML: "IGT_Cirebon_fungsional KETOS"
                                    from .models import DaerahIrigasi
                                    for di in DaerahIrigasi.objects.all():
                                        if di.nama_di.upper() in nama_objek:
                                            di.luas_baku_onemap = luas_ha # atau luas_fungsional
                                            di.save()
                                            print(f"Berhasil update luas {di.nama_di}: {luas_ha} Ha")

        except Exception as e:
            print(f"Gagal ekstrak KMZ Lahan: {e}")

    def __str__(self):
        return f"{self.nama} ({self.get_kategori_display()})"
    
class AsetSaluran(models.Model):
    saluran = models.ForeignKey(
        Saluran, 
        on_delete=models.CASCADE, 
        related_name='aset_fisik_saluran'
    )
    
    # Kolom dari gambar (Aset Saluran)
    nama_aset_saluran = models.CharField(max_length=255) # Contoh: Sekunder 3, Sekunder 6
    nomenklatur = models.CharField(max_length=100, null=True, blank=True)
    bangunan_hulu = models.CharField(max_length=100, null=True, blank=True)
    bangunan_hilir = models.CharField(max_length=100, null=True, blank=True)
    kode_saluran = models.CharField(max_length=100) # Contoh: S02 / Saluran Sekunder
    
    foto = models.ImageField(upload_to='foto_aset/saluran/', null=True, blank=True)
    
    # Data Teknis
    jumlah_lining = models.IntegerField(default=0)
    panjang_saluran_m = models.FloatField(default=0, help_text="Panjang dalam meter")
    luas_layanan_ha = models.FloatField(default=0, help_text="Luas dalam hektar")
    
    # Fungsi & Kondisi
    fungsi_bangunan_sipil = models.CharField(max_length=255, null=True, blank=True)
    fungsi_jalan_inspeksi = models.CharField(max_length=255, null=True, blank=True)
    prioritas = models.FloatField(default=0)
    kondisi_aset = models.CharField(max_length=50) # JELEK, SEDANG, BAIK
    nilai_persen = models.FloatField(default=0)

    class Meta:
        verbose_name_plural = "ASET SALURAN"

    def __str__(self):
        return f"{self.nama_aset_saluran} ({self.saluran.nama_saluran})"    
        

class PelaporanAset(models.Model):
    daerah_irigasi = models.OneToOneField(DaerahIrigasi, on_delete=models.CASCADE, related_name='laporan_aksi')
    tahun = models.IntegerField(default=2024)
    luas_fungsional = models.FloatField(default=0)

    # --- IKSI JARINGAN UTAMA ---
    utama_prasarana_fisik = models.FloatField(default=0, verbose_name="Prasarana Fisik (Utama)")
    utama_produktivitas_tanam = models.FloatField(default=0, verbose_name="Produktivitas Tanam (Utama)")
    utama_sarana_penunjang = models.FloatField(default=0, verbose_name="Sarana Penunjang (Utama)")
    utama_organisasi_personalia = models.FloatField(default=0, verbose_name="Organisasi Personalia (Utama)")
    utama_dokumentasi = models.FloatField(default=0, verbose_name="Dokumentasi (Utama)")
    utama_gp3a_ip3a = models.FloatField(default=0, verbose_name="GP3A / IP3A")

    # --- IKSI JARINGAN TERSIER ---
    tersier_prasarana_fisik = models.FloatField(default=0, verbose_name="Prasarana Fisik (Tersier)")
    tersier_produktivitas_tanam = models.FloatField(default=0, verbose_name="Produktivitas Tanam (Tersier)")
    tersier_kondisi_op = models.FloatField(default=0, verbose_name="Kondisi OP")
    tersier_petugas_pembagi_air = models.FloatField(default=0, verbose_name="Petugas Pembagi Air")
    tersier_dokumentasi = models.FloatField(default=0, verbose_name="Dokumentasi (Tersier)")
    tersier_p3a = models.FloatField(default=0, verbose_name="P3A")

    def total_utama(self):
        # Logika perhitungan rata-rata atau bobot IKSI Utama
        fields = [self.utama_prasarana_fisik, self.utama_produktivitas_tanam, self.utama_sarana_penunjang, 
                  self.utama_organisasi_personalia, self.utama_dokumentasi, self.utama_gp3a_ip3a]
        return sum(fields) / len(fields)

    def total_tersier(self):
        # Logika perhitungan rata-rata atau bobot IKSI Tersier
        fields = [self.tersier_prasarana_fisik, self.tersier_produktivitas_tanam, self.tersier_kondisi_op, 
                  self.tersier_petugas_pembagi_air, self.tersier_dokumentasi, self.tersier_p3a]
        return sum(fields) / len(fields)

    def total_gabungan(self):
        return (self.total_utama() + self.total_tersier()) / 2

    def hitung_skor_final(self):
        """Menghitung total IKSI berdasarkan Kelompok DI sesuai standar PDF"""
        di = self.daerah_irigasi
        skor_utama = self.total_utama()
        skor_tersier = self.total_tersier()

        # Logika Pembobotan Berdasarkan Kelompok (Lihat PDF Hal 2)
        if di.kelompok_di == '1': # > 1000 ha
            return (skor_utama * 0.8) + (skor_tersier * 0.2)
        elif di.kelompok_di == '2': # 150 - 1000 ha
            return (skor_utama * 0.6) + (skor_tersier * 0.4)
        else: # Kelompok 3 (< 150 ha)
            return (skor_utama * 0.5) + (skor_tersier * 0.5)

    def get_status_kinerja(self):
        """Menentukan status Baik/Rusak berdasarkan skor (Lihat PDF Hal 3)"""
        total = self.hitung_skor_final()
        if total >= 80: return "BAIK"
        if total >= 70: return "RUSAK RINGAN"
        if total >= 55: return "RUSAK SEDANG"
        return "JELEK (PERLU PERHATIAN)"

    class Meta:
        verbose_name = "Pelaporan Aset & IKSI"
        verbose_name_plural = "5. PELAPORAN ASET & IKSI"

    def __str__(self):
        return f"IKSI {self.daerah_irigasi.nama_di} - {self.tahun}"
    
class LaporanIksiSaluran(models.Model):
    # RUMAH DATA RANGKUMAN (Data Utama)
    saluran = models.ForeignKey('Saluran', on_delete=models.CASCADE, related_name='laporan_iksi')
    tahun = models.IntegerField(default=2024)
    surveyor = models.CharField(max_length=100, blank=True)
    
    # Nilai Akumulasi (Rangkuman)
    total_nilai_iksi = models.FloatField(default=0, verbose_name="Total Nilai IKSI (%)")
    catatan_rekomendasi = models.TextField(blank=True)
    

    class Meta:
        verbose_name = "IKSI - 1. Rangkuman"
        verbose_name_plural = "4. DATA IKSI(Rangkuman)"

    def __str__(self):
        return f"Rangkuman IKSI {self.saluran.nama_saluran} ({self.tahun})"


class RuasIksiSaluran(models.Model):
    # RUMAH DATA RUAS (Detail per Item)
    laporan_utama = models.ForeignKey(LaporanIksiSaluran, on_delete=models.CASCADE, related_name='ruas_detail')
    
    kode_item = models.CharField(max_length=20, help_text="Contoh: S02_01")
    nama_ruas_item = models.CharField(max_length=255, verbose_name="Uraian Ruas/Kuesioner")
    
    # Value (Sama antara Rangkuman & Ruas)
    nilai_kondisi = models.FloatField(default=0)    
    bobot_pengaruh = models.FloatField(default=0)
    nilai_akhir = models.FloatField(default=0)
    
    # Perbedaan Utama: Ada Foto di Ruas
    foto_kondisi = models.ImageField(upload_to='iksi/saluran/', blank=True, null=True)
    catatan_ruas = models.TextField(blank=True, null=True)

    class Meta:
        verbose_name = "IKSI - 2. Detail Ruas"
        verbose_name_plural = "IKSI - 2. Detail Ruas"

class Paisaluran(models.Model):

    saluran = models.OneToOneField('Saluran', on_delete=models.CASCADE, related_name='pai_saluran')
    
    # Identitas (Sesuai list S01-S017)
    jenis_aset_kode = models.CharField(
        max_length=5, 
        choices=KODE_SALURAN_MASTER, 
        verbose_name="Jenis Aset (Kode)"
    )
    nama_aset = models.CharField(max_length=100) # Contoh: PRIMER 1
    nomenklatur = models.CharField(max_length=100)
    
    # Batas Ruas
    bangunan_hulu = models.CharField(max_length=100)
    bangunan_hilir = models.CharField(max_length=100)
    subsistem = models.CharField(max_length=100, blank=True)
    
    # Data Teknis & Kapasitas
    luas_layanan_ha = models.FloatField(default=0)
    q_desain = models.FloatField(default=0, verbose_name="Q Desain (m3/det)")
    panjang_saluran_m = models.FloatField(default=0)
    tahun_dibangun = models.IntegerField(null=True, blank=True)
    
    # Data Pintu pada Saluran
    pintu_jumlah = models.IntegerField(default=0)
    pintu_lebar_m = models.FloatField(default=0)
    pintu_tinggi_m = models.FloatField(default=0)
    pintu_tenaga = models.CharField(max_length=50, choices=[('MANUAL', 'Manual'), ('LISTRIK', 'Listrik')], default='MANUAL')
    pintu_bahan = models.CharField(max_length=50, default='Besi')

    # Dimensi Desain
    desain_li = models.FloatField(default=0, verbose_name="Desain Li (m)")
    desain_b = models.FloatField(default=0, verbose_name="Desain b (m)")
    desain_la = models.FloatField(default=0, verbose_name="Desain La (m)")
    desain_h = models.FloatField(default=0, verbose_name="Desain H (m)")
    desain_kemiringan = models.CharField(max_length=20, default="90 derajat")

    # Dimensi Kenyataan (Existing)
    nyata_li = models.FloatField(default=0, verbose_name="Kenyataan Li (m)")
    nyata_b = models.FloatField(default=0, verbose_name="Kenyataan b (m)")
    nyata_la = models.FloatField(default=0, verbose_name="Kenyataan La (m)")
    nyata_h = models.FloatField(default=0, verbose_name="Kenyataan H (m)")
    
    foto = models.ImageField(upload_to='pai/saluran/', blank=True, null=True)
    catatan = models.TextField(blank=True)

    class Meta:
        verbose_name = "PAI Saluran"
        verbose_name_plural = "PAI Saluran"

class PaiBangunan(models.Model):
    bangunan = models.OneToOneField('Bangunan', on_delete=models.CASCADE, related_name='pai_bangunan')
    
    jenis_aset_kode = models.CharField(max_length=10) # Contoh: B01, P01
    nama_bangunan = models.CharField(max_length=100)
    nomenklatur = models.CharField(max_length=100)
    
    # Spesifikasi teknis bangunan bisa disesuaikan nanti
    tahun_dibangun = models.IntegerField(null=True, blank=True)
    foto = models.ImageField(upload_to='pai/bangunan/', blank=True, null=True)
    catatan = models.TextField(blank=True)

    class Meta:
        verbose_name = "PAI Bangunan"
        verbose_name_plural = "PAI Bangunan"

class AsetPendukung(models.Model):
    daerah_irigasi = models.ForeignKey(DaerahIrigasi, on_delete=models.CASCADE)
    nama_aset = models.CharField(max_length=100) # Kantor, Motor Juru, dsb
    jumlah = models.IntegerField(default=1)
    kondisi = models.CharField(max_length=50) # Baik/Rusak

class DetailSegmenSaluran(models.Model):
    saluran = models.ForeignKey(Saluran, on_delete=models.CASCADE, related_name='segments')
    KONDISI_CHOICES = [
        ('BAIK', 'Baik'),
        ('RR', 'Rusak Ringan'),
        ('RB', 'Rusak Berat'),
        ('BAP', 'Belum Ada Pasangan'),
    ]
    kondisi = models.CharField(max_length=10, choices=KONDISI_CHOICES)
    panjang = models.FloatField(default=0)
    titik_awal = models.CharField(max_length=255, blank=True, null=True)
    titik_akhir = models.CharField(max_length=255, blank=True, null=True)
    keterangan = models.TextField(blank=True, null=True)
    foto = models.TextField(blank=True, null=True) # JSON list path foto
    # geom = gis_models.LineStringField(srid=4326, blank=True, null=True, verbose_name="Peta Segmen")
    geom = gis_models.GeometryField(srid=4326, blank=True, null=True, verbose_name="Peta Segmen")
    # foto_admin = gis_models.ImageField(upload_to='segmen_saluran/', blank=True, null=True, verbose_name="Upload Foto (Web)")
    foto_admin = gis_models.ImageField(upload_to='segmen_saluran/', blank=True, null=True, verbose_name="Upload Foto Utama")
    foto_admin_2 = gis_models.ImageField(upload_to='segmen_saluran/', blank=True, null=True, verbose_name="Upload Foto Ke-2")
    foto_admin_3 = gis_models.ImageField(upload_to='segmen_saluran/', blank=True, null=True, verbose_name="Upload Foto Ke-3")
    foto_admin_4 = gis_models.ImageField(upload_to='segmen_saluran/', blank=True, null=True, verbose_name="Upload Foto Ke-4")
    foto_admin_5 = gis_models.ImageField(upload_to='segmen_saluran/', blank=True, null=True, verbose_name="Upload Foto Ke-5")

    @property
    def get_panjang_format(self):
        return f"{round(self.panjang, 2)} m"

    def __str__(self):
        return f"{self.saluran.nama_saluran} - {self.kondisi} ({self.panjang}m)"
    
    def save(self, *args, **kwargs):
        from django.contrib.gis.geos import LineString
        
        # SKENARIO A: User MENGETIK Titik Awal & Akhir manual, tapi peta kosong
        if self.titik_awal and self.titik_akhir and not self.geom:
            try:
                lat_awal, lon_awal = map(float, self.titik_awal.replace(' ', '').split(','))
                lat_akhir, lon_akhir = map(float, self.titik_akhir.replace(' ', '').split(','))
                # Buat garis tunggal di peta
                self.geom = LineString((lon_awal, lat_awal), (lon_akhir, lat_akhir))
            except Exception as e:
                print(f"Gagal mengonversi koordinat teks ke peta: {e}")

        # SKENARIO B: User MENGGAMBAR di peta manual / import KMZ
        # Kita ambil ujung koordinatnya untuk mengisi teks Titik Awal & Akhir secara otomatis
        if self.geom:
            try:
                if self.geom.geom_type == 'LineString':
                    coords = self.geom.coords
                    self.titik_awal = f"{coords[0][1]}, {coords[0][0]}"
                    self.titik_akhir = f"{coords[-1][1]}, {coords[-1][0]}"
                elif self.geom.geom_type == 'MultiLineString':
                    coords_awal = self.geom[0].coords
                    coords_akhir = self.geom[-1].coords
                    self.titik_awal = f"{coords_awal[0][1]}, {coords_awal[0][0]}"
                    self.titik_akhir = f"{coords_akhir[-1][1]}, {coords_akhir[-1][0]}"
            except Exception as e:
                print(f"Gagal mengekstrak koordinat peta ke teks: {e}")

        # HITUNG PANJANG OTOMATIS (Jika masih 0)
        if self.geom and self.panjang == 0:
            try:
                # Menghitung dengan akurasi meter (UTM)
                self.panjang = round(self.geom.transform(32749, clone=True).length, 2)
            except Exception:
                self.panjang = round(self.geom.length * 111320, 2)

        super().save(*args, **kwargs)
        
        # Update Rekap Saluran Induk
        if self.saluran:
            self.saluran.refresh_summary()


class UnitPintuBangunan(models.Model):
    detail_layanan = models.ForeignKey(DetailLayananBangunan, on_delete=models.CASCADE, related_name='unit_pintu')
    nomor_pintu = models.IntegerField(default=1)
    nama_pintu = models.CharField(max_length=150, verbose_name="Nama Pintu", help_text="Akan terisi otomatis dari Nomenklatur Ruas")
    jenis_pintu = models.ForeignKey('JenisPintu', on_delete=models.SET_NULL, null=True, blank=True)
    lebar_pintu = models.FloatField(default=0)
    tinggi_pintu = models.FloatField(default=0)
    
    KONDISI_CHOICES = [
        ('BAIK', 'Baik'),
        ('RR', 'Rusak Ringan'),
        ('RB', 'Rusak Berat'),
    ]
    kondisi = models.CharField(max_length=10, choices=KONDISI_CHOICES, default='BAIK')
    foto_pintu = models.ImageField(upload_to='foto_pintu/', null=True, blank=True)

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.trigger_di_update() # Update D.I saat pintu ditambah/diedit
        
    def delete(self, *args, **kwargs):
        super().delete(*args, **kwargs)
        self.trigger_di_update() # Update D.I saat pintu dihapus
        
    def trigger_di_update(self):
        # Lacak Daerah Irigasi miliknya dan suruh hitung ulang
        try:
            target_di = None
            bgn = self.detail_layanan.bangunan
            if bgn.saluran:
                target_di = bgn.saluran.daerah_irigasi
            elif hasattr(bgn, 'daerah_irigasi'):
                target_di = bgn.daerah_irigasi
                
            if target_di:
                target_di.update_totals()
        except Exception:
            pass

    def __str__(self):
        return self.nama_pintu