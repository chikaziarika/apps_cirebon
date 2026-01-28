from django.urls import re_path
from apps.consumers import LiveTrackingConsumer

websocket_urlpatterns = [
    re_path(r'ws/live/$', LiveTrackingConsumer.as_view()),
]