from django.db import models
from django.utils.translation import gettext_lazy as _


class OwnedModel(models.Model):
    owner = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="%(class)ss",
        verbose_name=_("Owner"),
    )

    class Meta:
        abstract = True


class Account(OwnedModel):
    name = models.CharField(
        _("Name"),
        max_length=255,
    )
    initial_value = models.FloatField(
        _("Initial Value"),
        default=0,
    )
    current_value = models.FloatField(
        _("Value"),
        editable=False,
        blank=True,
    )

    class Meta:
        verbose_name = _("Account")
        verbose_name_plural = _("Accounts")

        unique_together = ["owner", "name"]


class Category(OwnedModel):
    name = models.CharField(
        _("Name"),
        max_length=255,
    )

    class Meta:
        verbose_name = _("Category")
        verbose_name_plural = _("Categories")

        unique_together = ["owner", "name"]


class Transaction(OwnedModel):
    title = models.CharField(
        _("Title"),
        max_length=255,
    )
    description = models.TextField(
        _("Description"),
        max_length=2047,
        blank=True,
    )
    account = models.ForeignKey(
        "core.Account",
        on_delete=models.CASCADE,
        related_name="%(class)ss",
        verbose_name=_("Account"),
    )
    value = models.FloatField(
        _("Value"),
    )
    category = models.ForeignKey(
        "core.Category",
        on_delete=models.SET_NULL,
        null=True,
    )
    date = models.DateField(
        _("Date"),
        auto_created=True,
    )

    class Meta:
        verbose_name = _("Transaction")
        verbose_name_plural = _("Transactions")
