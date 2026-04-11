
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0022_rename_jumlah_pintu_bangunan_pintu_total_unit_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='daerahirigasi',
            name='total_luas_fungsional',
            field=models.FloatField(default=0),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='total_panjang_jaringan',
            field=models.FloatField(default=0),
        ),
    ]
