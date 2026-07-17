{{flutter_js}}
{{flutter_build_config}}

// ARCANUM administra su cache PWA con web/service-worker.js. No pasar
// serviceWorkerSettings evita que el worker obsoleto de Flutter compita por
// el mismo scope y fuerce una recarga durante el arranque.
_flutter.loader.load();
