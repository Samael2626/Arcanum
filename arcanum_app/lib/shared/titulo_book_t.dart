/// El titulo del Book T, en espanol.
///
/// El catalogo los guarda BILINGUES, separados por barra:
///
///     "The Fool / El Loco"
///     "Root of the Powers of Water / Raiz de los Poderes del Agua"
///
/// Y eso esta bien: el titulo del Book T es ingles en origen —la Golden Dawn lo
/// escribio asi— y conviene conservarlo en la base para no perder la fuente. Lo
/// que estaba mal era PINTARLO ENTERO: la pantalla mostraba las dos mitades y
/// aparecia ingles en una app en espanol.
///
/// El backend ya resolvia esto en `claude_service._term_key`, que se queda con
/// la parte tras la barra para verificar que el modelo nombro la carta. Aqui va
/// la misma regla, para que el criterio sea uno y no dos que divergen.
///
/// Cuando llegue el momento de otros idiomas, el corte natural ya esta hecho:
/// el idioma se elige AL PINTAR y no al guardar. Quien anada contenido nuevo
/// debe respetarlo — siempre las dos formas, siempre separadas por barra.
library;

/// La mitad espanola de un titulo bilingue, o el titulo tal cual si no lo es.
///
/// Sin barra devuelve la cadena entera: un titulo que ya venga solo en espanol
/// no se toca, y uno que venga solo en ingles se muestra igualmente en vez de
/// desaparecer. Perder el dato seria peor que mostrarlo en el idioma equivocado.
String tituloEnEspanol(String? bilingue) {
  final crudo = bilingue?.trim() ?? '';
  if (!crudo.contains('/')) return crudo;
  final espanol = crudo.split('/').last.trim();
  return espanol.isEmpty ? crudo : espanol;
}
