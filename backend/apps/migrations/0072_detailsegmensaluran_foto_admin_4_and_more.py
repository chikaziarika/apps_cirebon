
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0071_detailsegmensaluran_foto_admin_2_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='detailsegmensaluran',
            name='foto_admin_4',
            field=models.ImageField(blank=True, null=True, upload_to='segmen_saluran/', verbose_name='Upload Foto Ke-4'),
        ),
        migrations.AddField(
            model_name='detailsegmensaluran',
            name='foto_admin_5',
            field=models.ImageField(blank=True, null=True, upload_to='segmen_saluran/', verbose_name='Upload Foto Ke-5'),
        ),
    ]
