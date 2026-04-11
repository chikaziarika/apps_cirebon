
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0065_alter_detaillayananbangunan_is_saluran_berlanjut_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='layerpendukung',
            name='warna_garis',
            field=models.CharField(default='#3388ff', max_length=7),
        ),
    ]
