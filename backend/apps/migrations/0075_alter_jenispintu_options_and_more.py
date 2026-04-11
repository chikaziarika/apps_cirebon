
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0074_detaillayananbangunan_jenis_saluran_kanan_and_more'),
    ]

    operations = [
        migrations.AlterModelOptions(
            name='jenispintu',
            options={'verbose_name': '5. JENIS PINTU', 'verbose_name_plural': '5. JENIS PINTU'},
        ),
        migrations.AlterModelOptions(
            name='layerpendukung',
            options={'verbose_name': '6. LAYER PENDUKUNG', 'verbose_name_plural': '6. LAYER PENDUKUNG'},
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='jenis_saluran_kanan',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='jenis_saluran_kiri',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='jenis_saluran_tengah',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='luas_kanan',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='luas_kiri',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='luas_tengah',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='nomenklatur_kanan',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='nomenklatur_kiri',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='nomenklatur_tengah',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='saluran_manual_kanan',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='saluran_manual_kiri',
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='saluran_manual_tengah',
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='jenis_saluran_kanan',
            field=models.CharField(choices=[('INDUK', 'Saluran Induk'), ('SEKUNDER', 'Saluran Sekunder'), ('TERSIER', 'Saluran Tersier'), ('PENGURAS', 'Saluran Penguras'), ('MANUAL', 'Input Manual')], default='TERSIER', max_length=20, verbose_name='Jns Saluran Kanan'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='jenis_saluran_kiri',
            field=models.CharField(choices=[('INDUK', 'Saluran Induk'), ('SEKUNDER', 'Saluran Sekunder'), ('TERSIER', 'Saluran Tersier'), ('PENGURAS', 'Saluran Penguras'), ('MANUAL', 'Input Manual')], default='TERSIER', max_length=20, verbose_name='Jns Saluran Kiri'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='jenis_saluran_tengah',
            field=models.CharField(choices=[('INDUK', 'Saluran Induk'), ('SEKUNDER', 'Saluran Sekunder'), ('TERSIER', 'Saluran Tersier'), ('PENGURAS', 'Saluran Penguras'), ('MANUAL', 'Input Manual')], default='INDUK', max_length=20, verbose_name='Jns Saluran Tengah'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='luas_kanan',
            field=models.FloatField(default=0, verbose_name='Luas Kanan (Ha)'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='luas_kiri',
            field=models.FloatField(default=0, verbose_name='Luas Kiri (Ha)'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='luas_tengah',
            field=models.FloatField(default=0, verbose_name='Luas Tengah (Ha)'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='nomenklatur_kanan',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Nom Pintu Kanan'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='nomenklatur_kiri',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Nom Pintu Kiri'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='nomenklatur_tengah',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Nom Tengah'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='saluran_manual_kanan',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Saluran Kanan (Mnl)'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='saluran_manual_kiri',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Saluran Kiri (Mnl)'),
        ),
        migrations.AddField(
            model_name='unitpintubangunan',
            name='saluran_manual_tengah',
            field=models.CharField(blank=True, max_length=100, null=True, verbose_name='Saluran Tengah (Mnl)'),
        ),
    ]
