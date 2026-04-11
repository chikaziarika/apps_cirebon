
import django.contrib.gis.db.models.fields
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0044_alter_saluran_geojson'),
    ]

    operations = [
        migrations.AlterField(
            model_name='saluran',
            name='geom',
            field=django.contrib.gis.db.models.fields.MultiLineStringField(blank=True, null=True, srid=4326),
        ),
    ]
