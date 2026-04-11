
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0043_saluran_geojson_saluran_geom'),
    ]

    operations = [
        migrations.AlterField(
            model_name='saluran',
            name='geojson',
            field=models.FileField(blank=True, null=True, upload_to='geojson/saluran/', verbose_name='File Spasial (KMZ/GeoJSON)'),
        ),
    ]
