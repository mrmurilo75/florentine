from django.contrib.auth.models import AbstractUser, UserManager
from django.db.models import CharField, EmailField
from django.urls import reverse
from django.utils.translation import gettext_lazy as _


class EmailUserManager(UserManager):
    def _create_user(self, username, email, password, **extra_fields):
        if not email:  # Only change: check email
            raise ValueError(_("The given email must be set."))

        return super()._create_user(username, email, password, **extra_fields)

    def create_superuser(self, username=None, *args, **kwargs):
        return super().create_superuser(username=kwargs.get("email"), *args, **kwargs)


class User(AbstractUser):
    """
    Default custom user model for Florentine: Money Tracker.
    If adding fields that need to be filled at user signup,
    check forms.SignupForm and forms.SocialSignupForms accordingly.
    """

    #: First and last name do not cover name patterns around the globe
    name = CharField(_("Name of User"), blank=True, max_length=255)
    first_name = None  # type: ignore
    last_name = None  # type: ignore

    email = EmailField(_("email address"), unique=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = EmailUserManager()

    def __str__(self):
        return self.email

    def get_absolute_url(self):
        """Get url for user's detail view.

        Returns:
            str: URL for user detail.

        """
        return reverse("users:detail", kwargs={"username": self.username})
