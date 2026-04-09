# from django.apps import AppConfig


# class AppsConfig(AppConfig):
#     name = 'apps'


# apps/apps.py
from django.apps import AppConfig
from django.db.models.signals import post_migrate
import os

def otomatis_update_domain(sender, **kwargs):
    """
    Fungsi ini akan dijalankan otomatis oleh Django SETIAP KALI 
    perintah 'python manage.py migrate' selesai dieksekusi.
    """
    # Import model dilakukan di dalam fungsi untuk mencegah error "AppRegistryNotReady"
    from django.contrib.sites.models import Site
    from django.conf import settings
    
    # Ambil domain dari file .env. Jika lupa diisi, gunakan localhost:8000 sebagai cadangan
    domain_env = os.getenv('DOMAIN_NAME', 'localhost:8000')
    nama_aplikasi = 'SIRIGASI'
    
    # Cari Site dengan ID 1 (sesuai SITE_ID di settings.py) dan paksa ubah datanya
    Site.objects.filter(id=settings.SITE_ID).update(domain=domain_env, name=nama_aplikasi)
    print(f"✅ [SYSTEM] Domain Site otomatis disetel ke: {domain_env}")

class AppsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps' # Pastikan ini sesuai dengan nama folder aplikasi Anda

    def ready(self):
        # Hubungkan fungsi otomatis_update_domain ke sinyal post_migrate
        post_migrate.connect(otomatis_update_domain, sender=self)