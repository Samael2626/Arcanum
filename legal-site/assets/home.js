const respuestas = [
  "Lo que buscas afuera ya está decidido adentro. Observa antes de actuar.",
  "Hay un ciclo cerrándose. No fuerces el siguiente paso todavía.",
  "La claridad que pides llega con quietud, no con más preguntas.",
  "Lo que temes soltar es justo lo que te está deteniendo.",
  "El símbolo que buscas ya apareció. Revisa lo que ignoraste esta semana."
];

const form = document.getElementById('oracleForm');
const input = document.getElementById('oracleInput');
const response = document.getElementById('oracleResponse');

form.addEventListener('submit', (e) => {
  e.preventDefault();
  if (!input.value.trim()) return;

  response.textContent = 'Consultando...';

  setTimeout(() => {
    const r = respuestas[Math.floor(Math.random() * respuestas.length)];
    response.textContent = '"' + r + '"';
    input.value = '';
  }, 600);
});
