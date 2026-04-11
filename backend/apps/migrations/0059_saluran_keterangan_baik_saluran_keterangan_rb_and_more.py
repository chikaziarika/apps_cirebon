
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0058_alter_saluran_kode_aset_saluran'),
    ]

    operations = [
        migrations.AddField(
            model_name='saluran',
            name='keterangan_baik',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='saluran',
            name='keterangan_rb',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='saluran',
            name='keterangan_rr',
            field=models.TextField(blank=True, null=True),
        ),
    ]
