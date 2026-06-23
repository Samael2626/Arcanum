"""Materia Arcana — Metales planetarios + Inciensos y resinas.
Fuentes: Agrippa Lib. I & II, Dioscórides, Culpeper, tradición alquímica.
"""

METALES: list[dict] = [
    # ── EXISTENTES (oro, plata, cobre — en seed_materia.py) ──

    # ── NUEVOS (completan los 7 metales planetarios clásicos) ─────────────────
    dict(slug="hierro", item_type="metal", name="Hierro", planet="mars", element="fuego",
         aliases=["Iron", "Ferrum"],
         properties={
             "intenciones": ["fuerza", "protección", "voluntad", "destierro"],
             "notas": "Metal marcial por excelencia; el hierro fríd repele a las hadas, los espíritus y el mal de ojo.",
             "estudio": "El hierro es el metal de Marte en todas las tradiciones alquímicas y mágicas. Agrippa (Lib. I, cap. XXVI) lo asigna inequívocamente a Marte: 'el hierro pertenece a Marte, guerrero y destructivo'. El símbolo alquímico de Marte (♂) es también el símbolo del hierro en química moderna. En el folklore europeo universal, el hierro frío repele a las hadas y los espíritus malignos — clavos de hierro en puertas y umbrales son protección. Los herreros eran figuras de poder mágico en casi todas las culturas (Hefesto/Vulcano, Ogún en Yoruba). El acero es hierro; la espada ritual es hierro martiano.",
             "dia": "martes",
             "angel_regente": "Samael",
             "fuente": "Agrippa, Lib. I cap. XXVI; tradición alquímica universal",
         }),

    dict(slug="estaño", item_type="metal", name="Estaño", planet="jupiter", element="aire",
         aliases=["Tin", "Stannum", "Júpiter (alquimia)"],
         properties={
             "intenciones": ["expansión", "prosperidad", "sabiduría", "suerte"],
             "notas": "Metal jovial de Júpiter; trae abundancia, crecimiento y buen juicio a quien lo trabaja.",
             "estudio": "El estaño (Sn) es el metal asignado a Júpiter en la tradición alquímica desde la Antigüedad. Agrippa (Lib. I, cap. XXVI): 'el estaño pertenece a Júpiter, benéfico y expansivo'. Los alquimistas lo simbolizaban con el signo ♃. El estaño fue crucial para la civilización del Bronce (aleación con cobre). En Cornualles (minas de estaño, siglos XVII-XVIII) los mineros tenían rituales de protección y prosperidad asociados a 'knockers' (espíritus subterráneos). En magia talismánica jovial, el estaño es el metal para grabar pentáculos de prosperidad y buena fortuna.",
             "dia": "jueves",
             "angel_regente": "Sachiel",
             "fuente": "Agrippa, Lib. I cap. XXVI; tradición alquímica",
         }),

    dict(slug="plomo", item_type="metal", name="Plomo", planet="saturn", element="tierra",
         aliases=["Lead", "Plumbum", "Saturno (alquimia)"],
         properties={
             "intenciones": ["destierro", "sellado", "trabajo ctónico", "ralentización"],
             "notas": "Metal saturnino de los límites; en la Antigüedad se grababan maldiciones en tablillas de plomo.",
             "estudio": "El plomo (Pb) es el metal de Saturno en la alquimia: pesado, oscuro, inerte — todas cualidades saturnianas. Agrippa (Lib. I, cap. XXVI) lo asigna a Saturno. Las *defixiones* romanas y griegas (tablillas de maldición) se grababan en láminas de plomo y se enterraban o arrojaban a pozos — el plomo saturnino 'sellaba' la maldición y la dirigía hacia el inframundo. En alquimia, el plomo es la materia prima bruta que el Gran Trabajo transmuta en oro (Saturno → Sol = nigredo → rubedo). Usar plomo en magia moderna requiere precaución: es tóxico por contacto e inhalación de polvo.",
             "dia": "sábado",
             "angel_regente": "Cassiel",
             "toxicidad": "TÓXICO — neurotóxico acumulativo; no manipular en polvo; lavar manos tras contacto",
             "fuente": "Agrippa, Lib. I cap. XXVI; defixiones greco-romanas (British Museum); tradición alquímica",
         }),

    dict(slug="mercurio-metal", item_type="metal", name="Mercurio (Azogue)", planet="mercury", element="agua",
         aliases=["Quicksilver", "Hydrargyrum", "Azogue", "Hg"],
         properties={
             "intenciones": ["comunicación", "rapidez", "magia de influencia", "transmutación"],
             "notas": "El único metal líquido; símbolo de la materia que fluye entre estados — el mensajero de los dioses.",
             "estudio": "El mercurio (Hg) es el único metal líquido a temperatura ambiente — su fluidez es la firma de Mercurio, el dios que fluye entre mundos. Agrippa (Lib. I, cap. XXVI) lo asigna a Mercurio. En alquimia es el principio del Mercurio filosófico (junto con azufre y sal), uno de los tres principios primordiales de Paracelso. Los alquimistas lo llamaban 'azogue' y lo usaban en amalgamas para purificar oro. En la tradición hoodoo afroamericana, el 'quicksilver' se coloca en amuletos para acelerar el cambio y atraer el dinero. ADVERTENCIA: el mercurio metálico y sus vapores son altamente tóxicos para el sistema nervioso central.",
             "dia": "miércoles",
             "angel_regente": "Rafael",
             "toxicidad": "VENENOSO — los vapores de mercurio son neurotóxicos; no manipular sin protección; no ingerir",
             "fuente": "Agrippa, Lib. I cap. XXVI; Paracelso, Opus Paramirum (tres principios); tradición alquímica",
         }),
]

INCIENSOS: list[dict] = [
    # ── EXISTENTES (olibano, mirra — en seed_materia.py) ──

    # ── NUEVOS ────────────────────────────────────────────────────────────────
    dict(slug="copal", item_type="incense", name="Copal", planet="sun", element="fuego",
         aliases=["Copal blanco", "Bursera copallifera"],
         properties={
             "intenciones": ["purificación", "comunicación con ancestros", "consagración", "ofrenda"],
             "notas": "Resina solar mesoamericana; el incienso sagrado de los aztecas y mayas para los dioses y muertos.",
             "estudio": "El copal (término náhuatl 'copalli' = incienso) es la resina de varios árboles del género Bursera, endémicos de México y Centroamérica. Fue el incienso sagrado por excelencia de las civilizaciones mesoamericanas: los aztecas lo ofrecían a Huitzilopochtli, Tláloc y Quetzalcóatl; los mayas lo quemaban en el Tzolk'in. En el *Codex Borgia* y el *Florentine Codex* (Sahagún) aparece mencionado en centenares de contextos rituales. El Día de Muertos, el copal guía a los difuntos de regreso al mundo de los vivos con su aroma. Hoy es el incienso más usado en México para limpia y purificación.",
             "fuente": "Sahagún, Historia General de las Cosas de Nueva España (Codex Florentine); Codex Borgia",
         }),

    dict(slug="benjuí", item_type="incense", name="Benjuí", planet="venus", element="aire",
         aliases=["Benzoin", "Benjuí de Sumatra", "Styrax benzoin"],
         properties={
             "intenciones": ["purificación", "prosperidad", "atracción", "consagración"],
             "notas": "Resina venusina dulce; eleva el espacio ritual y atrae energías de abundancia y belleza.",
             "estudio": "El benjuí es la resina de Styrax benzoin (Sumatra) y Styrax tonkinensis (Laos/Vietnam). Llegó a Europa vía comercio árabe en el siglo XIV bajo el nombre 'benzui' (resina de Java). Agrippa no lo menciona explícitamente pero los formularios mágicos renacentistas lo usan sistemáticamente en inciensos de Venus por su aroma dulce, casi de vainilla. La Golden Dawn (*777*) lo lista en preparaciones venusinas. En la farmacología antigua se usaba como antiséptico de piel. Se añade frecuentemente como fijador a mezclas de incienso.",
             "fuente": "Formularios mágicos renacentistas; Golden Dawn, 777 (Venus)",
         }),

    dict(slug="sangre-de-drago", item_type="incense", name="Sangre de Drago", planet="mars", element="fuego",
         aliases=["Dragon's Blood", "Dracaena draco", "Croton lechleri"],
         properties={
             "intenciones": ["poder", "protección", "amor", "destierro", "potenciación"],
             "notas": "Resina marcial rojo sangre; amplifica cualquier operación mágica y agrega fuerza bruta.",
             "estudio": "La 'sangre de drago' designa la resina roja de varias plantas: Dracaena draco (Canarias, mencionada por Plinio), Daemonorops draco (palma de ratán, Asia) y Croton lechleri (Amazonia). Su color rojo sangre la convirtió en material mágico universal. Dioscórides (V.90 aprox.) menciona el 'cinnabari' (sangre de drago) para heridas. Culpeper la usa en preparaciones astringentes. En magia es el amplificador universal: añadir sangre de drago a cualquier incienso aumenta su potencia. Sola, se usa para protección y para romper bloqueos con fuerza marcial.",
             "fuente": "Plinio, Historia Natural XXXIII; Dioscórides, De Materia Medica V; Culpeper, Complete Herbal",
         }),

    dict(slug="sándalo-blanco", item_type="incense", name="Sándalo Blanco", planet="moon", element="agua",
         aliases=["White Sandalwood", "Santalum album"],
         properties={
             "intenciones": ["meditación", "purificación", "elevación espiritual", "deseo"],
             "notas": "Madera lunar de la India; el más antiguo incienso espiritual del mundo, usado 4.000 años.",
             "estudio": "Santalum album (sándalo blanco de Mysore, India) es citado en textos sánscritos desde hace 4.000 años. Fue el incienso principal del hinduismo y el budismo para meditación y ofrendas. En la tradición hermética occidental se asigna a la Luna por su aroma fresco y su efecto calmante de la mente. Dioscórides no lo menciona (árbol indio), pero los herbalistas árabes medievales (Ibn Sina, *Canon*) lo incluyen como refrescante y cardiaco. La Golden Dawn lo lista en el incienso lunar y en los rituales de la luna. Actualmente, Santalum album está en peligro de extinción — preferir aceites de fuentes sostenibles.",
             "fuente": "Ibn Sina, Canon de Medicina; Golden Dawn, 777; tradición hinduista y budista",
         }),

    dict(slug="estoraque", item_type="incense", name="Estoraque", planet="mercury", element="aire",
         aliases=["Storax", "Styrax officinalis", "Liquidambar"],
         properties={
             "intenciones": ["comunicación", "trabajo psíquico", "claridad", "viaje astral"],
             "notas": "Resina mercurial de los profetas; es el 'estacte' del Éxodo, uno de los inciensos del Templo.",
             "estudio": "El estoraque (Styrax officinalis) fue uno de los cuatro ingredientes del incienso sagrado del Templo de Jerusalén según el Éxodo (30:34-38). Dioscórides (I.79) lo describe como balsámico y útil para tos y afecciones respiratorias. Agrippa lo incluye en inciensos mercuriales. La Golden Dawn (*777*) lo asigna a Mercurio. Su aroma es dulce, resinoso, con notas balsámicas — diferente del liquidambar moderno que se vende a veces como 'estoraque'. En magia se quema para facilitar la comunicación, la profecía y los viajes astrales.",
             "fuente": "Éxodo 30:34-38; Dioscórides, De Materia Medica I.79; Agrippa, Lib. I; Golden Dawn, 777",
         }),

    dict(slug="galbano", item_type="incense", name="Gálbano", planet="saturn", element="tierra",
         aliases=["Galbanum", "Ferula gummosa"],
         properties={
             "intenciones": ["trabajo ctónico", "invocación", "anclaje", "comunión con lo antiguo"],
             "notas": "Resina saturnina fétida del Templo; su olor penetrante âncora las invocaciones a entidades.",
             "estudio": "El gálbano (Ferula gummosa y F. galbaniflua) es el segundo ingrediente del incienso sagrado del Templo mencionado en Éxodo 30:34. Dioscórides (III.83) lo describe como antiespasmódico y para las mordeduras de serpiente. Su aroma es verde, terroso, casi fétido — muy diferente de los inciensos suaves. Agrippa lo incluye en formulaciones de invocación. La Golden Dawn lo asigna a Saturno por su cualidad densa y terrosa. Se usa en magia ceremonial para anclaje de operaciones pesadas y para crear el 'ambiente espeso' que facilita manifestaciones.",
             "fuente": "Éxodo 30:34; Dioscórides, De Materia Medica III.83; Agrippa, Lib. I; Golden Dawn, 777",
         }),

    dict(slug="opoponax", item_type="incense", name="Opopónax", planet="saturn", element="agua",
         aliases=["Opoponax", "Mirra dulce", "Commiphora guidottii"],
         properties={
             "intenciones": ["protección", "trabajo con sombra", "destierro", "meditación profunda"],
             "notas": "Resina oscura emparentada con la mirra; más dulce pero igualmente ctónica y protectora.",
             "estudio": "El opopónax (Commiphora guidottii y C. holtziana) es mencionado por Dioscórides (III.48) como la resina del 'pastinaka' — diferente de la mirra pero igualmente medicinal. En la tradición mágica occidental es la mirra oscura, usada en rituales de protección profunda y trabajo con la sombra jungiana. La Golden Dawn lo incluye en inciensos de Saturno junto con la mirra. Su aroma es dulce-terroso, con profundidad balsámica. Menos común que la mirra, pero con mayor suavidad en el humo.",
             "fuente": "Dioscórides, De Materia Medica III.48; Golden Dawn, 777 (Saturno)",
         }),

    dict(slug="nardo", item_type="incense", name="Nardo", planet="venus", element="agua",
         aliases=["Spikenard", "Nardostachys jatamansi", "Nardo de la India"],
         properties={
             "intenciones": ["amor sagrado", "devoción", "ungüento", "preparación del alma"],
             "notas": "El ungüento de María Magdalena; resina venusina del Himalaya de una devoción extraordinaria.",
             "estudio": "Nardostachys jatamansi es la planta del nardo genuino, originaria del Himalaya nepalés y tibetano. Dioscórides (I.7) la describe como calorífica, diurética y para la flatulencia. Fue el ingrediente principal del ungüento con que María Magdalena ungió a Jesús en Betania (Juan 12:3, Marcos 14:3) — un frasco de alabastro con nardo valorado en 300 denarios (el salario de un año). Culpeper lo vincula a Venus. Es el ungüento de la devoción absoluta: en el Cantar de los Cantares (1:12) es el aroma del amado. En magia se usa en unciones de amor sagrado y preparación espiritual.",
             "fuente": "Dioscórides, De Materia Medica I.7; Juan 12:3; Cantar de los Cantares 1:12; Culpeper",
         }),

    dict(slug="ciprés-resina", item_type="incense", name="Ciprés", planet="saturn", element="tierra",
         aliases=["Cypress", "Cupressus sempervirens"],
         properties={
             "intenciones": ["duelo", "memoria de los muertos", "umbral", "consuelo"],
             "notas": "Árbol saturnino del cementerio; sus ramas se usan en ritos fúnebres desde la Antigüedad.",
             "estudio": "Cupressus sempervirens es el árbol del cementerio mediterráneo por excelencia — sus ramas apuntando al cielo simbolizan el alma que asciende. Dioscórides (I.102) lo menciona para heridas y estreñimiento. Culpeper lo asigna a Saturno. En la mitología griega, el joven Cyparissus fue transformado en ciprés por Apolo — árbol del luto perpetuo. Los romanos colocaban ramas de ciprés en puertas de casas donde había un difunto. En magia se quema para honrar a los muertos, acompañar en el duelo y trabajar con el umbral entre los mundos.",
             "fuente": "Dioscórides, De Materia Medica I.102; Culpeper, Complete Herbal; Ovidio, Metamorfosis X",
         }),

    dict(slug="canfora", item_type="incense", name="Alcanfor", planet="moon", element="agua",
         aliases=["Camphor", "Cinnamomum camphora", "Canfora"],
         properties={
             "intenciones": ["purificación extrema", "castidad", "sueños", "claridad"],
             "notas": "Resina lunar fría y penetrante; purifica el aura y enfría las pasiones para el trabajo oracular.",
             "estudio": "El alcanfor (Cinnamomum camphora, árbol nativo de China y Japón) fue conocido en Europa medieval a través del comercio árabe. Dioscórides no lo menciona (llegó a Occidente tardíamente). Ibn Sina (*Canon de Medicina*) lo describe como frío y seco en cuarto grado — la cualidad extrema frío/húmedo lo vincula a la Luna. Agrippa no lo lista, pero la tradición ceremonial posterior lo asigna a la Luna por sus efectos enfriantes sobre el sistema nervioso. En Japón se quema en templos budistas. En magia se usa para purificar el espacio antes de adivinación y para suprimir temporalmente los deseos físicos.",
             "fuente": "Ibn Sina, Canon de Medicina; tradición ceremonial budista japonesa; Agrippa (inferencia por correspondencia lunar)",
         }),
]
