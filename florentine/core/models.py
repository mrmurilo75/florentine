from django.core.exceptions import NON_FIELD_ERRORS, ValidationError
from django.db import models, transaction
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

    def __str__(self):
        return self.name

    def clean(self):
        super().clean()

        if self.current_value is None:
            self.current_value = self.initial_value


class Category(OwnedModel):
    name = models.CharField(
        _("Name"),
        max_length=255,
    )

    class Meta:
        verbose_name = _("Category")
        verbose_name_plural = _("Categories")

        unique_together = ["owner", "name"]

    def __str__(self):
        return self.name


class Transaction(models.Model):
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

    def __str__(self):
        return f"{self.title} ({self.date})"

    def save(
        self, force_insert=False, force_update=False, using=None, update_fields=None
    ):
        with transaction.atomic(using=using):
            account = (
                Account.objects.using(using).select_for_update().get(id=self.account_id)
            )
            if self.id:
                previous = (
                    Transaction.objects.using(using).select_for_update().get(id=self.id)
                )
                account.current_value += self.value - previous.value
            else:
                account.current_value += self.value

            super().save(force_insert, force_update, using, update_fields)
            account.save()

    def delete(self, using=None, keep_parents=False):
        with transaction.atomic(using=using):
            account = (
                Account.objects.using(using).select_for_update().get(id=self.account_id)
            )
            account.current_value -= self.value

            super().delete(using, keep_parents)
            account.save()

    @property
    def is_deposit(self):
        return self.value > 0

    @property
    def is_withdraw(self):
        return self.value > 0


class Transfer(models.Model):
    transaction_in = models.OneToOneField(
        Transaction,
        on_delete=models.PROTECT,
        related_name="%(class)s_in",
        verbose_name=_("Transfer Deposit"),
    )
    transaction_out = models.OneToOneField(
        Transaction,
        on_delete=models.PROTECT,
        related_name="%(class)s_out",
        verbose_name=_("Transfer Withdraw"),
    )

    def clean(self):
        super().clean()

        errors = dict()
        if not self.transaction_in.is_deposit:
            errors["transaction_in"] = ValidationError(
                _("Transfer Deposit must be a deposit."), code="invalid"
            )
        if not self.transaction_out.is_withdraw:
            errors["transaction_in"] = ValidationError(
                _("Transfer Withdraw must be a withdraw."), code="invalid"
            )
        if not self.transaction_in.value == -self.transaction_out.value:
            errors[NON_FIELD_ERRORS] = ValidationError(
                f"Expected transactions of transfer to have inverse values, "
                f"but got {self.transaction_in.value} and {self.transaction_out.value} .",
                code="invalid",
            )

        if errors:
            raise ValidationError(errors)
