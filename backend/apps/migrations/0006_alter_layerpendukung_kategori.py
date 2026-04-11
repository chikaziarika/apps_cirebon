
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0005_layerpendukung'),
    ]

    operations = [
        migrations.AlterField(
            model_name='layerpendukung',
            name='kategori',
            field=models.CharField(choices=[('wilayah', 'Batas Wilayah'), ('jalan', 'Jaringan Jalan'), ('irigasi', 'Jaringan Irigasi (Saluran)'), ('lahan', 'Luasan Areal Fungsional'), ('air', 'Sumber Air / Waduk')], max_length=50),
        ),
    ]
