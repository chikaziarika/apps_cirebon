
import django.contrib.gis.db.models.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0042_alter_detaillayananbangunan_kode_aset'),
    ]

    operations = [
        migrations.AddField(
            model_name='saluran',
            name='geojson',
            field=models.FileField(blank=True, null=True, upload_to='geojson/saluran/'),
        ),
        migrations.AddField(
            model_name='saluran',
            name='geom',
            field=django.contrib.gis.db.models.fields.LineStringField(blank=True, null=True, srid=4326),
        ),
    ]
