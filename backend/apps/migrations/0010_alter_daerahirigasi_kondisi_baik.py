
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0009_alter_daerahirigasi_file_geojson'),
    ]

    operations = [
        migrations.AlterField(
            model_name='daerahirigasi',
            name='kondisi_baik',
            field=models.FloatField(default=0),
        ),
    ]
