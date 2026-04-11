
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0030_jenispintu'),
    ]

    operations = [
        migrations.AlterModelOptions(
            name='jenispintu',
            options={},
        ),
        migrations.RemoveField(
            model_name='detaillayananbangunan',
            name='pintu_jenis',
        ),
        migrations.AddField(
            model_name='detaillayananbangunan',
            name='jenis_pintu',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to='apps.jenispintu', verbose_name='Jenis Pintu'),
        ),
    ]
