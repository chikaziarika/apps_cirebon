
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0076_remove_unitpintubangunan_jenis_saluran_kanan_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='daerahirigasi',
            name='panjang_tersier',
            field=models.FloatField(default=0, verbose_name='Total Panjang Tersier (m)'),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='tersier_baik',
            field=models.FloatField(default=0, verbose_name='Tersier Baik (m)'),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='tersier_bap',
            field=models.FloatField(default=0, verbose_name='Tersier Belum Ada Pasangan (m)'),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='tersier_rb',
            field=models.FloatField(default=0, verbose_name='Tersier Rusak Berat (m)'),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='tersier_rr',
            field=models.FloatField(default=0, verbose_name='Tersier Rusak Ringan (m)'),
        ),
    ]
