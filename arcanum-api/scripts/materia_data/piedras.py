"""Materia Arcana — Piedras y gemas. Fuentes: Agrippa Lib. I, tablas Golden Dawn *777*."""

PIEDRAS: list[dict] = [
    # ── EXISTENTES (cuarzo-claro, amatista, obsidiana, cornalina — en seed_materia.py) ──

    # ── NUEVAS ────────────────────────────────────────────────────────────────
    dict(slug="turmalina-negra", item_type="stone", name="Turmalina Negra", planet="saturn", element="tierra",
         aliases=["Black Tourmaline", "Schorl"],
         properties={
             "intenciones": ["protección", "destierro", "anclaje", "escudo energético"],
             "notas": "Piedra saturnina de protección absoluta; el escudo más potente del arsenal lapidario moderno.",
             "estudio": "La turmalina negra (eschorl) es la variedad de turmalina más común. En la tradición hermética se asigna a Saturno por su color negro y su virtud de absorber y neutralizar. Agrippa (Lib. I) lista piedras negras bajo la regencia de Saturno como protectoras contra influencias malignas. En las tablas de correspondencias de la Golden Dawn (*777*, col. Saturno), las piedras negras son las de protección y barrera. La turmalina negra genera una pequeña carga eléctrica (piezoeléctrica) cuando se calienta o comprime — propiedad física que sustenta su reputación de 'actividad' energética.",
             "fuente": "Agrippa, Lib. I; Golden Dawn, 777 (col. Saturno); mineralogía moderna (piezoelectricidad)",
         }),

    dict(slug="labradorita", item_type="stone", name="Labradorita", planet="moon", element="agua",
         aliases=["Labradorite", "Piedra de Luna Oscura"],
         properties={
             "intenciones": ["magia", "intuición", "protección en el trabajo mágico", "transformación"],
             "notas": "Piedra lunar de la iridiscencia; su juego de colores es la labradorescencia — portal entre mundos.",
             "estudio": "La labradorita fue descubierta en 1770 en la Península de Labrador (Canadá) por misioneros moravos — los nativos Inuit ya la conocían y creían que las auroras boreales atrapadas en la roca la iluminaban. Es un feldespato con fenómeno óptico propio ('labradorescencia'): iridiscencia azul-verde-dorada causada por interferencia de luz en capas internas. En la tradición lapidaria moderna se asigna a la Luna por su cualidad de 'velo' entre mundos. Es la piedra de los practicantes de magia: amplifica la percepción extrasensorial y protege el campo del practicante durante el trabajo.",
             "fuente": "Mineralogía moderna; tradición lapidaria contemporánea (basada en correspondencias de color y fenómeno óptico)",
         }),

    dict(slug="lapislazuli", item_type="stone", name="Lapislázuli", planet="jupiter", element="agua",
         aliases=["Lapis Lazuli", "Lazurita"],
         properties={
             "intenciones": ["sabiduría", "verdad", "iluminación", "comunicación divina"],
             "notas": "Piedra de Júpiter y de los dioses egipcios; el azul real que decoraba la máscara de Tutankamón.",
             "estudio": "El lapislázuli fue la piedra preciosa más valorada del mundo antiguo antes que el diamante. Provenía casi exclusivamente de las minas de Sar-i Sang (Afganistán), activas desde hace 6.000 años. Los egipcios lo usaban para decorar esculturas de dioses y la máscara funeraria de Tutankamón; la diosa Nuit (cielo nocturno) se representaba con piel de lapislázuli. Agrippa (Lib. I) lo incluye entre piedras de virtud jovial. Los alquimistas medievales lo procesaban para obtener el pigmento azul ultramarino — más valioso que el oro. En magia: facilita la comunicación con entidades elevadas y abre la mente a verdades universales.",
             "fuente": "Agrippa, Lib. I; Dioscórides, De Materia Medica V.91; arqueología egipcia",
         }),

    dict(slug="hematita", item_type="stone", name="Hematita", planet="mars", element="fuego",
         aliases=["Hematite", "Piedra de sangre"],
         properties={
             "intenciones": ["anclaje", "fuerza", "coraje", "protección física"],
             "notas": "Piedra marcial de hierro oxidado; su raya roja es la sangre de la tierra — fuerza y voluntad.",
             "estudio": "La hematita es óxido de hierro (Fe₂O₃) — mineral que tiñe de rojo la tierra y cuya raya es sanguínea. El nombre deriva del griego 'haema' (sangre). Dioscórides (V.90) la describe bajo el nombre de 'bloodstone' (haematites lithos) con usos medicinales en hemorragias oculares. Agrippa la asigna a Marte por su contenido de hierro (metal marcial) y su color rojo. En la Roma antigua se tallaban sellos y camafeos en hematita para los soldados. En magia se usa para anclaje físico, protección en situaciones de confrontación y refuerzo de la voluntad.",
             "fuente": "Dioscórides, De Materia Medica V.90; Agrippa, Lib. I",
         }),

    dict(slug="citrino", item_type="stone", name="Citrino", planet="sun", element="fuego",
         aliases=["Citrine", "Cuarzo citrino", "Topacio falso"],
         properties={
             "intenciones": ["prosperidad", "abundancia", "éxito", "claridad mental"],
             "notas": "Cuarzo solar amarillo; la 'piedra del comerciante' por su asociación con el dinero y el éxito.",
             "estudio": "El citrino es cuarzo (SiO₂) con trazas de hierro que le dan color amarillo a naranja. En la naturaleza es raro; la mayoría del 'citrino' del mercado es amatista o cuarzo ahumado calentado. En la tradición lapidaria se asigna al Sol por su color dorado-solar. Agrippa (Lib. I) vincula las piedras amarillas y doradas con el Sol. Es la única piedra del cuarzo que no acumula energía negativa (según la tradición), por lo que no requiere limpieza frecuente — virtud que la convierte en amuleto de negocios ideal.",
             "fuente": "Agrippa, Lib. I (piedras solares); mineralogía (cuarzo con Fe³⁺)",
         }),

    dict(slug="malaquita", item_type="stone", name="Malaquita", planet="venus", element="tierra",
         aliases=["Malachite", "Cobre verde"],
         properties={
             "intenciones": ["amor", "protección", "transformación", "viaje seguro"],
             "notas": "Piedra venusina de cobre; sus espirales verdes son las venas de Venus y el ojo que aparta el mal.",
             "estudio": "La malaquita es carbonato básico de cobre Cu₂(CO₃)(OH)₂ — su color verde esmeralda proviene del cobre, metal de Venus. Dioscórides (V.87) la menciona como chrysocolla (confusión histórica común). Agrippa vincula el verde con Venus. Los egipcios la trituraban como pigmento cosmético (kohl verde) y la asociaban a Hathor, diosa del amor y la belleza. En el Renacimiento se colgaba sobre cunas de niños para protegerlos del mal de ojo — sus espirales concéntricas emulan el 'ojo apotropaico'. En alquimia es fuente de cobre para procesos transmutatorios.",
             "fuente": "Agrippa, Lib. I; Dioscórides, De Materia Medica V; arqueología egipcia",
         }),

    dict(slug="ágata-musgo", item_type="stone", name="Ágata de Musgo", planet="mercury", element="tierra",
         aliases=["Moss Agate", "Agata verde"],
         properties={
             "intenciones": ["abundancia", "conexión con la naturaleza", "curación", "crecimiento"],
             "notas": "Ágata de Mercurio con inclusiones que parecen musgo; piedra de los jardineros y los curanderos.",
             "estudio": "El ágata de musgo no es musgo real sino inclusiones de óxidos minerales (clorita, hornblenda) que crean patrones vegetales internos — doctrina de las signaturas en mineral: parece una planta, rige lo vegetal. Agrippa asigna el ágata a Mercurio. En la tradición griega, los agricultores ataban ágata a bueyes de arado para garantizar buenas cosechas. En magia herbal es la piedra que potencia el trabajo con plantas medicinales y rituales de crecimiento y abundancia natural.",
             "fuente": "Agrippa, Lib. I (ágata a Mercurio); doctrina de las signaturas (Böhme)",
         }),

    dict(slug="ónix-negro", item_type="stone", name="Ónix Negro", planet="saturn", element="tierra",
         aliases=["Black Onyx", "Ónice"],
         properties={
             "intenciones": ["protección", "fuerza en adversidad", "anclaje", "control propio"],
             "notas": "Piedra saturnina de disciplina; absorbe y transforma la energía caótica en orden y control.",
             "estudio": "El ónix negro es calcedonia en bandas (SiO₂) con inclusiones de carbono que le dan el color negro. Agrippa (Lib. I) lista el ónix bajo Saturno por su color oscuro. Los romanos lo usaban para grabar sellos — su dureza lo hace ideal para camafeos. En la tradición árabe medieval (Ibn Sina, *Canon de Medicina*) el ónix negro protege contra el miedo y fortalece la voluntad. En magia se usa en periodos de duelo, reestructuración y trabajo de disciplina personal — Saturno como maestro de la forma y el límite.",
             "fuente": "Agrippa, Lib. I; Ibn Sina (Avicena), Canon de Medicina; tradición lapidaria clásica",
         }),

    dict(slug="jade", item_type="stone", name="Jade", planet="venus", element="agua",
         aliases=["Jade", "Jadeíta", "Nefrita"],
         properties={
             "intenciones": ["longevidad", "sabiduría", "prosperidad", "armonía"],
             "notas": "Piedra de Venus en Oriente; en China es la piedra del cielo, la virtud y la inmortalidad.",
             "estudio": "El jade comprende dos minerales distintos: jadeíta (silicato de aluminio y sodio) y nefrita (anfibol cálcico-magnésico). En China el jade (yù) es la piedra sagrada por excelencia desde el Neolítico: representa las cinco virtudes confucianas (benevolencia, sabiduría, valentía, justicia, pureza). Los emperadores eran enterrados en trajes de jade. En la tradición mesoamericana (Olmeca, Maya, Azteca) el jade era más valioso que el oro — representaba el agua, el maíz y la vida. Agrippa vincula el verde venusino con el amor y la prosperidad.",
             "fuente": "Agrippa, Lib. I (verde → Venus); arqueología china y mesoamericana",
         }),

    dict(slug="rodocrosita", item_type="stone", name="Rodocrosita", planet="venus", element="fuego",
         aliases=["Rhodochrosite", "Rosa del Inca"],
         properties={
             "intenciones": ["amor propio", "curación emocional", "compasión", "reconciliación"],
             "notas": "Piedra venusina rosada de los Incas; se llama 'Rosa del Inca' por su origen en las minas andinas.",
             "estudio": "La rodocrosita es carbonato de manganeso MnCO₃ con color rosado a rojo. Los Incas creían que era la sangre solidificada de sus reyes y reinas ancestrales — una piedra de linaje real y amor sagrado. En la tradición lapidaria occidental moderna se asigna a Venus por su color rosado y su efecto en el chakra del corazón. Agrippa asocia el rosado-rojo con Venus (Lib. I). Es la piedra del amor propio y la curación del corazón herido: trabaja la aceptación de uno mismo antes que el amor romántico.",
             "fuente": "Agrippa, Lib. I (rosado → Venus); arqueología andina (minas de Catamarca)",
         }),

    dict(slug="sodalita", item_type="stone", name="Sodalita", planet="jupiter", element="aire",
         aliases=["Sodalite"],
         properties={
             "intenciones": ["verdad", "intuición", "comunicación", "confianza en uno mismo"],
             "notas": "Piedra jovial azul oscuro; desarrolla la mente analítica y el pensamiento honesto.",
             "estudio": "La sodalita es un tectosilicato de sodio y aluminio con cloro. Su azul intenso con venas blancas de calcita la distingue del lapislázuli. En la tradición lapidaria moderna se asigna a Júpiter por su azul jovial y su efecto en la claridad mental y el juicio honesto. Agrippa (Lib. I) vincula las piedras azules con Júpiter. Es la piedra del pensador y del buscador de verdad: se dice que disuelve la culpa irracional y el miedo a la verdad propia.",
             "fuente": "Agrippa, Lib. I (azul → Júpiter); tradición lapidaria contemporánea",
         }),

    dict(slug="ojo-de-tigre", item_type="stone", name="Ojo de Tigre", planet="sun", element="fuego",
         aliases=["Tiger's Eye", "Ojo de gato solar"],
         properties={
             "intenciones": ["discernimiento", "protección", "voluntad", "claridad de propósito"],
             "notas": "Cuarzo solar con chatoyance; el ojo que todo lo ve — protección y discernimiento marcial.",
             "estudio": "El ojo de tigre es cuarzo fibroso (SiO₂) con inclusiones de crocidolita (amianto azul) oxidada que le dan el efecto óptico de 'chatoyance' (ojo de gato). Su color dorado-pardo y el efecto visual del ojo que sigue al observador lo convirtieron en amuleto apotropaico universal. Los soldados romanos llevaban ojos de tigre tallados en sus armaduras. Agrippa vincula las piedras dorado-solares con la fortaleza y la visión. En magia protege de la envidia y el mal de ojo, y aclara la visión interior.",
             "fuente": "Agrippa, Lib. I (dorado → Sol); tradición lapidaria romana",
         }),

    dict(slug="piedra-luna", item_type="stone", name="Piedra de Luna", planet="moon", element="agua",
         aliases=["Moonstone", "Adularia", "Selenita"],
         properties={
             "intenciones": ["intuición", "ciclos", "diosa", "sueños", "fertilidad"],
             "notas": "Feldespato lunar con adularescencia; la piedra de la Luna y los ciclos femeninos.",
             "estudio": "La piedra de luna es feldespato (ortoclasa o adularia) con capas alternas de albita que producen 'adularescencia' — un resplandor azulado-blanco que parece moverse en el interior. En la India es una piedra sagrada que trae buena fortuna y clarividencia. Plinio (Historia Natural XXXVII) afirma que la piedra de luna cambia con las fases de la luna. Agrippa (Lib. I) asigna las piedras blancas-plateadas a la Luna. Es la piedra del trabajo lunar por excelencia: amplifica la intuición, regula los ritmos corporales y abre la percepción en los sueños.",
             "fuente": "Agrippa, Lib. I; Plinio, Historia Natural XXXVII; tradición hindu (Chandrakanta)",
         }),

    dict(slug="granate", item_type="stone", name="Granate", planet="mars", element="fuego",
         aliases=["Garnet", "Granada (gema)"],
         properties={
             "intenciones": ["pasión", "vitalidad", "coraje", "amor sensual"],
             "notas": "Gema marcial de color sangre; activa la fuerza vital, la pasión y el coraje en la acción.",
             "estudio": "El granate (grupo mineralógico: almandino, piropo, espesartina, etc.) fue una de las gemas más apreciadas del mundo antiguo. Su nombre deriva del latín 'granatum' (granada) por la semejanza de los cristales con las semillas del fruto. Agrippa (Lib. I) lo asigna a Marte por su color rojizo-sangre. En la tradición medieval, los cruzados llevaban granates como protección en batalla. Los gnósticos lo usaron en sellos y amuletos. En magia trabaja la fuerza vital, la sexualidad sagrada y el coraje ante la adversidad.",
             "fuente": "Agrippa, Lib. I; tradición lapidaria medieval",
         }),

    dict(slug="esmeralda", item_type="stone", name="Esmeralda", planet="venus", element="tierra",
         aliases=["Emerald", "Berilo verde"],
         properties={
             "intenciones": ["amor", "prosperidad", "visión", "fidelidad"],
             "notas": "Gema venusina del color de Venus; piedra de Hermes Trismegisto según la leyenda hermética.",
             "estudio": "La esmeralda (berilo con cromo y vanadio) es una de las cuatro gemas preciosas clásicas. La mítica *Tabla Esmeralda* de Hermes Trismegisto fue grabada supuestamente en esmeralda — el soporte material del principio hermético 'como arriba, abajo'. Agrippa (Lib. I) la asigna a Venus y Mercurio. Los aztecas la llamaban 'quetzalitzli' y la veneraban. Cleopatra tenía minas de esmeralda en el Mar Rojo. En la Golden Dawn (*777*) aparece bajo Venus. En magia: amor fiel, visión profética y atracción de prosperidad duradera.",
             "fuente": "Agrippa, Lib. I; Tabla Esmeralda (Hermes Trismegisto); Golden Dawn, 777",
         }),

    dict(slug="zafiro", item_type="stone", name="Zafiro", planet="jupiter", element="aire",
         aliases=["Sapphire", "Corindón azul"],
         properties={
             "intenciones": ["sabiduría", "justicia", "devoción", "elevación espiritual"],
             "notas": "Gema jovial de los reyes y los cielos; piedra del juicio recto y la devoción sincera.",
             "estudio": "El zafiro (corindón Al₂O₃ con titanio y hierro) es la segunda piedra más dura después del diamante. En la tradición judía, las Tablas de la Ley eran de zafiro. En el Medievo cristiano, los obispos usaban anillos de zafiro. Agrippa (Lib. I) lo asigna a Júpiter por su azul celestial. Dante viste a Beatriz en el Paraíso con el azul del zafiro. En la Golden Dawn (*777*, col. Júpiter). En magia: eleva la mente hacia la sabiduría divina, protege la honestidad y fortalece la devoción espiritual.",
             "fuente": "Agrippa, Lib. I; Golden Dawn, 777; Biblia hebrea (Éxodo 24:10)",
         }),

    dict(slug="rubí", item_type="stone", name="Rubí", planet="mars", element="fuego",
         aliases=["Ruby", "Corindón rojo"],
         properties={
             "intenciones": ["pasión", "poder", "protección", "vitalidad"],
             "notas": "Gema marcial del color de la sangre; piedra de reyes guerreros y protección ante el peligro.",
             "estudio": "El rubí (corindón con cromo) fue la gema más valiosa del mundo antiguo — llamado 'ratnaraj' (rey de las gemas) en el Sanskrit. Marco Polo describió los rubíes birmanos como los más hermosos de la tierra. Agrippa (Lib. I) lo asigna a Marte por su color rojo-fuego. En la tradición medieval europea, los rubíes protegían a los guerreros: se incrustaban en las armaduras. Se creía que el rubí no perdía su lustre en la sangre — a diferencia del granate. En la Golden Dawn aparece bajo Marte y Geburah (Sephirah de la severidad).",
             "fuente": "Agrippa, Lib. I; Golden Dawn, 777; Marco Polo, Il Milione",
         }),

    dict(slug="perla", item_type="stone", name="Perla", planet="moon", element="agua",
         aliases=["Pearl", "Perla natural"],
         properties={
             "intenciones": ["pureza", "intuición", "femineidad", "protección en el mar"],
             "notas": "Joya lunar nacida del mar; nacre de ostra que captura la luz como la luna captura el sol.",
             "estudio": "La perla es el único 'gem' de origen orgánico (secretado por moluscos). Su color blanco-plateado y su origen en las aguas la vinculan inequívocamente a la Luna. Agrippa (Lib. I) la asigna a la Luna. En China, las perlas caían del cielo durante tormentas — eran la esencia de la luna condensada en agua. En el mundo islámico medieval, las huríes del Paraíso se comparaban con perlas ocultas. Dioscórides (V.140 aprox.) menciona la perla en preparaciones médicas. En magia protege a marineros y viajeros por el mar, amplifica la intuición femenina y preserva la pureza de intención.",
             "fuente": "Agrippa, Lib. I; Dioscórides, De Materia Medica V; tradición china y árabe medieval",
         }),

    dict(slug="cuarzo-ahumado", item_type="stone", name="Cuarzo Ahumado", planet="saturn", element="tierra",
         aliases=["Smoky Quartz", "Morión"],
         properties={
             "intenciones": ["anclaje", "protección", "transmutación", "limpieza"],
             "notas": "Cuarzo saturnino de color humo; ancla la energía a la tierra y transmuta lo negativo.",
             "estudio": "El cuarzo ahumado (SiO₂ con centros de color producidos por irradiación natural) varía del marrón tostado al negro intenso (morión). Su color oscuro lo vincula a Saturno. Agrippa (Lib. I) asigna las piedras oscuras/negras a Saturno. En Escocia, los puñales celtas (sgian-dubh) a veces tenían pomo de cuarzo ahumado — conexión con la tierra y la protección. En magia es el ancla física del ritual: coloca el cuarzo ahumado en los cuatro puntos del círculo mágico para enraizar la energía.",
             "fuente": "Agrippa, Lib. I (oscuro → Saturno); tradición celta escocesa",
         }),
]
