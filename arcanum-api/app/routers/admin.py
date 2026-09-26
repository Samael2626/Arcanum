"""
Admin endpoints (protegidos).
- GET /admin/migrate/status — verifica estado de migraciones
- POST /admin/migrate — ejecuta migraciones pendientes
"""

from fastapi import APIRouter, Depends, HTTPException, status
from app.core.config import settings
from app.db.session import get_engine
from app.db.migrate import run_migrations, check_migration_status
from app.api.deps import require_migrations_enabled, verify_admin_token

# La autenticacion va en el router, no dentro de cada funcion. Antes se
# llamaba a `verify_admin_token(...)` en el cuerpo: funcionaba, pero no
# aparecia como protegido en OpenAPI y el endpoint que se anadiese manana
# podia olvidarlo sin que nada avisara. Declarado aqui, no hay forma de
# colgar una ruta de este router sin token.
#
# Y APAGADO POR DEFECTO desde el 26-sep-2026. `require_migrations_enabled` va
# PRIMERO en la lista: se evalua antes que el token, asi que con la bandera en
# false estas rutas responden 404 sin llegar a mirar la cabecera. Produccion no
# las necesita -- `start.sh` migra en cada arranque --, y lo que aportaban era
# superficie: DDL contra la base de produccion a un HTTP de distancia.
router = APIRouter(prefix="/admin", tags=["admin"],
                   dependencies=[Depends(require_migrations_enabled),
                                 Depends(verify_admin_token)])


@router.get("/migrate/status")
def get_migration_status():
    """
    Verifica estado de migraciones sin ejecutarlas.
    Header: X-Admin-Token: <token>
    """
    result = check_migration_status(get_engine())
    return result


@router.post("/migrate")
def execute_migrations():
    """
    Ejecuta migraciones pendientes.
    Header: X-Admin-Token: <token>

    ADVERTENCIA: Esto es destructivo en downgrade. Use con cuidado en prod.
    """

    # Primero, verifica estado actual
    status_before = check_migration_status(get_engine())
    if status_before.get("status") == "error":
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"No se pudo verificar estado: {status_before.get('message')}",
        )

    # Ejecuta migraciones
    result = run_migrations(get_engine())

    if result.get("status") == "error":
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get("message"),
        )

    # Verifica estado después
    status_after = check_migration_status(get_engine())

    return {
        "status": "success",
        "message": result.get("message"),
        "before": status_before,
        "after": status_after,
    }


