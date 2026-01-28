import json
from channels.generic.websocket import AsyncWebsocketConsumer

class LiveTrackingConsumer(AsyncWebsocketConsumer):
    label_group_name = 'live_location_group'

    async def connect(self):
        # Bergabung ke grup agar data bisa di-broadcast ke semua user
        await self.channel_layer.group_add(
            self.label_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.label_group_name,
            self.channel_name
        )

    # Menerima koordinat dari Flutter
    async def receive(self, text_data):
        data = json.loads(text_data)
        lat = data.get('lat')
        lng = data.get('lng')
        user = data.get('user', 'Surveyor_Unknown')

        # Kirim ulang (broadcast) ke dashboard web secara real-time
        await self.channel_layer.group_send(
            self.label_group_name,
            {
                'type': 'send_location',
                'lat': lat,
                'lng': lng,
                'user': user,
            }
        )

    async def send_location(self, event):
        # Mengirim data ke client (Web Dashboard)
        await self.send(text_data=json.dumps({
            'lat': event['lat'],
            'lng': event['lng'],
            'user': event['user'],
        }))