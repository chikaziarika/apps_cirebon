
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0075_alter_jenispintu_options_and_more'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='jenis_saluran_kanan',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='jenis_saluran_kiri',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='jenis_saluran_tengah',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='luas_kanan',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='luas_kiri',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='luas_tengah',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='nomenklatur_kanan',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='nomenklatur_kiri',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='nomenklatur_tengah',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='saluran_manual_kanan',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='saluran_manual_kiri',
        ),
        migrations.RemoveField(
            model_name='unitpintubangunan',
            name='saluran_manual_tengah',
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='jenis_saluran_kanan',
            field=models.CharField(choices=[('INDUK', 'Saluran Induk'), ('SEKUNDER', 'Saluran Sekunder'), ('TERSIER', 'Saluran Tersier'), ('PENGURAS', 'Saluran Penguras'), ('MANUAL', 'Input Manual')], default='TERSIER', max_length=20, verbose_name='Jenis Saluran'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='jenis_saluran_kiri',
            field=models.CharField(choices=[('INDUK', 'Saluran Induk'), ('SEKUNDER', 'Saluran Sekunder'), ('TERSIER', 'Saluran Tersier'), ('PENGURAS', 'Saluran Penguras'), ('MANUAL', 'Input Manual')], default='TERSIER', max_length=20, verbose_name='Jenis Saluran'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='jenis_saluran_tengah',
            field=models.CharField(choices=[('INDUK', 'Saluran Induk'), ('SEKUNDER', 'Saluran Sekunder'), ('TERSIER', 'Saluran Tersier'), ('PENGURAS', 'Saluran Penguras'), ('MANUAL', 'Input Manual')], default='INDUK', max_length=20, verbose_name='Jenis Saluran'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='luas_kanan',
            field=models.FloatField(default=0, verbose_name='Luas Areal (Ha)'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='luas_kiri',
            field=models.FloatField(default=0, verbose_name='Luas Areal (Ha)'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='luas_tengah',
            field=models.FloatField(default=0, verbose_name='Luas Areal (Ha)'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='nomenklatur_kanan',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Nomenklatur'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='nomenklatur_kiri',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Nomenklatur'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='nomenklatur_tengah',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Nomenklatur'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='saluran_manual_kanan',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Input Nama'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='saluran_manual_kiri',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Input Nama'),
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='saluran_manual_tengah',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Input Nama'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='nama_pintu',
            field=models.CharField(default=1, help_text='Akan terisi otomatis dari Nomenklatur Ruas', max_length=150, verbose_name='Nama Pintu'),
            preserve_default=False,
        ),
    ]
