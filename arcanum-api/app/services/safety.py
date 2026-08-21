"""Guardarrailes duros: lo que ARCANUM se niega a decir, comprobado en codigo.

Los prompts de sistema ya lo piden. Esto lo IMPONE. La diferencia importa
porque un prompt es una peticion al modelo y esto es una comprobacion sobre el
texto real, antes y despues de generar.

Por que existe, en orden de dureza. Todo lo de abajo es LEY o politica de
tienda, no contrato con el proveedor del modelo (ver la nota al final):

1. La Directiva 2005/29/CE, Anexo I, punto 17 hace practica desleal EN
   CUALQUIER CIRCUNSTANCIA proclamar que algo cura enfermedades, sin necesidad
   de probar dano y sin defensa de "era entretenimiento". Y la 2001/83/CE art.
   1(2)(a) convierte en medicamento lo que se PRESENTA como curativo, mire lo
   que mire dentro. Ninguna de las dos admite matices.
2. Google Play, Health Content and Services: prohibe funcionalidades de salud
   enganosas y las declaraciones de salud falsas, y obliga a recordar que se
   consulte a un profesional. En Colombia, el Decreto 3249/2006 prohibe
   presentar indicaciones preventivas o terapeuticas en publicidad.
3. Autolesion y suicidio. Aqui no hay norma que lo obligue con este detalle:
   es criterio propio. No basta con no hablar del tema — hay que salir del
   registro simbolico y derivar a ayuda humana, porque una tirada de tarot
   respondiendo a "no quiero vivir" es exactamente el peor uso posible de esto.

NOTA SOBRE EL PROVEEDOR, y es una correccion a lo que decia este archivo:
ARCANUM usa GROQ, no Anthropic — el nombre `claude_service.py` es herencia. La
AUP de Groq (console.groq.com/docs/legal/ai-policy, consultada el 21-ago-2026)
NO exige avisar de que se habla con una IA, NO menciona autolesion, y sobre
dominios de alto riesgo solo pide supervision humana para DECISIONES
AUTOMATIZADAS con impacto material en derechos individuales. Es mucho menos
exigente que la de Anthropic, que fue la que se cito por error aqui. Nada de
esto rebaja los guardarrailes: la razon de que existan es la de arriba, y esa
no depende de quien sirva el modelo.

Lo que esto NO es: una garantia. Es un suelo. Un filtro por patrones deja pasar
lo que no se le ocurrio a quien lo escribio, y por eso el prompt sigue siendo
la primera linea y esto la segunda. Se declara asi a proposito en vez de
venderlo como resuelto.
"""
from __future__ import annotations

import re
import unicodedata
from typing import Optional

# Motivos. Viajan al llamador para que decida el codigo de estado y el mensaje.
CRISIS = "crisis"
HEALTH = "health"
LEGAL = "legal"
FINANCE = "finance"


def _norm(s: str) -> str:
    """Minusculas sin acentos: quien escribe una crisis no pone tildes."""
    s = unicodedata.normalize("NFKD", s or "")
    return "".join(c for c in s if not unicodedata.combining(c)).lower()


# ── Crisis ───────────────────────────────────────────────────────────────────
#
# Solo intencion en PRIMERA PERSONA. La carta de la Muerte, el simbolismo del
# final y el duelo son materia legitima del tarot: buscar la palabra "muerte"
# haria inutilizable el producto y no protegeria a nadie.
_CRISIS = [
    r"\bme\s+quiero\s+(morir|matar)\b",
    r"\bquiero\s+(morir|matarme|suicidarme)\b",
    r"\bno\s+quiero\s+(vivir|seguir\s+viviendo)\b",
    r"\bvoy\s+a\s+(matarme|suicidarme|quitarme\s+la\s+vida)\b",
    r"\bquitarme\s+la\s+vida\b",
    r"\b(pienso|penso|estoy\s+pensando)\s+en\s+(suicid|matarme)",
    r"\bme\s+(corto|hago\s+dano|autolesion)",
    r"\bacabar\s+con\s+(todo|mi\s+vida)\b",
    r"\bmejor\s+(estaria|estarian)\s+(muerto|muerta|sin\s+mi)\b",
    r"\bsuicid(arme|io\b)",
    r"\bkill\s+myself\b",
    r"\bend\s+my\s+life\b",
]

# ── Peticiones de consejo de alto riesgo ─────────────────────────────────────
#
# Se busca la PETICION DE DECISION, no el tema. "Saturno y mi salud simbolica"
# no es lo mismo que "que tomo para el dolor". El corte es el de la nota de
# riesgo editorial: verbo de uso, posologia, o enfermedad nombrada fuera de
# boca de una fuente historica.
_HEALTH_ASK = [
    r"\bque\s+(me\s+)?(tomo|puedo\s+tomar|debo\s+tomar)\b",
    r"\bcomo\s+(me\s+)?(curo|cura|sano|trato)\b",
    r"\bque\s+(hierba|planta|remedio|infusion)\s+.{0,20}\b(para|contra)\s+(el|la|los|las|mi)\b",
    r"\b(dejo|suspendo|cambio|abandono)\s+(el|mi|la)\s+(tratamiento|medicacion|medicamento|quimio)",
    r"\bes\s+(cancer|un\s+tumor|grave)\b",
    r"\btengo\s+(cancer|vih|sida|un\s+tumor|depresion\s+clinica)\b",
    r"\bme\s+(voy\s+a\s+)?(curar|sanar)\b",
    r"\bdiagnostic",
    r"\bdosis\b",
    r"\bcuant[oa]s?\s+(mg|gramos|gotas|pastillas)\b",
]
_LEGAL_ASK = [
    r"\b(demando|denuncio|firmo|no\s+firmo)\b",
    r"\bque\s+dice\s+la\s+ley\b",
    r"\b(gano|voy\s+a\s+ganar)\s+(el|mi)\s+(juicio|caso|demanda)\b",
    r"\b(me\s+)?(divorcio|separo)\s+legal",
    r"\bcontrato\s+.{0,15}\b(firmo|firmar|conviene)\b",
    r"\bcustodia\b",
]
_FINANCE_ASK = [
    r"\b(invierto|compro|vendo)\s+.{0,25}\b(acciones|bitcoin|cripto|dolares|casa|apartamento)\b",
    r"\bque\s+(accion|cripto|moneda)\s+(compro|subir)",
    r"\b(va\s+a\s+)?(subir|bajar)\s+(el\s+)?(bitcoin|dolar|la\s+bolsa)\b",
    r"\bpido\s+(el\s+)?prestamo\b",
    r"\bme\s+(voy\s+a\s+)?(arruinar|hacer\s+rico)\b",
]

# ── Afirmaciones prohibidas en la SALIDA ─────────────────────────────────────
#
# Aqui el objeto no es el tema sino la FORMA: imperativo de uso, posologia, o
# promesa de curacion. Un texto que atribuye a una fuente ("Culpeper la situa
# bajo Venus") no cae aqui, y no debe caer.
_OUT_FORBIDDEN = [
    # curacion prometida — es la lista negra de la UCPD
    (r"\b(cura|curara|sana|sanara|elimina|previene)\s+(el|la|los|las|tu|su)\s+"
     r"(cancer|diabetes|depresion|ansiedad|enfermedad|dolor|infeccion|tumor)\b", HEALTH),
    (r"\bte\s+(curara|sanara|aliviara)\b", HEALTH),
    # Posologia. El corte es INGESTA o CUERPO, no la cantidad a secas: un rito
    # que unge una vela con tres gotas de aceite es contenido central de
    # ARCANUM, y la primera version de este filtro lo bloqueaba. "Aplica" sobre
    # un objeto (vela, incienso, papel, sigilo) es ritual; sobre una persona es
    # posologia. Por eso el reflexivo (`aplicate`, `untate`) va aparte del
    # transitivo, y `gotas` o `gramos` solos ya no bastan.
    (r"\b(toma|tomate|bebe|bebete|ingiere|traga)\s+.{0,30}\b"
     r"(gotas|mg|ml|gramos|cucharad\w*|pastillas?|capsulas?|comprimidos?|"
     r"veces\s+al\s+dia|"
     r"en\s+ayunas|antes\s+de\s+dormir)\b", HEALTH),
    (r"\b(aplicate|untate|frotate|inhala|inyecta)\b", HEALTH),
    (r"\b(en|sobre)\s+(la\s+herida|la\s+piel|la\s+llaga|el\s+ojo)\b", HEALTH),
    # mg y ml son unidades clinicas: no aparecen en un rito.
    (r"\b\d+\s*(mg|ml|mililitros|miligramos)\b", HEALTH),
    (r"\b(dos|tres|cuatro)?\s*veces\s+al\s+dia\s+.{0,20}\b(toma|bebe|ingiere)\b",
     HEALTH),
    # sustituir tratamiento — prohibicion absoluta, sin excepcion
    (r"\ben\s+(lugar|vez)\s+de\s+(tu|su|el|la)\s+"
     r"(medicamento|medicacion|tratamiento|medico)\b", HEALTH),
    (r"\b(deja|suspende|abandona)\s+(tu|su|el|la)\s+"
     r"(tratamiento|medicacion|medicamento)\b", HEALTH),
    # consejo legal y financiero accionable
    (r"\b(demanda|denuncia)\s+a\s+\w+", LEGAL),
    (r"\bno\s+firmes\b", LEGAL),
    (r"\b(invierte|vende|compra)\s+(en|tus|tu)\s+"
     r"(acciones|bitcoin|cripto|bolsa|casa)\b", FINANCE),
]

_CRISIS_RE = [re.compile(p) for p in _CRISIS]
_ASK_RE = ([(re.compile(p), HEALTH) for p in _HEALTH_ASK]
           + [(re.compile(p), LEGAL) for p in _LEGAL_ASK]
           + [(re.compile(p), FINANCE) for p in _FINANCE_ASK])
_OUT_RE = [(re.compile(p), motivo) for p, motivo in _OUT_FORBIDDEN]


def screen_question(text: Optional[str]) -> Optional[str]:
    """Motivo por el que NO se debe consultar al modelo, o None.

    La crisis se comprueba primero y gana siempre: alguien que escribe que
    quiere morir no recibe una tirada, reciba lo que reciba el resto del texto.
    """
    if not text:
        return None
    t = _norm(text)
    if any(r.search(t) for r in _CRISIS_RE):
        return CRISIS
    for r, motivo in _ASK_RE:
        if r.search(t):
            return motivo
    return None


def screen_output(text: Optional[str]) -> Optional[str]:
    """Motivo por el que un texto YA generado no se puede entregar, o None.

    Segunda linea: el modelo pudo obedecer el prompt y aun asi cruzar. Lo que
    se mira es la forma —imperativo de uso, posologia, promesa de curacion—, no
    el tema, para que la atribucion a una fuente historica siga siendo legal.
    """
    if not text:
        return None
    t = _norm(text)
    for r, motivo in _OUT_RE:
        if r.search(t):
            return motivo
    return None


# Mensajes de cara al usuario: espanol CON acentos, sin culpar a quien pregunta
# y sin fingir que el simbolo puede sustituir a un profesional.
_MESSAGES = {
    CRISIS: (
        "Esto se sale de lo que ARCANUM puede acompañar, y no voy a responderlo "
        "con símbolos. Si estás pensando en hacerte daño, habla hoy con alguien: "
        "en Colombia, la Línea 106; en España, el 024; en otros países, los "
        "servicios locales de emergencia. Si puedes, díselo también a una persona "
        "de confianza que esté cerca."
    ),
    HEALTH: (
        "El oráculo no da orientación de salud. Puede hablar del símbolo, no del "
        "cuerpo: para eso hace falta un profesional sanitario que te escuche y te "
        "examine."
    ),
    LEGAL: (
        "El oráculo no da orientación legal. Una decisión con consecuencias "
        "jurídicas necesita a alguien que conozca tu caso y la ley que te aplica."
    ),
    FINANCE: (
        "El oráculo no da orientación financiera. Puede leer el símbolo del "
        "recurso y del límite, no decirte qué hacer con tu dinero."
    ),
}


def message_for(reason: str) -> str:
    """Texto que ve la persona. Nunca la traza ni el nombre del motivo."""
    return _MESSAGES.get(reason, _MESSAGES[HEALTH])


# ── Divulgacion de IA ────────────────────────────────────────────────────────
#
# Obligacion LEGAL, y de una sola fuente: AI Act (UE) art. 50(1), aplicable
# desde el 2 de agosto de 2026 — "natural persons concerned are informed that
# they are interacting with an AI system" — con el plazo del 50(5): "at the
# latest at the time of the first interaction or exposure".
#
# Correccion del 21-ago-2026: aqui se citaba tambien la AUP de Anthropic como
# obligacion contractual. NO aplica — ARCANUM usa Groq, y la AUP de Groq no
# exige esta divulgacion. La obligacion sobrevive entera de todas formas, porque
# el art. 50(1) no depende del proveedor sino de quien pone el sistema en el
# mercado, y la beta sale sin geo-restriccion.
#
# Viaja en la RESPUESTA y no solo en los Terminos: un aviso que la persona
# acepto una vez al instalar no acompana a la lectura de dentro de seis meses.
GROQ_PROVIDER = "Groq, Inc."
GROQ_COUNTRY = "Estados Unidos"

AI_DISCLOSURE = (
    "Este texto lo redacta una inteligencia artificial a partir de tu carta y "
    "del cielo real. Es contenido simbólico y cultural: no sustituye "
    "orientación médica, psicológica, legal ni financiera."
)
