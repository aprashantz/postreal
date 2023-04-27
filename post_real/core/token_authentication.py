from rest_framework import status
from rest_framework import serializers
from rest_framework_simplejwt.views import TokenViewBase
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from post_real.core.log_and_response import generic_response
from post_real.services.send_email import email_verification


class TokenObtainSerializer(TokenObtainPairSerializer):
    """
    Overriding TokenObtainPairSerializer for email verification before obtaining JWT tokens (access and refresh).
    """

    def validate(self, attrs):
        data = super().validate(attrs)
        user = self.user
        if not user.is_email_verified:
            email_verification(user_id=user.id)  # execute this in delay (celery worker) 
            raise serializers.ValidationError({
                "detail": "This account is not verified. Please verify your account with otp sent on your registered email."
            })
        return data


class TokenObtainPairView(TokenViewBase):
    """
    Return JWT tokens (access and refresh).
    """
    serializer_class = TokenObtainSerializer

    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        token = response.data.get('access', None)
        if not token: return response
        return generic_response( 
            success=True,
            message='Token Obtained Successfully',
            data=response.data,
            status=status.HTTP_200_OK
        )