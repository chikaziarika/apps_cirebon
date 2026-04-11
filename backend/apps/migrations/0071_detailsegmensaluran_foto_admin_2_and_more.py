
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('apps', '0070_fotosegmen'),
    ]

    operations = [
        migrations.AddField(
            model_name='detailsegmensaluran',
            name='foto_admin_2',
            field=models.ImageField(blank=True, null=True, upload_to='segmen_saluran/', verbose_name='Upload Foto Ke-2'),
        ),
        migrations.AddField(
            model_name='detailsegmensaluran',
            name='foto_admin_3',
            field=models.ImageField(blank=True, null=True, upload_to='segmen_saluran/', verbose_name='Upload Foto Ke-3'),
        ),
        migrations.AlterField(
            model_name='detailsegmensaluran',
            name='foto_admin',
            field=models.ImageField(blank=True, null=True, upload_to='segmen_saluran/', verbose_name='Upload Foto Utama'),
        ),
        migrations.DeleteModel(
            name='FotoSegmen',
        ),
    ]
