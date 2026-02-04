from django.urls import re_path
from . import consumers 

websocket_urlpatterns = [
    # Ganti 'ws/main/' sesuai kebutuhan frontend
    re_path(r'ws/main/$', consumers.IrigasiConsumer.as_async()),
]