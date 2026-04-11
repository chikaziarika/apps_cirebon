
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0018_daerahirigasi_latitude_daerahirigasi_longitude_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='daerahirigasi',
            name='is_iksi_calculated',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='is_pai_verified',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='daerahirigasi',
            name='nilai_iksi',
            field=models.FloatField(blank=True, null=True),
        ),
    ]
