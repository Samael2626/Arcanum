"""Materia Arcana — Hierbas. Fuentes: Culpeper, Dioscórides, Agrippa Lib. I."""

HIERBAS: list[dict] = [
    # ── EXISTENTES (mantenidas en seed_materia.py, no duplicar) ──────────────
    # romero, lavanda, rosa, canela, artemisa, salvia — ya sembradas

    # ── NUEVAS ────────────────────────────────────────────────────────────────
    dict(slug="ruda", item_type="herb", name="Ruda", planet="mars", element="fuego",
         aliases=["Rue", "Ruta graveolens"],
         properties={
             "intenciones": ["protección", "destierro", "ruptura de maleficios"],
             "notas": "Hierba marcial de exorcismo; la más usada en el mundo hispano para destierro de mal de ojo.",
             "estudio": "Ruta graveolens fue descrita por Dioscórides (De Materia Medica III.45) como potente antídoto y abortivo. Culpeper la asigna a Marte en Aries, subrayando su carácter agresivo-protector. En la tradición latinoamericana y mediterránea es la hierba de destierro por excelencia: se coloca en la entrada del hogar, se baña con infusión o se porta como amuleto. Agrippa (Lib. I) la incluye entre las plantas de virtud marcial. ADVERTENCIA: el aceite esencial es altamente tóxico; el contacto con la piel causa fotodermatitis severa; ingerida en cantidad provoca aborto y daño hepático.",
             "parte": "hojas",
             "toxicidad": "TÓXICA — fotodermatitis por contacto; abortiva en dosis altas; no ingerir aceite esencial",
             "fuente": "Dioscórides, De Materia Medica III.45; Culpeper, Complete Herbal; Agrippa, Lib. I",
         }),

    dict(slug="verbena", item_type="herb", name="Verbena", planet="venus", element="agua",
         aliases=["Vervain", "Verbena officinalis", "Hierba de todos los santos"],
         properties={
             "intenciones": ["amor", "protección", "purificación", "profecía"],
             "notas": "Hierba sagrada de Venus; los druidas la usaban en rituales de adivinación y consagración.",
             "estudio": "Verbena officinalis fue reverenciada en el mundo greco-romano como *herba sacra*: se usaba para purificar altares de Júpiter y en la diplomacia romana. Culpeper la asigna a Venus, subrayando sus virtudes en el amor y la curación de dolencias venéreas. Dioscórides (IV.60) la menciona como vulneraria y antiinflamatoria. En la tradición mágica europea es hierba de juramentos, adivinación y apertura de espacios sagrados. Agrippa la incluye entre las plantas de poder venusino. Hoy el nombre 'verbena' se aplica también a Aloysia citrodora (verbena de limón), que no comparte estas correspondencias históricas.",
             "parte": "hojas y flores",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica IV.60; Culpeper, Complete Herbal; Agrippa, Lib. I",
         }),

    dict(slug="belladona", item_type="herb", name="Belladona", planet="saturn", element="agua",
         aliases=["Deadly Nightshade", "Atropa belladonna", "Bella dama"],
         properties={
             "intenciones": ["visiones", "vuelo astral", "trabajo ctónico"],
             "notas": "Planta de Saturno y Hécate; usada en ungüentos de vuelo de brujas medievales. VENENOSA.",
             "estudio": "Atropa belladonna contiene atropina, hiosciamina y escopolamina — alcaloides del tropano que producen alucinaciones, taquicardia y en dosis altas la muerte. Dioscórides (IV.73) advierte que 'la cantidad de una dracma produce delirio suave; más, locura persistente; cuatro dracmas matan'. Culpeper la asigna a Saturno, planeta de lo sombrío y lo mortal. Los ungüentos de vuelo medievales (Porta, *Magia Naturalis*) combinaban belladona con otras solanáceas — la absorción transdérmica de alcaloides generaba las 'experiencias de vuelo'. Su nombre italiano (bella donna) alude al uso cosmético: las cortesanas dilataban las pupilas con el jugo para parecer más atractivas.",
             "parte": "hojas y raíz (uso ritual externo únicamente)",
             "toxicidad": "VENENOSA — dosis mínima letal en niños; no ingerir jamás; contacto cutáneo prolongado peligroso",
             "fuente": "Dioscórides, De Materia Medica IV.73; Culpeper, Complete Herbal; Porta, Magia Naturalis",
         }),

    dict(slug="mandragora", item_type="herb", name="Mandrágora", planet="mercury", element="tierra",
         aliases=["Mandrake", "Mandragora officinarum", "Mano de hombre"],
         properties={
             "intenciones": ["poder", "amor", "fertilidad", "protección del hogar"],
             "notas": "Raíz antropomórfica de Mercurio; fetiche de poder por excelencia en la tradición europea.",
             "estudio": "Mandragora officinarum fue la planta más mítica del mundo antiguo y medieval. Dioscórides (IV.75) describe sus usos como anestésico (vino de mandrágora), hipnótico y para el amor. Agrippa (Lib. I, cap. XLVII) la asigna a Mercurio por su forma humana — aplicación directa de la doctrina de las signaturas. El grito legendario al arrancarla (que mata al que lo oye) refleja el terror que inspiraba: los recolectores usaban perros para extraerla. Contiene escopolamina, hiosciamina y atropina como la belladona. La raíz bifurcada se usaba como imagen mágica ('poppet') para encantamientos de amor y protección doméstica.",
             "parte": "raíz",
             "toxicidad": "VENENOSA — mismos alcaloides del tropano que la belladona; no ingerir",
             "fuente": "Dioscórides, De Materia Medica IV.75; Agrippa, Lib. I cap. XLVII; Culpeper, Complete Herbal",
         }),

    dict(slug="ajenjo", item_type="herb", name="Ajenjo", planet="mars", element="fuego",
         aliases=["Wormwood", "Artemisia absinthium", "Absenta"],
         properties={
             "intenciones": ["adivinación", "invocación", "destierro de espíritus"],
             "notas": "Hierba marcial de Marte; potencia la percepción en rituales. Ingrediente de la absenta.",
             "estudio": "Artemisia absinthium es distinta de la artemisa (A. vulgaris) del seed actual. Culpeper la asigna a Marte por su sabor amargo extremo y su acción estimulante-agresiva sobre la digestión. Dioscórides (III.23) la usa como antihelmíntico, estomacal y antídoto. En la tradición mágica se quema para potenciar la clarividencia y la comunicación con espíritus, o se añade a el calíx de adivinación. La thuyone (principio activo) es neurotóxica en dosis altas — la absenta del siglo XIX en exceso causaba alucinaciones y convulsiones ('absintismo').",
             "parte": "hojas y sumidades floridas",
             "toxicidad": "leve — la thuyone es neurotóxica en dosis muy altas; no ingerir aceite esencial puro",
             "fuente": "Dioscórides, De Materia Medica III.23; Culpeper, Complete Herbal",
         }),

    dict(slug="hiperico", item_type="herb", name="Hipérico", planet="sun", element="fuego",
         aliases=["Hierba de San Juan", "St. John's Wort", "Hypericum perforatum"],
         properties={
             "intenciones": ["protección", "elevación", "exorcismo", "salud"],
             "notas": "Hierba solar del solsticio; florece en San Juan y protege contra influencias oscuras.",
             "estudio": "Hypericum perforatum es el ejemplo paradigmático de la doctrina de las signaturas: sus hojas tienen glándulas translúcidas que parecen perforaciones (poros de la piel), y el fluido de las flores es rojo sangre — ambas firmas de planta solar y vulneraria. Culpeper la asigna al Sol en Aries. Florece en el solsticio de verano (San Juan, 24 de junio), lo que la vincula al sol en su cénit. Se colgaba en puertas en la víspera de San Juan para expulsar demonios. En fitoterapia moderna, sus extractos (hipericina, hiperforina) están clínicamente validados para depresión leve-moderada. Interacciona con numerosos fármacos (anticoagulantes, anticonceptivos) por inducción del CYP3A4.",
             "parte": "flores y sumidades",
             "toxicidad": "leve — fotosensibilizante en uso tópico; interacciones farmacológicas importantes",
             "fuente": "Culpeper, Complete Herbal; Doctrina de las Signaturas (Böhme, Signatura Rerum)",
         }),

    dict(slug="laurel", item_type="herb", name="Laurel", planet="sun", element="fuego",
         aliases=["Bay Laurel", "Laurus nobilis", "Laurel noble"],
         properties={
             "intenciones": ["éxito", "purificación", "profecía", "victoria"],
             "notas": "Árbol solar de Apolo; las pitonisas de Delfos mascaban sus hojas para profetizar.",
             "estudio": "Laurus nobilis fue la planta sagrada de Apolo en el mundo greco-romano. Las sacerdotisas del oráculo de Delfos quemaban sus hojas e inhalaban el humo, y según algunas fuentes masticaban las hojas antes de profetizar. Culpeper lo asigna al Sol en Aries. En Roma, las coronas de laurel coronaban a generales victoriosos y poetas. Dioscórides (I.78) describe sus usos digestivos y para picaduras de animales. En práctica mágica: escribir una intención en la hoja y quemarla es una de las operaciones más simples y documentadas de magia simpática solar.",
             "parte": "hojas",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica I.78; Culpeper, Complete Herbal",
         }),

    dict(slug="hisopo", item_type="herb", name="Hisopo", planet="jupiter", element="fuego",
         aliases=["Hyssop", "Hyssopus officinalis"],
         properties={
             "intenciones": ["purificación", "limpieza ritual", "protección"],
             "notas": "Hierba bíblica de purificación: 'purifícame con hisopo y quedaré limpio' (Salmo 51).",
             "estudio": "Hyssopus officinalis aparece en el Antiguo Testamento (Éxodo 12:22, Números 19:18, Salmo 51:9) como el agente ritual de purificación por excelencia. Culpeper lo asigna a Júpiter. Dioscórides (III.25) lo usa como expectorante y para dolencias pulmonares. En la tradición hermética es hierba de limpieza de espacios y personas antes de operaciones rituales importantes. Se usa en aspersión (rama en agua) o como sahumerio.",
             "parte": "sumidades floridas",
             "toxicidad": "leve — el aceite esencial contiene pinocamfona, epileptogénica en dosis altas; no ingerir aceite puro",
             "fuente": "Dioscórides, De Materia Medica III.25; Culpeper, Complete Herbal; Biblia hebrea (Salmo 51)",
         }),

    dict(slug="milenrama", item_type="herb", name="Milenrama", planet="venus", element="agua",
         aliases=["Yarrow", "Achillea millefolium", "Aquilea"],
         properties={
             "intenciones": ["amor", "coraje", "adivinación", "curación"],
             "notas": "Hierba de Aquiles; se dice que la usó para curar a sus soldados en Troya. Venusina y marcial.",
             "estudio": "Achillea millefolium lleva el nombre del héroe Aquiles, quien según Plinio la usó para detener la hemorragia de sus soldados (propiedad hemostática confirmada por la fitoquímica: contiene aquileína y flavonoides). Culpeper la asigna a Venus, aunque su virtud marcial (curar heridas de guerra) es evidente. En la tradición china, los tallos secos de milenrama son el instrumento clásico del I Ching. Dioscórides (IV.36) la usa en heridas y úlceras. En la magia europea: abre la percepción amorosa y fortalece el coraje en oráculos.",
             "parte": "flores y hojas",
             "toxicidad": "leve — puede causar dermatitis de contacto en personas alérgicas a asteráceas",
             "fuente": "Dioscórides, De Materia Medica IV.36; Culpeper, Complete Herbal; Plinio, Historia Natural",
         }),

    dict(slug="dictamo-cretense", item_type="herb", name="Díctamo Cretense", planet="venus", element="agua",
         aliases=["Dittany of Crete", "Origanum dictamnus", "Dictámamo"],
         properties={
             "intenciones": ["amor", "apariciones", "trabajo astral", "adivinación"],
             "notas": "Hierba venusina de Creta; en magia ceremonial se quema para materializar apariciones en el humo.",
             "estudio": "Origanum dictamnus es endémico de Creta y fue celebrado en toda la Antigüedad por sus virtudes casi milagrosas: Aristóteles y Teofrasto afirman que las cabras montesas heridas de flecha buscaban y comían esta hierba para expulsar el proyectil. Dioscórides (III.34) la describe como vulneraria y para inducir el parto. Culpeper la asigna a Venus por su aroma suave y virtudes curativas de afecto. En la tradición ceremonial occidental se usa como incienso para convocar apariciones: el humo denso sirve de 'pantalla' para la visión. La Golden Dawn (Israel Regardie, *The Complete Golden Dawn System*) la cita en este uso.",
             "parte": "hojas y flores",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica III.34; Teofrasto, Historia Plantarum; Culpeper, Complete Herbal",
         }),

    dict(slug="valeriana", item_type="herb", name="Valeriana", planet="mercury", element="agua",
         aliases=["Valerian", "Valeriana officinalis", "Hierba de los gatos"],
         properties={
             "intenciones": ["sueño", "calma", "amor", "purificación"],
             "notas": "Hierba de Mercurio; calma la mente nerviosa y se usa en bolsas de amor por su aroma que atrae gatos.",
             "estudio": "Valeriana officinalis fue descrita por Dioscórides (I.10) como calmante y carminativa. Culpeper la asigna a Mercurio, planeta que rige la mente y el sistema nervioso. Sus raíces contienen ácido valérico y valepotriatos, con efecto sedante leve validado clínicamente. En la magia popular europea se incluye en bolsas de amor (el aroma atrae irresistiblemente a los gatos — analogía mágica con la atracción). También se usa para purificar espacios y favorecer el sueño oracular.",
             "parte": "raíz",
             "toxicidad": "no — sedante leve; no combinar con alcohol o benzodiacepinas",
             "fuente": "Dioscórides, De Materia Medica I.10; Culpeper, Complete Herbal",
         }),

    dict(slug="menta-piperita", item_type="herb", name="Menta", planet="mercury", element="aire",
         aliases=["Peppermint", "Mentha piperita", "Hierbabuena"],
         properties={
             "intenciones": ["claridad mental", "prosperidad", "purificación", "viaje"],
             "notas": "Hierba mercurial; aclara la mente y acelera el movimiento de energías.",
             "estudio": "Mentha piperita (híbrido de M. aquatica × M. spicata) fue usada en Egipto y Grecia. Culpeper asigna la menta a Venus en algunos textos y a Mercurio en otros — la correspondencia mercurial predomina en la tradición mágica por su acción estimulante mental. Dioscórides (III.34 aprox.) menciona varias mentas para digestión y dolor de cabeza. En magia: frotar las manos con aceite de menta antes de negociaciones activa la prosperidad; quemar o colocar hojas frescas atrae el dinero y despeja la mente para el estudio.",
             "parte": "hojas",
             "toxicidad": "no — el aceite esencial puro es tóxico en niños pequeños",
             "fuente": "Culpeper, Complete Herbal; Dioscórides, De Materia Medica III",
         }),

    dict(slug="tomillo", item_type="herb", name="Tomillo", planet="venus", element="aire",
         aliases=["Thyme", "Thymus vulgaris"],
         properties={
             "intenciones": ["coraje", "purificación", "salud", "sueño"],
             "notas": "Hierba venusina del coraje; en la Edad Media caballeros llevaban ramas de tomillo al combate.",
             "estudio": "Thymus vulgaris fue descrito por Dioscórides (III.36) como expectorante, antihelmíntico y para la tos. Culpeper lo asigna a Venus en Aries. En la tradición escocesa e inglesa, las hadas moraban bajo los tomillos silvestres. Los caballeros medievales bordaban ramas de tomillo en sus estandartes y llevaban sprigs de la planta — símbolo de coraje. En magia: quemar tomillo limpia el pasado, favorece el sueño sin pesadillas y atrae salud. El timol (principio activo) es un antiséptico potente, validado científicamente.",
             "parte": "hojas y flores",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica III.36; Culpeper, Complete Herbal",
         }),

    dict(slug="mejorana", item_type="herb", name="Mejorana", planet="mercury", element="aire",
         aliases=["Marjoram", "Origanum majorana", "Mayorana"],
         properties={
             "intenciones": ["amor", "felicidad", "protección del hogar", "duelo"],
             "notas": "Hierba de Mercurio; en Grecia se plantaba en tumbas y se tejía en coronas nupciales.",
             "estudio": "Origanum majorana fue sagrada para Afrodita/Venus en el mundo greco-romano: se tejía en coronas de bodas y se plantaba en tumbas para asegurar la felicidad del difunto. Dioscórides (III.39) la describe como calorífica y digestiva. Culpeper la asigna a Mercurio. En la tradición popular: llevar mejorana atrae el amor; colocarla en el hogar trae paz; incluirla en bolsas de protección ahuyenta la melancolía. Su aroma suave y el carácter dual (bodas y tumbas) la hace única en la herbolaria mágica.",
             "parte": "hojas y flores",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica III.39; Culpeper, Complete Herbal",
         }),

    dict(slug="agrimonia", item_type="herb", name="Agrimonia", planet="jupiter", element="aire",
         aliases=["Agrimony", "Agrimonia eupatoria", "Hierba de San Guillermo"],
         properties={
             "intenciones": ["protección", "sueño", "inversión de hechizos", "justicia"],
             "notas": "Hierba de Júpiter; invierte maleficios hacia su emisor y favorece el sueño sin pesadillas.",
             "estudio": "Agrimonia eupatoria fue descrita por Dioscórides (IV.41) como planta hepática y para picaduras de serpiente. Culpeper la asigna a Júpiter bajo Cáncer, destacando su virtud de proteger en el sueño. En la tradición anglosajona (*Lacnunga*, manuscrito del s. X) es una de las 'nueve hierbas sagradas'. En magia: colocar agrimonia bajo la almohada produce sueño profundo sin pesadillas; puesta en un espacio deshace hechizos y los devuelve a su origen. La Golden Dawn la usa en trabajo de protección por inversión (regresión de maleficios).",
             "parte": "hojas y flores",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica IV.41; Culpeper, Complete Herbal; Lacnunga (ms. anglosajón, s. X)",
         }),

    dict(slug="celidonia", item_type="herb", name="Celidonia", planet="sun", element="fuego",
         aliases=["Celandine", "Chelidonium majus", "Hierba de la golondrina"],
         properties={
             "intenciones": ["éxito legal", "libertad", "alegría", "curación ocular"],
             "notas": "Hierba solar de la golondrina; su látex amarillo señala su virtud biliar y su poder de 'ver claro'.",
             "estudio": "Chelidonium majus es ejemplo perfecto de la doctrina de las signaturas: su látex amarillo-naranja señala (según la firma) virtudes hepáticas y oculares. Culpeper la asigna al Sol bajo Leo. Dioscórides (II.180) la usa para curar ojos y eliminar verrugas con el látex. En la tradición mágica se lleva en bolsa para ganar casos legales y liberarse de injusticias — resonancia con el Sol como planeta de autoridad y justicia. PRECAUCIÓN: el látex en ojos puede causar daño corneal severo; el alcaloide chelidonina es tóxico internamente.",
             "parte": "látex (uso externo) y sumidades",
             "toxicidad": "tóxica — alcaloides hepatotóxicos; látex irritante; no ingerir extractos concentrados",
             "fuente": "Dioscórides, De Materia Medica II.180; Culpeper, Complete Herbal",
         }),

    dict(slug="digital", item_type="herb", name="Digital", planet="saturn", element="agua",
         aliases=["Foxglove", "Digitalis purpurea", "Dedalera"],
         properties={
             "intenciones": ["trabajo ctónico", "comunicación con los muertos", "umbral"],
             "notas": "Planta de Saturno y el umbral; sus flores tubulares albergan (según el folklore) a las hadas y a los muertos.",
             "estudio": "Digitalis purpurea contiene glucósidos cardíacos (digitoxina, digoxina) — uno de los mayores descubrimientos de la medicina moderna, documentado por William Withering (1785) tras investigar recetas herbales. Culpeper la asigna a Venus (por la forma y color de las flores), aunque la tradición mágica la trata como saturnina por su asociación con el umbral y la muerte. En el folklore celta, las manchas en las flores son 'las huellas de los dedos de las hadas' (fox's glove = guante de zorro/hada). En magia se usa únicamente en contextos ctónicos y de umbral, nunca internamente.",
             "parte": "hojas (solo uso ritual externo)",
             "toxicidad": "VENENOSA — glucósidos cardíacos; dosis bajas causan arritmia fatal; no ingerir bajo ningún concepto",
             "fuente": "Culpeper, Complete Herbal; William Withering, Account of the Foxglove (1785)",
         }),

    dict(slug="beleño", item_type="herb", name="Beleño Negro", planet="saturn", element="agua",
         aliases=["Henbane", "Hyoscyamus niger", "Hierba loca"],
         properties={
             "intenciones": ["adivinación ctónica", "sueño profético", "trabajo con los muertos"],
             "notas": "Hierba saturnina de Hécate; en la Antigüedad se quemaba en oráculos de los muertos. VENENOSA.",
             "estudio": "Hyoscyamus niger contiene hiosciamina, escopolamina y atropina. Dioscórides (IV.69) advierte que 'perturba la mente y produce locura'. Culpeper lo asigna a Saturno, el planeta de los límites, la muerte y los cementerios — exactamente el hábitat preferido del beleño. Las sacerdotisas de Hécate lo quemaban en necromancias. Homero menciona el Lethe (río del olvido) en relación a plantas similares; Plinio lo cita como 'furioso y enemigo de la razón'. En el contexto mágico occidental, el beleño ha servido en ungüentos de vuelo chamánicos junto a la belladona y la mandrágora.",
             "parte": "semillas y hojas (uso ritual externo únicamente)",
             "toxicidad": "VENENOSA — todos los alcaloides del tropano; fatal en dosis bajas en niños; no ingerir",
             "fuente": "Dioscórides, De Materia Medica IV.69; Culpeper, Complete Herbal; Plinio, Historia Natural XXV",
         }),

    dict(slug="acacia", item_type="herb", name="Acacia", planet="sun", element="aire",
         aliases=["Acacia", "Acacia senegal", "Goma arábiga"],
         properties={
             "intenciones": ["iniciación", "inmortalidad", "protección del alma", "purificación"],
             "notas": "Árbol solar masónico y egipcio; símbolo de la inmortalidad del alma y la resurrección.",
             "estudio": "La acacia es el árbol sagrado de Osiris en el Antiguo Egipto y un símbolo central de la masonería especulativa, donde representa la inmortalidad del alma (la rama de acacia que marca la tumba de Hiram Abiff). Culpeper describe especies de acacia como astringentes y vulnerarias. Dioscórides (I.133) menciona la goma arábiga (Acacia senegal) para cataplasmas y como protectora de mucosas. En magia egipcia (Libro de los Muertos) la madera de acacia construye los ataúdes de los iniciados. El humo de resina de acacia purifica y consagra.",
             "parte": "resina y flores",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica I.133; Albert Mackey, Encyclopedia of Freemasonry; Libro de los Muertos (Papiro de Ani)",
         }),

    dict(slug="enebro", item_type="herb", name="Enebro", planet="sun", element="fuego",
         aliases=["Juniper", "Juniperus communis", "Sabina"],
         properties={
             "intenciones": ["protección", "purificación", "salud", "destierro"],
             "notas": "Arbusto solar; su humo purifica espacios y ahuyenta enfermedades y malos espíritus.",
             "estudio": "Juniperus communis fue descrito por Dioscórides (I.103) para picaduras de serpiente, riñones y como diurético. Culpeper lo asigna al Sol. En el Tíbet y en tradiciones nativas americanas, el enebro es la hierba de purificación primaria. En Europa medieval se quemaba durante epidemias — el humo tiene propiedades antisépticas reales (terpenos). Los beduinos quemaban enebro en tiendas para purificar el ambiente. En magia se usa en sahumerios de destierro y protección, especialmente de enfermedades.",
             "parte": "bayas y madera",
             "toxicidad": "leve — el aceite esencial es nefrotóxico en dosis altas; evitar en embarazo",
             "fuente": "Dioscórides, De Materia Medica I.103; Culpeper, Complete Herbal",
         }),

    dict(slug="angélica", item_type="herb", name="Angélica", planet="sun", element="fuego",
         aliases=["Angelica", "Angelica archangelica", "Hierba del Espíritu Santo"],
         properties={
             "intenciones": ["protección", "salud", "exorcismo", "consagración"],
             "notas": "Hierba solar del arcángel Miguel; protege contra enfermedades, hechizos y malos espíritus.",
             "estudio": "Angelica archangelica recibe su nombre de la leyenda en que un ángel (algunos dicen el arcángel Miguel) reveló esta planta como cura de la peste. Culpeper la asigna al Sol. Florece en el día de San Miguel (29 de septiembre en el antiguo calendario). En el folklore escandinavo, los lapones la mastican para dar fuerza. En magia se lleva como amuleto de protección, se usa en baños de limpieza y se quema para consagrar espacios sagrados. Sus raíces contienen furanocumarinas fotosensibilizantes.",
             "parte": "raíz y semillas",
             "toxicidad": "leve — fotodermatitis por furanocumarinas; no confundir con cicuta (parecida y mortal)",
             "fuente": "Culpeper, Complete Herbal; folklore escandinavo (documentado por Linnaeus)",
         }),

    dict(slug="calamo-aromatico", item_type="herb", name="Cálamo Aromático", planet="moon", element="agua",
         aliases=["Sweet Flag", "Acorus calamus", "Cálamo"],
         properties={
             "intenciones": ["prosperidad", "curación", "amor", "protección del hogar"],
             "notas": "Hierba lunar de los pantanos; en magia se coloca en las esquinas del hogar para protección y atracción.",
             "estudio": "Acorus calamus fue descrito por Dioscórides (I.2) como diurético, digestivo y para la tos. Culpeper lo asigna a la Luna por su preferencia por ambientes acuáticos y pantanosos. En el Antiguo Testamento (Éxodo 30:23) es uno de los ingredientes del aceite sagrado de unción. Walt Whitman escribió su ciclo poético más íntimo ('Calamus', *Leaves of Grass*) bajo este símbolo. En la magia popular americana (hoodoo) las raíces de calamus se usan para controlar situaciones y proteger el hogar.",
             "parte": "raíz (rizoma)",
             "toxicidad": "leve — el asarón (variedad asiática) es carcinógeno; la variedad norteamericana/europea tiene niveles bajos",
             "fuente": "Dioscórides, De Materia Medica I.2; Culpeper, Complete Herbal; Éxodo 30:23",
         }),

    dict(slug="trébol-rojo", item_type="herb", name="Trébol Rojo", planet="mercury", element="aire",
         aliases=["Red Clover", "Trifolium pratense"],
         properties={
             "intenciones": ["suerte", "amor", "éxito financiero", "protección"],
             "notas": "Hierba mercurial; el trébol de cuatro hojas (mutación) es el amuleto de suerte más universal de Europa.",
             "estudio": "Trifolium pratense es asignado por Culpeper a Mercurio. La forma trilobulada se asoció en el Medievo a la Trinidad cristiana. El trébol de cuatro hojas (mutación espontánea, ratio ~1:5.000) es el talismán de buena fortuna más documentado en el folklore europeo desde el siglo I (Plinio). En la tradición irlandesa, San Patricio usó el trébol para explicar la Trinidad. En magia: llevar trébol en la billetera atrae dinero; el de cuatro hojas específicamente neutraliza maleficios.",
             "parte": "flores y hojas",
             "toxicidad": "no",
             "fuente": "Culpeper, Complete Herbal; Plinio, Historia Natural XXVII",
         }),

    dict(slug="muérdago", item_type="herb", name="Muérdago", planet="sun", element="aire",
         aliases=["Mistletoe", "Viscum album", "Visgo"],
         properties={
             "intenciones": ["protección", "fertilidad", "amor", "inmortalidad"],
             "notas": "Planta sagrada de los druidas; Plinio describe la ceremonia de recolección en robles con hoz de oro.",
             "estudio": "Viscum album fue la planta más sagrada del druidismo celta. Plinio (Historia Natural XVI.95) describe la ceremonia: un druida con ropas blancas, en el sexto día de luna, corta el muérdago de un roble con hoz de oro y lo recoge sin que toque el suelo. Se creía que curaba todo y era antídoto universal. Culpeper lo asigna al Sol. En la mitología nórdica, la flecha de muérdago mató a Baldr — el único material que no había jurado no dañarlo. La tradición de besarse bajo el muérdago en Navidad deriva de ritos de fertilidad celtas.",
             "parte": "ramas y bayas",
             "toxicidad": "tóxica — las bayas contienen lectinas (viscotoxinas); no ingerir; tóxico para animales domésticos",
             "fuente": "Plinio, Historia Natural XVI.95; Culpeper, Complete Herbal",
         }),

    dict(slug="nuez-moscada", item_type="herb", name="Nuez Moscada", planet="jupiter", element="fuego",
         aliases=["Nutmeg", "Myristica fragrans"],
         properties={
             "intenciones": ["suerte", "prosperidad", "fidelidad", "clarividencia"],
             "notas": "Especia jovial de Júpiter; llevar una nuez entera en el bolso atrae suerte y dinero.",
             "estudio": "Myristica fragrans fue una de las especias más codiciadas de la Edad Media, que motivó expediciones y guerras coloniales. Culpeper la asigna a Júpiter. Dioscórides menciona nueces aromáticas similares en el Libro I. En dosis normales es inocua como especia; en dosis altas (15-20 g) produce alucinaciones por la miristicina, un alucinógeno análogo al MDMA. En la tradición mágica americana (hoodoo) la nuez entera se lleva como amuleto de suerte; rallada se usa en mezclas de prosperidad.",
             "parte": "semilla (nuez)",
             "toxicidad": "leve — alucinógena y tóxica en dosis muy altas (>15g); a dosis normales de cocina, inocua",
             "fuente": "Culpeper, Complete Herbal; Dioscórides, De Materia Medica I",
         }),

    dict(slug="albahaca", item_type="herb", name="Albahaca", planet="mars", element="fuego",
         aliases=["Basil", "Ocimum basilicum", "Hierba real"],
         properties={
             "intenciones": ["amor", "prosperidad", "protección", "exorcismo"],
             "notas": "Hierba marcial de India y el Mediterráneo; Culpeper la asigna a Marte por su energía expansiva.",
             "estudio": "Ocimum basilicum tiene doble tradición: en Europa/Mediterráneo fue planta de luto y muerte (griegos y romanos la asociaban al escorpión y al odio); en India es la Tulsi sagrada de Vishnu, protectora del hogar. Culpeper la asigna a Marte bajo Escorpio, señalando esta dualidad. Dioscórides (II.141) la menciona sin recomendar su uso interno. En la magia italiana moderna (malocchio), la albahaca es la hierba antimalocchio por excelencia: plantas vivas en el umbral protegen el hogar. En América Latina, lavar el dinero con agua de albahaca atrae prosperidad.",
             "parte": "hojas",
             "toxicidad": "no",
             "fuente": "Dioscórides, De Materia Medica II.141; Culpeper, Complete Herbal",
         }),

    dict(slug="acónito", item_type="herb", name="Acónito", planet="saturn", element="agua",
         aliases=["Aconite", "Wolfsbane", "Monkshood", "Aconitum napellus", "Matalobos"],
         properties={
             "intenciones": ["protección extrema", "invisibilidad", "trabajo ctónico", "iniciación"],
             "notas": "La planta más venenosa de Europa; en tradición mágica, protección absoluta y umbral de la muerte.",
             "estudio": "Aconitum napellus contiene aconitina, uno de los venenos vegetales más potentes conocidos. Dioscórides (IV.76) advierte que mata animales y humanos con rapidez. Culpeper lo asigna a Saturno. En la mitología griega brotó de la baba de Cerbero cuando Heracles lo arrastró al mundo superior. Los ungüentos de vuelo medievales lo incluían. Plinio describe su uso en ejecuciones. En la tradición mágica ceremonial se usa únicamente como símbolo o en rituales de iniciación que trabajan con la muerte simbólica — NUNCA en contacto físico: la aconitina se absorbe a través de la piel.",
             "parte": "ninguna (solo representación simbólica)",
             "toxicidad": "VENENOSA EXTREMA — la aconitina se absorbe transdérmicamente; dosis letal muy baja; manipular solo con guantes; no ingerir bajo ninguna circunstancia",
             "fuente": "Dioscórides, De Materia Medica IV.76; Culpeper, Complete Herbal; Plinio, Historia Natural XXVII",
         }),
]
