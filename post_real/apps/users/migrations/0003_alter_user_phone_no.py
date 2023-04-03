# Generated by Django 4.0.6 on 2023-04-03 19:46

import django.core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0002_alter_user_email_alter_user_id_alter_user_username'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='phone_no',
            field=models.CharField(blank=True, max_length=15, null=True, validators=[django.core.validators.RegexValidator('^[0-9-+]+$', 'Invalid Mobile Number'), django.core.validators.MinLengthValidator(10)], verbose_name='phone no.'),
        ),
    ]
