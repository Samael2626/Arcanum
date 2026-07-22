/// Glifos y nombres en español para planetas y signos.
const planetGlyph = {
  'sun': '☉',
  'moon': '☽',
  'mercury': '☿',
  'venus': '♀',
  'mars': '♂',
  'jupiter': '♃',
  'saturn': '♄',
  'uranus': '♅',
  'neptune': '♆',
  'pluto': '♇',
  'north_node': '☊',
};
const planetEs = {
  'sun': 'Sol',
  'moon': 'Luna',
  'mercury': 'Mercurio',
  'venus': 'Venus',
  'mars': 'Marte',
  'jupiter': 'Júpiter',
  'saturn': 'Saturno',
  'uranus': 'Urano',
  'neptune': 'Neptuno',
  'pluto': 'Plutón',
  'north_node': 'Nodo Norte',
};
const signGlyph = {
  'aries': '♈',
  'taurus': '♉',
  'gemini': '♊',
  'cancer': '♋',
  'leo': '♌',
  'virgo': '♍',
  'libra': '♎',
  'scorpio': '♏',
  'sagittarius': '♐',
  'capricorn': '♑',
  'aquarius': '♒',
  'pisces': '♓',
};
const signEs = {
  'aries': 'Aries',
  'taurus': 'Tauro',
  'gemini': 'Géminis',
  'cancer': 'Cáncer',
  'leo': 'Leo',
  'virgo': 'Virgo',
  'libra': 'Libra',
  'scorpio': 'Escorpio',
  'sagittarius': 'Sagitario',
  'capricorn': 'Capricornio',
  'aquarius': 'Acuario',
  'pisces': 'Piscis',
};
const aspectEs = {
  'conjunction': 'conjunción',
  'sextile': 'sextil',
  'square': 'cuadratura',
  'trine': 'trígono',
  'opposition': 'oposición',
};

/// Qué favorece la energía de cada planeta (para la guía "Ahora favorece").
///
/// Los siete primeros son los clásicos, únicos que rigen horas y días
/// planetarios. Los modernos y el Nodo no gobiernan horas, pero sí aparecen en
/// la carta natal y en los tránsitos: necesitan su línea para que la lectura
/// no quede coja.
const planetFavors = {
  'sun': 'éxito, vitalidad, reconocimiento',
  'moon': 'hogar, sueños, psiquismo, emociones',
  'mercury': 'estudio, comercio, comunicación, viajes',
  'venus': 'amor, belleza, arte, reconciliación',
  'mars': 'fuerza, coraje, protección, deseo',
  'jupiter': 'abundancia, expansión, suerte, justicia',
  'saturn': 'límites, disciplina, destierro, estructura',
  'uranus': 'liberación, invención, cortar con lo caduco',
  'neptune': 'sueños, visión, arte, compasión',
  'pluto': 'transformación profunda, trabajo de sombra',
  'north_node': 'propósito, dirección vital, salir de lo cómodo',
};
