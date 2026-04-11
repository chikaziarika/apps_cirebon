
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0017_asetsaluran'),
    ]

    operations = [
        migrations.AddField(
            model_name='daerahirigasi',
            name='latitude',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='longitude',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='daerahirigasi',
            name='geojson',
            field=models.FileField(blank=True, null=True, upload_to='geojson/di/'),
        ),
    ]
