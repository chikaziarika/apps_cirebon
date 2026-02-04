import os
import django
import pandas as pd

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'main.settings')
django.setup()

from apps.models import DaerahIrigasi

def run_import():
    # file_path = 'dataSet.xlsx'
    file_path = r'C:\Users\Jelita\Desktop\apps_cirebon\backend\dataSet.xlsx'
    sheet_name = 'Konjar Kab 2025 (PAKAI)'
    
    try:
        # Kita pakai header=9 sesuai file Anda
        df = pd.read_excel(file_path, sheet_name=sheet_name, engine='openpyxl', header=9)
        
        print("--- Memulai Import Ulang ---")
        count = 0

        for index, row in df.iterrows():
            nama_di = row.iloc[2] # Kolom DAERAH IRIGASI
            
            if pd.notna(nama_di) and "JUMLAH" not in str(nama_di) and str(nama_di).strip() != "":
                
                # JANGAN PAKAI UPDATE_OR_CREATE pada kode yang mungkin duplikat
                # Kita pakai create() saja atau pastikan kode_di unik
                kode_excel = str(row.iloc[1]).strip() if pd.notna(row.iloc[1]) else ""
                
                # Jika kode excel kosong atau cuma spasi, buat kode unik berdasarkan index
                if kode_excel == "" or kode_excel == "nan":
                    kode_unik = f"ID-{index}"
                else:
                    # Tambahkan index di belakang untuk menghindari duplikat jika kode sama
                    kode_unik = f"{kode_excel}-{index}"

                def clean(val):
                    try:
                        return float(val) if pd.notna(val) else 0
                    except: return 0

                # Ambil data kondisi (Induk: kolom 19-21, Sekunder: 23-25)
                # Kita jumlahkan Induk + Sekunder agar data rekap akurat
                b_induk = clean(row.iloc[19]) 
                b_sek = clean(row.iloc[23])
                
                rr_induk = clean(row.iloc[20])
                rr_sek = clean(row.iloc[24])
                
                rb_induk = clean(row.iloc[21])
                rb_sek = clean(row.iloc[25])

                DaerahIrigasi.objects.create(
                    kode_di=kode_unik,
                    nama_di=str(nama_di).strip(),
                    luas_fungsional=clean(row.iloc[3]),
                    kondisi_baik=b_induk + b_sek,
                    kondisi_rusak_ringan=rr_induk + rr_sek,
                    kondisi_rusak_berat=rb_induk + rb_sek,
                )
                count += 1
        
        print(f"✅ Berhasil! {count} data unik telah masuk.")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    run_import()