# apps/urls.py
from django.urls import path
from . import views

urlpatterns = [

    path('upload-survey/', views.api_upload_survey, name='api_upload_survey'),
    # Halaman Utama Dashboard
    path('', views.dashboard, name='dashboard'),
    
    
    path('peta/', views.peta_irigasi, name='peta_irigasi'),
    # Modul Peta
    path('peta/', views.peta_irigasi, name='peta'),
    
    # Modul Pelaporan
    path('pelaporan/', views.pelaporan, name='pelaporan'),



]