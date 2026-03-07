import os
import sys 
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'main.settings') 

try:
    django.setup()
    print("--- Django Berhasil Terkoneksi ---")
except Exception as e:
    print(f"--- ERROR SETUP: {e} ---")
    sys.exit()

try:
    django.setup()
except Exception as e:
    print(f"Gagal Setup Django: {e}")
    print("Coba ganti 'backend.settings' menjadi 'config.settings' di baris 13")
    sys.exit()

from apps.models import Saluran, DetailSegmenSaluran

def migrate_to_segments():
    print("Memulai proses migrasi data foto ke segmen...")
    salurans = Saluran.objects.all()
    count = 0

    for s in salurans:
        # Cek apakah sudah ada segmen (biar tidak double)
        # if s.segments.exists():
        #     print(f"Skipping {s.nama_saluran}, sudah ada data segmen.")
        #     continue

        # List data lama untuk dipindah
        kondisi_list = [
            ('BAIK', s.panjang_baik, s.foto_baik, s.keterangan_baik),
            ('RR', s.panjang_rr, s.foto_rr, s.keterangan_rr),
            ('RB', s.panjang_rb, s.foto_rb, s.keterangan_rb),
            ('BAP', s.panjang_bap, s.foto_bap, s.keterangan_bap),
        ]

        found_data = False
        for kondisi, panjang, foto, ket in kondisi_list:
            # Pindahkan jika ada panjang > 0 atau ada path foto
            if (panjang and panjang > 0) or (foto and foto != "[]" and foto != "null" and foto):
                DetailSegmenSaluran.objects.create(
                    saluran=s,
                    kondisi=kondisi,
                    panjang=panjang or 0,
                    keterangan=ket or f"Migrasi data awal {kondisi}",
                    foto=foto
                )
                found_data = True
        
        if found_data:
            print(f"Berhasil memindahkan data: {s.nama_saluran}")
            count += 1
            # Hitung ulang summary agar sinkron
            s.refresh_summary()

    print(f"\nSelesai! {count} Saluran berhasil dimigrasi.")

if __name__ == "__main__":
    migrate_to_segments()