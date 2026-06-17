from datetime import timedelta
from app.core import security


def test_password_hashing():
    password = "secretmagicpwd123"
    hashed = security.get_password_hash(password)
    assert hashed != password
    assert security.verify_password(password, hashed) is True
    assert security.verify_password("wrongpwd", hashed) is False


def test_access_token_creation_and_verification():
    data = {"sub": "wizard@arcanum.com"}
    token = security.create_access_token(data)
    
    # Verificar token
    payload = security.verify_token(token, token_type="access")
    assert payload is not None
    assert payload["sub"] == "wizard@arcanum.com"
    assert payload["type"] == "access"


def test_refresh_token_creation_and_verification():
    data = {"sub": "druid@arcanum.com"}
    token = security.create_refresh_token(data)
    
    # Verificar token
    payload = security.verify_token(token, token_type="refresh")
    assert payload is not None
    assert payload["sub"] == "druid@arcanum.com"
    assert payload["type"] == "refresh"


def test_invalid_token_type():
    data = {"sub": "alchemist@arcanum.com"}
    access_token = security.create_access_token(data)
    
    # Validar un access token como si fuera refresh token debe fallar
    payload = security.verify_token(access_token, token_type="refresh")
    assert payload is None


def test_token_blacklist(mock_redis):
    token = "some-dummy-jwt-token-string"
    
    # No debe estar blacklisted inicialmente
    assert security.is_token_blacklisted(token) is False
    
    # Blacklistear token
    security.blacklist_token(token, expires_in=100)
    
    # Ahora debe estar blacklisted
    assert security.is_token_blacklisted(token) is True
