"""Guardarrailes duros: lo que ARCANUM se niega a decir, comprobado en codigo.

Los prompts de sistema ya lo piden. Esto lo IMPONE. La diferencia importa
porque un prompt es una peticion al modelo y esto es una comprobacion sobre el
texto real, antes y despues de generar.

Por que existe, en orden de dureza:

1. La Usage Policy de Anthropic clasifica Healthcare, Legal y Finance como
   high-risk y exige para ellos revision por un profesional cualificado antes
   de publicar la salida. ARCANUM no tiene medico ni abogado revisando, asi que
   no puede cumplirlo: la unica postura sostenible es NEGARSE a esos dominios.
   Incumplir la AUP corta la API, y sin API no hay producto.
   La misma AUP excluye el *wellness* (sueno, estres, alimentacion, ejercicio)
   de ese regimen, asi que hablar de habito y descanso NO se bloquea.
2. Autolesion y suicidio: la AUP prohibe facilitar, promover o glamorizar
   cualquier forma. Aqui no basta con no hablar del tema: hay que salir del
   registro simbolico y derivar a ayuda humana.
3. La Directiva 2005/29/CE, Anexo I, punto 17 hace practica desleal EN
   CUALQUIER CIRCUNSTANCIA proclamar que algo cura enfermedades, sin necesidad
   de probar dano y sin defensa de "era entretenimiento". Y la 2001/83/CE art.
   1(2)(a) convierte en medicamento lo que se PRESENTA como curativo, mire lo
   que mire dentro.

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
    # posologia
    (r"\b(toma|tomate|bebe|ingiere|aplica|aplicate)\s+.{0,30}\b"
     r"(gotas|mg|gramos|cucharadas|veces\s+al\s+dia|en\s+ayunas)\b", HEALTH),
    (r"\b\d+\s*(mg|ml|gotas|gramos)\b", HEALTH),
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
# Obligacion doble y de origen distinto:
#   - AUP de Anthropic: "must disclose to users that they are interacting with
#     AI rather than a human [...] at a minimum at the beginning of each chat
#     session". Es contractual: incumplirla corta la API.
#   - AI Act (UE) art. 50(1), aplicable desde el 2 de agosto de 2026, y 50(5):
#     la informacion se da "at the latest at the time of the first interaction".
# Por eso viaja en la RESPUESTA y no solo en los Terminos: un aviso que la
# persona acepto una vez al instalar no acompana a la lectura de dentro de seis
# meses.
AI_DISCLOSURE = (
    "Este texto lo redacta una inteligencia artificial a partir de tu carta y "
    "del cielo real. Es contenido simbólico y cultural: no sustituye "
    "orientación médica, psicológica, legal ni financiera."
)
