
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0069_alter_detailsegmensaluran_geom'),
    ]

    operations = [
        migrations.CreateModel(
            name='FotoSegmen',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('foto', models.ImageField(upload_to='segmen_saluran/galeri/', verbose_name='File Foto')),
                ('keterangan', models.CharField(blank=True, max_length=255, null=True, verbose_name='Keterangan Foto')),
                ('segmen', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='galeri_foto', to='apps.detailsegmensaluran', verbose_name='Segmen Saluran')),
            ],
            options={
                'verbose_name': 'Foto Tambahan Segmen',
                'verbose_name_plural': 'Galeri Foto Segmen',
            },
        ),
    ]
