
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0008_daerahirigasi_file_geojson_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='daerahirigasi',
            name='file_geojson',
            field=models.FileField(blank=True, null=True, upload_to='geojson/di/'),
        ),
    ]
