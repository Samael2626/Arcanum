"""Servicio para interactuar con la API de Anthropic (Claude)."""
import os
from typing import Optional
import anthropic

# Inicializa el cliente de Anthropic usando la variable de entorno ANTHROPIC_API_KEY
_api_key = os.getenv("ANTHROPIC_API_KEY")
if not _api_key:
    # En desarrollo, se puede advertir pero no fallar si la variable no está establecida.
    # En producción, debería lanzarse una excepción o configurarse adecuadamente.
    _client = None
else:
    _client = anthropic.Anthropic(api_key=_api_key)

def get_claude_response(context: str, question: str) -> str:
    """
    Envía un contexto y una pregunta a Claude y devuelve la respuesta.
    El contexto puede incluir natal chart, fase lunar, hora planetaria, etc.
    """
    if _client is None:
        # Fallback para desarrollo sin API key configurada.
        return "[Modo desarrollo] Respuesta de Claude no disponible. Configure ANTHROPIC_API_KEY."

    # Construimos el prompt para el modelo.
    prompt = f"""Contexto del usuario:
{context}

Pregunta del usuario:
{question}

Por favor, responde como un oráculo ritual, utilizando el contexto proporcionado para dar una respuesta significativa y acorde con la tradición esotérica."""

    try:
        message = _client.messages.create(
            model="claude-3-5-sonnet-20241022",  # o el modelo más reciente disponible
            max_tokens=1024,
            temperature=0.7,
            system="Eres un oráculo experto en tradiciones esotéricas, astrología y rituales. Tu respuesta debe ser profunda, simbólica y útil para el usuario.",
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        # Extraemos el texto de la respuesta.
        if message.content and len(message.content) > 0:
            # Asumimos que el primer bloque es texto.
            return message.content[0].text if hasattr(message.content[0], 'text') else str(message.content[0])
        else:
            return "[Error] Claude no devolvió contenido."
    except Exception as e:
        # En caso de error, devolvemos un mensaje amigable.
        return f"[Error al consultar a Claude: {str(e)}]"