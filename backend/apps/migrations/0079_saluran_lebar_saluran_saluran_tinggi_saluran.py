
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0078_remove_detaillayananbangunan_poligon_layanan_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='saluran',
            name='lebar_saluran',
            field=models.FloatField(default=0, verbose_name='Lebar Saluran (m)'),
        ),
        migrations.AddField(
            model_name='saluran',
            name='tinggi_saluran',
            field=models.FloatField(default=0, verbose_name='Tinggi Saluran (m)'),
        ),
    ]
