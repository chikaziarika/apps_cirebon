from django.apps import AppConfig
from django.db.models.signals import post_migrate
import os

def otomatis_update_domain(sender, **kwargs):
    """
    Fungsi ini akan dijalankan otomatis oleh Django SETIAP KALI 
    perintah 'python manage.py migrate' selesai dieksekusi.
    """
    from django.contrib.sites.models import Site
    from django.conf import settings
    domain_env = os.getenv('DOMAIN_NAME', 'localhost:8000')
    nama_aplikasi = 'SIRIGASI'
    Site.objects.filter(id=settings.SITE_ID).update(domain=domain_env, name=nama_aplikasi)
    print(f"✅ [SYSTEM] Domain Site otomatis disetel ke: {domain_env}")

class AppsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps' 
    verbose_name = '1. DATA OPERASIONAL SIRIGASI'

    def ready(self):
        post_migrate.connect(otomatis_update_domain, sender=self)