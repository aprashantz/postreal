# Generated by Django 4.2 on 2023-04-11 17:37

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0002_connection"),
    ]

    operations = [
        migrations.AlterField(
            model_name="connection",
            name="is_active",
            field=models.BooleanField(default=True, editable=False),
        ),
        migrations.AlterUniqueTogether(
            name="connection",
            unique_together={("user_id", "following_user_id")},
        ),
    ]
