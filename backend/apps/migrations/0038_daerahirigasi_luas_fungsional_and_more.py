
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0037_daerahirigasi_jumlah_pintu_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='daerahirigasi',
            name='luas_fungsional',
            field=models.FloatField(default=0, verbose_name='Luas Fungsional (Ha)'),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='luas_potensial',
            field=models.FloatField(default=0, verbose_name='Luas Potensial (Ha)'),
        ),
    ]
