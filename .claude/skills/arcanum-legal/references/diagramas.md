# Documentación legal-técnica: UML, casos de uso, flujo de datos, ROPA

Los diagramas aquí no son decoración: son la evidencia con la que se rellena el Data safety de Play, se sostiene el ROPA del GDPR y se contesta a un reviewer o a la SIC. Se generan **desde el código auditado**, nunca desde lo que dice la política.

Formato: Mermaid en Markdown, dentro de `docs/legal/`. Se renderiza en GitHub, en Obsidian y en un Artifact.

## 1. Casos de uso — quién toca datos personales

Un actor por rol real, y solo los casos de uso donde hay dato personal de por medio.

```mermaid
flowchart LR
  U((Usuario)) --> CU1[Crear cuenta]
  U --> CU2[Registrar carta natal]
  U --> CU3[Consultar el oraculo]
  U --> CU4[Escribir en el grimorio]
  U --> CU5[Comprar suscripcion]
  U --> CU6[Ver anuncio por creditos]
  U --> CU7[Ejercer derechos / borrar cuenta]
  A((Admin)) --> CU8[Gestionar creditos]
  CU3 -.datos a tercero.-> LLM[[Groq]]
  CU5 -.-> RC[[RevenueCat]]
  CU6 -.-> AD[[AdMob]]
  CU1 -.-> FB[[Firebase]]
```

Regla: toda flecha punteada hacia un tercero exige, sí o sí, fila en la tabla de subencargados, base legal y mención en la política. Si aparece una flecha nueva y no hay fila, es un hallazgo de auditoría.

## 2. Flujo de datos (DFD) por feature

Uno por feature que salga del dispositivo. Debe mostrar: qué campo sale, hacia dónde, cifrado, dónde se persiste, cuánto se retiene.

```mermaid
sequenceDiagram
  participant App as Flutter
  participant API as FastAPI (Railway)
  participant DB as Postgres
  participant LLM as Groq
  App->>API: POST /oracle {consulta, contexto natal} TLS
  API->>DB: lee perfil (minimo necesario)
  API->>LLM: prompt con nombre visible + resumen natal, sin email ni user_id
  LLM-->>API: respuesta
  API->>DB: persiste lectura (user_id, retencion: hasta borrado)
  API-->>App: respuesta
  Note over API: no se loggea el prompt
```

## 3. ROPA — registro de actividades de tratamiento (GDPR art. 30)

Tabla en `docs/legal/ropa.md`, una fila por finalidad, no por campo:

`finalidad | categorías de interesados | categorías de datos | base legal | destinatarios | transferencia fuera del EEE | plazo de supresión | medidas de seguridad`

## 4. Mapa de retención y borrado

Diagrama del efecto cascada de `DELETE /users/me`: qué tablas se borran, qué queda, en qué tercero hay que propagar el borrado (RevenueCat, Firebase). Sirve para probar ante Play que el borrado es real.

```mermaid
flowchart TD
  D[DELETE /users/me] --> T1[usuarios]
  D --> T2[lecturas]
  D --> T3[grimorio]
  D --> T4[creditos]
  D --> X1[RevenueCat: borrar app user]
  D --> X2[Firebase: borrar instancia]
  D -.retenido por ley/fraude.-> R[logs de facturacion]
```

Lo que aparezca en el nodo de retención debe estar declarado en la política, con plazo. Si nada se retiene, el nodo se elimina — no se deja "por si acaso".

## 5. Cuándo regenerar

Cada vez que: se añade un tercero, cambia un endpoint que toca datos personales, cambia el esquema de base de datos, o se prepara un release. Los diagramas viejos son peores que no tenerlos: se citan como verdad y mienten.
