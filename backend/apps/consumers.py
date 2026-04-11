import json
from channels.generic.websocket import AsyncWebsocketConsumer

class LiveTrackingConsumer(AsyncWebsocketConsumer):
    label_group_name = 'live_location_group'

    async def connect(self):
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
    async def receive(self, text_data):
        data = json.loads(text_data)
        lat = data.get('lat')
        lng = data.get('lng')
        user = data.get('user', 'Surveyor_Unknown')
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
        await self.send(text_data=json.dumps({
            'lat': event['lat'],
            'lng': event['lng'],
            'user': event['user'],
        }))