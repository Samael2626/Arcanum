import pytest
from app.models.user import User
from app.models.refresh_token import RefreshToken


def test_register_user(client):
    response = client.post(
        "/auth/register",
        json={
            "email": "test@arcanum.com",
            "password": "supersecurepassword123",
            "display_name": "Mystic Apprentice",
            "preferred_tradition": "hermeticism"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@arcanum.com"
    assert data["display_name"] == "Mystic Apprentice"
    assert data["preferred_tradition"] == "hermeticism"
    assert "id" in data


def test_register_duplicate_email(client):
    payload = {
        "email": "duplicate@arcanum.com",
        "password": "password123",
        "display_name": "Apprentice A"
    }
    
    # Primer registro
    response1 = client.post("/auth/register", json=payload)
    assert response1.status_code == 201

    # Segundo registro con mismo email
    response2 = client.post("/auth/register", json=payload)
    assert response2.status_code == 400
    assert response2.json()["detail"] == "Este email ya está registrado"


def test_login_user(client):
    # Primero registrar
    client.post(
        "/auth/register",
        json={
            "email": "login@arcanum.com",
            "password": "loginpassword123",
            "display_name": "Login User"
        }
    )

    # Login exitoso
    response = client.post(
        "/auth/login",
        data={
            "username": "login@arcanum.com",
            "password": "loginpassword123"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert "expires_in" in data


def test_login_invalid_credentials(client):
    response = client.post(
        "/auth/login",
        data={
            "username": "nonexistent@arcanum.com",
            "password": "invalidpassword"
        }
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Email o contraseña incorrectos"


def test_refresh_token_rotation(client, db_session):
    # Registrar y loguear
    client.post(
        "/auth/register",
        json={
            "email": "refresh@arcanum.com",
            "password": "refreshpassword123"
        }
    )
    login_resp = client.post(
        "/auth/login",
        data={
            "username": "refresh@arcanum.com",
            "password": "refreshpassword123"
        }
    )
    tokens = login_resp.json()
    old_refresh = tokens["refresh_token"]

    # Verificar que el refresh token se guardó en la base de datos
    db_tokens_count = db_session.query(RefreshToken).count()
    assert db_tokens_count == 1

    # Refrescar tokens
    refresh_resp = client.post(
        "/auth/refresh",
        json={"refresh_token": old_refresh}
    )
    assert refresh_resp.status_code == 200
    new_tokens = refresh_resp.json()
    assert "access_token" in new_tokens
    assert "refresh_token" in new_tokens
    
    # El token viejo debería haber sido eliminado por rotation strategy
    new_refresh = new_tokens["refresh_token"]
    assert new_refresh != old_refresh
    
    # Aún debe haber solo 1 token en la BD (el nuevo sustituye al viejo)
    db_tokens = db_session.query(RefreshToken).all()
    assert len(db_tokens) == 1


def test_refresh_token_invalid_or_revoked(client):
    response = client.post(
        "/auth/refresh",
        json={"refresh_token": "some-invalid-refresh-token"}
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Refresh token inválido o revocado"


def test_get_current_user_me(client):
    email = "me@arcanum.com"
    password = "mepassword123"
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "Me User"
        }
    )
    
    login_resp = client.post(
        "/auth/login",
        data={
            "username": email,
            "password": password
        }
    )
    access_token = login_resp.json()["access_token"]

    # Obtener perfil autenticado
    response = client.get(
        "/users/me",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == email
    assert data["display_name"] == "Me User"


def test_logout_revokes_refresh_token(client, db_session):
    email = "logout@arcanum.com"
    password = "logoutpassword123"
    
    client.post(
        "/auth/register",
        json={"email": email, "password": password}
    )
    
    login_resp = client.post(
        "/auth/login",
        data={"username": email, "password": password}
    )
    tokens = login_resp.json()
    access_token = tokens["access_token"]
    refresh_token = tokens["refresh_token"]
    
    # Verificar que el token existe en la DB
    assert db_session.query(RefreshToken).count() == 1
    
    # Logout pasándole el refresh_token en el cuerpo y el access_token en el header de autenticación
    logout_resp = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"refresh_token": refresh_token}
    )
    assert logout_resp.status_code == 204

    # El refresh token debe haber sido eliminado de la BD
    assert db_session.query(RefreshToken).count() == 0


def test_update_me_cannot_escalate_subscription(client):
    """Regresión: PUT /users/me NO debe permitir auto-otorgarse premium
    ni tocar campos server-controlled (mass-assignment / escalada de privilegios)."""
    email = "escalate@arcanum.com"
    password = "escalatepass123"
    client.post("/auth/register", json={"email": email, "password": password})
    access_token = client.post(
        "/auth/login", data={"username": email, "password": password}
    ).json()["access_token"]

    resp = client.put(
        "/users/me",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "display_name": "Hacker",
            "subscription_tier": "premium",
            "revenuecat_customer_id": "fake_cus_123",
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["display_name"] == "Hacker"          # campo legítimo sí cambia
    assert data["subscription_tier"] == "free"        # NO se escala
    assert data["revenuecat_customer_id"] is None     # NO se inyecta


def test_login_rate_limited(client):
    """El 6º intento de login dentro de la ventana debe devolver 429 (límite 5/min)."""
    creds = {"username": "ratelimit@arcanum.com", "password": "whatever123"}
    codes = [client.post("/auth/login", data=creds).status_code for _ in range(6)]
    assert codes[:5] == [401] * 5      # los primeros 5 pasan el limiter (credenciales inválidas)
    assert codes[5] == 429             # el 6º es bloqueado
