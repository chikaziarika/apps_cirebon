import os

def bulk_rename_epaksi():
    # 1. Tentukan path folder (relatif terhadap posisi skrip ini)
    # Kita naik satu tingkat dari 'apps' lalu masuk ke 'static/icons'
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target_folder = os.path.join(base_dir, 'static', 'icons')

    # 2. Daftar mapping (Sesuaikan dengan hasil potongan katalog bapak)
    mapping = {
        'icon_0.png': 'B01.png', # Bendung
        'icon_1.png': 'B02.png', # Bendung Gerak
        'icon_2.png': 'P01.png', # Bangunan Bagi
        'icon_3.png': 'P02.png', # Bagi Sadap
        'icon_4.png': 'P03.png', # Sadap
        'icon_5.png': 'S01.png', # Saluran Primer
        'icon_6.png': 'S02.png', # Saluran Sekunder
    }

    if not os.path.exists(target_folder):
        print(f"❌ Folder tujuan tidak ditemukan: {target_folder}")
        return

    print(f"🚀 Memulai rename di: {target_folder}")
    
    count = 0
    for old_name, new_name in mapping.items():
        old_file = os.path.join(target_folder, old_name)
        new_file = os.path.join(target_folder, new_name)

        if os.path.exists(old_file):
            # Hapus file tujuan jika sudah ada (overwrite)
            if os.path.exists(new_file):
                os.remove(new_file)
            
            os.rename(old_file, new_file)
            print(f"✅ Berhasil: {old_name} -> {new_name}")
            count += 1
        else:
            print(f"⚠ Skip: {old_name} tidak ada di folder icons.")

    print(f"\n✨ Selesai! {count} icon ePAKSI siap digunakan di dashboard.")

if __name__ == "__main__":
    bulk_rename_epaksi()