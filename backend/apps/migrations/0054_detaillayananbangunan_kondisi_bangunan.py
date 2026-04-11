
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0053_detaillayananbangunan_surveyor_saluran_surveyor'),
    ]

    operations = [
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='kondisi_bangunan',
            field=models.CharField(choices=[('BAIK', 'Baik'), ('RR', 'Rusak Ringan'), ('RB', 'Rusak Berat')], default='BAIK', max_length=10, verbose_name='Kondisi Fisik Bangunan'),
        ),
    ]
