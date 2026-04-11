
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0038_daerahirigasi_luas_fungsional_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='daerahirigasi',
            name='geojson',
            field=models.FileField(blank=True, null=True, upload_to='geojson/di/'),
        ),
    ]
