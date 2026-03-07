# apps/urls.py
from django.urls import path
from . import views
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    # --- HALAMAN WEB (HTML Views) ---
    path('', views.dashboard, name='dashboard'),
    path('peta/', views.peta_irigasi, name='peta_irigasi'),
    path('pelaporan/', views.pelaporan, name='pelaporan'),
    path('upload-konjar/', views.upload_konjar_view, name='upload-konjar'),
    path('laporan/rekap-aset/<int:di_id>/', views.cetak_rekap_aset, name='rekap_aset_pdf'),
    path('get-di-stats/<int:di_id>/', views.get_di_stats, name='get-di-stats'),

    # --- API UNTUK WEB DASHBOARD (JSON) ---
    path('api/saluran/<int:di_id>/', views.api_saluran_list, name='api-saluran-list'),
    path('api/bangunan/<int:di_id>/', views.api_bangunan_list, name='api-bangunan-list'),
    path('api/daerah-irigasi/', views.api_daerah_irigasi_all, name='api-di-all'),
    path('api/geojson/<str:type_source>/<int:data_id>/', views.api_get_geojson, name='get_geojson_api'),

    # --- API UNTUK MOBILE (Flutter Sync) ---
    path('api/login/', views.api_login, name='api_login'),
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # Endpoint Utama Sinkronisasi
    path('api/sync/saluran/', views.api_sync_saluran, name='api_sync_saluran'),
    path('api/sync/bangunan/', views.api_sync_bangunan, name='api_sync_bangunan'), # <--- WAJIB TAMBAH INI
    path('api/sync/daerah-irigasi/', views.api_sync_di, name='api_sync_di'),
    
    # Backup upload sederhana (jika masih dipakai)
    path('upload-survey/', views.api_upload_survey, name='api_upload_survey'),
    path('api/layer-pendukung/', views.api_layer_pendukung_all, name='api-layer-pendukung-all'),
    path('api/bangunan/all/', views.api_bangunan_all, name='api-bangunan-all'),
]