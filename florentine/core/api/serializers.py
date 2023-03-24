from rest_framework import serializers

from florentine.core.models import Account


class AccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = Account
        fields = ("name", "initial_value", "current_value")


class AccountCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Account
        fields = ("owner", "name", "initial_value")
