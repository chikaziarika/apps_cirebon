import os
from django.core.management.base import BaseCommand
from django.core.files import File
from apps.models import Bangunan

class Command(BaseCommand):
    help = 'Sinkronisasi icon PNG dari folder ke field icon_png berdasarkan Kode Aset'

    def add_arguments(self, parser):
        parser.add_argument('folder_path', type=str, help='Path ke folder berisi icon (ex: ./static/icons/epaksi/)')

    def handle(self, *args, **options):
        folder_path = options['folder_path']
        
        if not os.path.exists(folder_path):
            self.stderr.write(f"Folder {folder_path} tidak ditemukan!")
            return

        bangunans = Bangunan.objects.all()
        count = 0

        for b in bangunans:
            # Mengambil kode_aset dari DetailLayananBangunan yang terelasi (related_name='layanan_list')
            detail = b.layanan_list.first()
            if detail and detail.kode_aset:
                icon_name = f"{detail.kode_aset}.png"
                full_path = os.path.join(folder_path, icon_name)

                if os.path.exists(full_path):
                    with open(full_path, 'rb') as f:
                        b.icon_png.save(icon_name, File(f), save=True)
                        count += 1
                        self.stdout.write(self.style.SUCCESS(f"Berhasil: {b.nomenklatur_ruas} menggunakan {icon_name}"))
                else:
                    self.stdout.write(self.style.WARNING(f"Skip: Icon {icon_name} tidak ditemukan di folder untuk {b.nomenklatur_ruas}"))

        self.stdout.write(self.style.SUCCESS(f"Selesai! {count} icon berhasil diperbarui."))