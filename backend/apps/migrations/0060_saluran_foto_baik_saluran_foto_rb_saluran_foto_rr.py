
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0059_saluran_keterangan_baik_saluran_keterangan_rb_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='saluran',
            name='foto_baik',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='saluran',
            name='foto_rb',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='saluran',
            name='foto_rr',
            field=models.TextField(blank=True, null=True),
        ),
    ]
