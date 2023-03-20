from django.contrib import admin

from florentine.core.models import Account, Category, Transaction


@admin.register(Account)
class AccountAdmin(admin.ModelAdmin):
    list_display = ("name", "current_value")
    list_filter = ("owner",)


admin.site.register(Category)
admin.site.register(Transaction)
