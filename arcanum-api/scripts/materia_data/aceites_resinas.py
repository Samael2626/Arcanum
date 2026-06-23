"""Materia Arcana — Aceites y resinas adicionales.
Fuentes: Agrippa Lib. I, Dioscórides, Culpeper, tradición hermética occidental.
"""

ACEITES_RESINAS: list[dict] = [
    dict(slug="resina-pino", item_type="resin", name="Resina de Pino", planet="mars", element="fuego",
         aliases=["Pine Resin", "Colofonia", "Pinus sylvestris"],
         properties={
             "intenciones": ["purificación", "protección", "curación", "limpieza"],
             "notas": "Resina marcial del pino; antiséptica y purificadora, limpia el aire y ahuyenta lo estancado.",
             "estudio": "La trementina y la resina de pino fueron ampliamente usadas por Dioscórides (I.71-75) para heridas, enfermedades pulmonares y como vulnerarios. Culpeper asigna el pino al Sol (por su tamaño y vitalidad) aunque la resina activa tiene cualidades marciales. En la tradición escandinava y báltica, la resina de pino o ámbaro (resina fosilizada) era el material sagrado protector por excelencia. En magia: quemar resina de pino limpia ambientes con acumulación de energía densa y protege el hogar en invierno.",
             "fuente": "Dioscórides, De Materia Medica I.71; Culpeper, Complete Herbal",
         }),

    dict(slug="aceite-solar", item_type="oil", name="Aceite Solar", planet="sun", element="fuego",
         aliases=["Sun Oil", "Aceite de consagración solar"],
         properties={
             "intenciones": ["éxito", "vitalidad", "consagración", "autoridad", "visibilidad"],
             "notas": "Aceite talismánico del Sol; se usa para ungir velas, herramientas y la frente en rituales solares.",
             "estudio": "El aceite solar tradicional se compone de ingredientes asignados al Sol por Agrippa (Lib. I y II): olíbano, laurel, canela, hipérico, miel y aceite de almendra como base. La fórmula se prepara en domingo, en la hora del Sol, idealmente en luna creciente o en el solsticio de verano. En la tradición hoodoo, el 'Crown of Success oil' es el equivalente funcional. En la magia ceremonial se unge el sello de Miguel o el cuadrado del Sol grabado en oro. Su uso principal es consagrar y activar objetos de trabajo solar.",
             "fuente": "Agrippa, Lib. I & II; tradición de la Golden Dawn; Mathers, The Key of Solomon",
         }),

    dict(slug="aceite-lunar", item_type="oil", name="Aceite Lunar", planet="moon", element="agua",
         aliases=["Moon Oil", "Aceite de la Luna"],
         properties={
             "intenciones": ["intuición", "sueños", "psiquismo", "trabajo astral", "ciclos"],
             "notas": "Aceite talismánico de la Luna; se prepara en lunes noche y activa el trabajo oracular y de sueños.",
             "estudio": "El aceite lunar tradicional combina ingredientes lunares de Agrippa: jazmín, sauce (extracto), alcanfor, lirio blanco, aceite de coco y perla en polvo. Se prepara en lunes, en la hora de la Luna, idealmente en luna llena o nueva según la intención. La luna nueva potencia los aceites de inicio y atracción; la luna llena los de visión y plenitud. En la magia ceremonial se unge el sello de Gabriel o el cuadrado de la Luna grabado en plata.",
             "fuente": "Agrippa, Lib. I & II; tradición de la Golden Dawn; tradición hoodoo (Moonlight oil)",
         }),

    dict(slug="aceite-mercurial", item_type="oil", name="Aceite Mercurial", planet="mercury", element="aire",
         aliases=["Mercury Oil", "Aceite de Mercurio"],
         properties={
             "intenciones": ["comunicación", "estudio", "negocios", "viajes", "escritura"],
             "notas": "Aceite talismánico de Mercurio; activa la mente, la memoria y la fluidez en la comunicación.",
             "estudio": "El aceite mercurial tradicional usa ingredientes de Mercurio según Agrippa: lavanda, menta, eneldo, nuez (extracto), aceite de almendra mezclado. Se prepara en miércoles, hora de Mercurio. Se unge en herramientas de escritura, libros de estudio, teléfonos o contratos antes de firmar. En la tradición hoodoo, el 'Mercury oil' o 'Fast Luck oil' cumple funciones similares para el comercio y la comunicación. También se usa antes de negociaciones, exámenes y viajes importantes.",
             "fuente": "Agrippa, Lib. I & II; tradición de la Golden Dawn; hoodoo (Fast Luck)",
         }),

    dict(slug="aceite-venusino", item_type="oil", name="Aceite Venusino", planet="venus", element="agua",
         aliases=["Venus Oil", "Aceite de Venus", "Aceite de amor"],
         properties={
             "intenciones": ["amor", "atracción", "belleza", "placer", "arte"],
             "notas": "Aceite talismánico de Venus; el aceite de atracción y amor más documentado en las tradiciones mágicas.",
             "estudio": "El aceite venusino combina rosa, verbena, díctamo, tomillo, mirto y aceite de rosa como base. Se prepara en viernes, hora de Venus, idealmente en luna creciente. La tradición de ungüentos de amor tiene raíces en el mundo greco-romano (Ovidio, *Ars Amatoria*; papiros mágicos griegos, PGM). Agrippa (Lib. I) lista los ingredientes venusinos para elaborar perfumes y ungüentos de amor. El aceite de rosa es el más venusino de todos: 30 kg de pétalos = 1 gota de aceite esencial de rosa absoluta.",
             "fuente": "Agrippa, Lib. I & II; PGM (Papiros Mágicos Griegos); Golden Dawn",
         }),

    dict(slug="aceite-marcial", item_type="oil", name="Aceite Marcial", planet="mars", element="fuego",
         aliases=["Mars Oil", "Aceite de Marte", "Aceite de protección"],
         properties={
             "intenciones": ["protección", "fuerza", "coraje", "destierro", "confrontación"],
             "notas": "Aceite talismánico de Marte; para ungir amuletos de protección y reforzar la voluntad ante la adversidad.",
             "estudio": "El aceite marcial combina ruda, ajo, jengibre, pimienta negra, sangre de drago y aceite de base. Se prepara en martes, hora de Marte. Agrippa (Lib. I) lista los ingredientes marciales para operaciones de protección y confrontación. En la tradición hoodoo se llama 'War Water' (en forma acuosa) o 'Mars Oil' para protección agresiva. Se unge en umbrales, herramientas de defensa y el cuerpo en situaciones de confrontación necesaria.",
             "fuente": "Agrippa, Lib. I & II; tradición hoodoo; Golden Dawn",
         }),

    dict(slug="aceite-jovial", item_type="oil", name="Aceite Jovial", planet="jupiter", element="aire",
         aliases=["Jupiter Oil", "Aceite de Júpiter", "Aceite de prosperidad"],
         properties={
             "intenciones": ["prosperidad", "abundancia", "expansión", "suerte", "justicia"],
             "notas": "Aceite talismánico de Júpiter; para atraer prosperidad, oportunidades y el favor de la fortuna.",
             "estudio": "El aceite jovial combina cedro, hisopo, salvia, nuez moscada, clavo y aceite de girasol como base. Se prepara en jueves, hora de Júpiter, idealmente en luna creciente o llena. Agrippa (Lib. I) lista ingredientes joviales para talismanes de prosperidad. En la tradición ceremonial, se unge el cuadrado mágico de Júpiter (♃ grabado en estaño) o billetes de dinero. En hoodoo, el 'Money Drawing oil' o 'Jupiter oil' es uno de los más vendidos.",
             "fuente": "Agrippa, Lib. I & II; Golden Dawn; tradición hoodoo (Money Drawing)",
         }),

    dict(slug="aceite-saturnino", item_type="oil", name="Aceite Saturnino", planet="saturn", element="tierra",
         aliases=["Saturn Oil", "Aceite de Saturno"],
         properties={
             "intenciones": ["límites", "destierro profundo", "trabajo con ancestros", "karma"],
             "notas": "Aceite talismánico de Saturno; para rituales de destierro, trabajo ctónico y límites firmes.",
             "estudio": "El aceite saturnino combina ciprés, mirra, gálbano, cedro negro, opopónax y aceite de sésamo como base. Se prepara en sábado, hora de Saturno, en luna menguante o nueva. Agrippa (Lib. I) lista ingredientes saturninos para operaciones de destierro y sellado. El aceite saturnino es el más potente para cortar vínculos, establecer límites ineludibles y honrar a los ancestros. No se recomienda a principiantes sin contexto adecuado de trabajo con Saturno.",
             "fuente": "Agrippa, Lib. I & II; Golden Dawn; tradición ceremonial occidental",
         }),

    dict(slug="trementina", item_type="resin", name="Trementina", planet="mars", element="fuego",
         aliases=["Turpentine", "Aguarrás natural", "Oleoresina de conífera"],
         properties={
             "intenciones": ["limpieza profunda", "purificación", "destierro de plagas"],
             "notas": "Oleoresina marcial de los pinos; limpieza agresiva y purificación física de espacios.",
             "estudio": "La trementina (oleoresina de Pinus, Abies y otros géneros de coníferas) fue el solvente y antiséptico más usado en la medicina occidental hasta el siglo XIX. Dioscórides (I.71) describe la 'terebintina' del terebinto (Pistacia terebinthus) como vulneraria y útil para los pulmones. Agrippa la incluye en preparados marciales. En la medicina tradicional griega y árabe se inhalaba para purificar los bronquios. En el contexto mágico, la trementina pura (sin mezcla petroquímica) se usa en limpias de espacios físicos muy contaminados.",
             "fuente": "Dioscórides, De Materia Medica I.71; Agrippa, Lib. I",
         }),

    dict(slug="resina-elemí", item_type="resin", name="Elemí", planet="mercury", element="aire",
         aliases=["Elemi", "Canarium luzonicum", "Resina de Manila"],
         properties={
             "intenciones": ["claridad mental", "comunicación", "equilibrio cuerpo-mente", "meditación"],
             "notas": "Resina mercurial del Pacífico; equilibra mente y cuerpo y aclara el pensamiento antes del ritual.",
             "estudio": "El elemí (Canarium luzonicum, Filipinas) es una resina con aroma de limón-hinojo-pimienta. Fue muy usada en Europa del siglo XVI al XIX como componente de barnices y ungüentos medicinales — aparece en formularios renacentistas. Por su aroma fresco y mentolado se asigna a Mercurio. En aromaterapia moderna se valora para equilibrar la mente activa y calmar el pensamiento excesivo. En la tradición mágica hermética se usa en inciensos de meditación intelectual y preparación para trabajo oracular.",
             "fuente": "Formularios farmacéuticos renacentistas (s. XVI-XVIII); tradición aromática hermética",
         }),

    dict(slug="resina-labdano", item_type="resin", name="Ládano", planet="saturn", element="tierra",
         aliases=["Labdanum", "Ládano", "Cistus ladanifer"],
         properties={
             "intenciones": ["meditación profunda", "trabajo ctónico", "conexión ancestral", "umbral"],
             "notas": "Resina saturnina oscura y terrosa de la jara; el 'ámbar gris vegetal' de la tradición árabe.",
             "estudio": "El ládano (Cistus ladanifer) es la resina oscura y balsámica de la jara mediterránea. Fue el 'ladanum' de los fenicios — obtenido peinando las barbas de las cabras que pastaban entre las jaras. Dioscórides (I.97) lo describe extensamente. Herodoto menciona que los beduinos lo cosechaban de las barbas de las cabras (Historia II.86). En la tradición árabe medieval se usó como fijador de perfumes — es el 'ámbar gris vegetal' por su persistencia. Su aroma oscuro, terroso y animal lo vincula a Saturno. En magia es el incienso de lo profundo y lo antiguo.",
             "fuente": "Dioscórides, De Materia Medica I.97; Herodoto, Historias II.86; tradición perfumera árabe",
         }),

    dict(slug="aceite-oliva-sagrado", item_type="oil", name="Aceite de Oliva Consagrado", planet="sun", element="fuego",
         aliases=["Holy Olive Oil", "Aceite de la lámpara", "Olea europaea"],
         properties={
             "intenciones": ["consagración", "bendición", "unción", "paz", "curación"],
             "notas": "El aceite sagrado universal de todas las tradiciones mediterráneas; base de toda unción ritual.",
             "estudio": "El aceite de oliva es la base de la unción sagrada en el judaísmo (Éxodo 30:22-33, el aceite de la Menorá), el cristianismo (Extremaunción, Confirmación) y el Islam. Dioscórides (I.30) dedica una entrada extensa al aceite de oliva. Agrippa lo usa como vehículo neutro-solar para ungüentos y aceites planetarios. En la magia griega y romana, el aceite de oliva era la ofrenda más común a los dioses domésticos (Lares). Consagrado en domingo con oración o intención, se convierte en el aceite de bendición más versátil.",
             "fuente": "Éxodo 30:22-33; Dioscórides, De Materia Medica I.30; Agrippa, Lib. I",
         }),

    dict(slug="resina-mastix", item_type="resin", name="Mástic", planet="mercury", element="aire",
         aliases=["Mastic", "Goma lentisco", "Pistacia lentiscus"],
         properties={
             "intenciones": ["comunicación", "claridad", "consagración", "protección"],
             "notas": "Resina mercurial del lentisco de Quíos; incienso de templo egipcio y griego desde 3.000 años.",
             "estudio": "El mástic (Pistacia lentiscus var. Chia) se cosecha en la isla griega de Quíos desde hace más de 2.500 años con el método tradicional (knistrí). Dioscórides (I.90) lo describe extensamente para digestión, dientes y ungüentos. Fue uno de los inciensos del Templo. Agrippa lo usa en formulaciones mercuriales. La Golden Dawn lo incluye en el incienso de Mercurio. Su humo es claro y fresco — no irrita los ojos, ideal para espacios de trabajo prolongado. Hoy el'chicle de Quíos' es la versión comestible del mismo árbol.",
             "fuente": "Dioscórides, De Materia Medica I.90; Agrippa, Lib. I; Golden Dawn, 777",
         }),
]
