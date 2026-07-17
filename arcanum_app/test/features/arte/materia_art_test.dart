import 'package:arcanum_app/features/arte/engraving_manifest_loader.dart';
import 'package:arcanum_app/features/arte/materia_engravings.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('identidad visual de Materia Arcana', () {
    test('normaliza slugs acentuados como los assets ASCII', () {
      expect(normalizeMateriaSlug(' Beleño '), 'beleno');
      expect(normalizeMateriaSlug('Acónito'), 'aconito');
      expect(normalizeMateriaSlug('Trébol-Rojo'), 'trebol-rojo');
    });

    test('las seis hierbas originales reciben siluetas propias', () {
      final variants = {
        for (final slug in const [
          'romero',
          'lavanda',
          'rosa',
          'canela',
          'artemisa',
          'salvia',
        ])
          materiaVariant(slug, 'herb'),
      };
      expect(variants, hasLength(6));
    });

    test('los siete metales planetarios reciben formas propias', () {
      final variants = {
        for (final slug in const [
          'oro',
          'plata',
          'hierro',
          'estaño',
          'plomo',
          'mercurio-metal',
          'cobre',
        ])
          materiaVariant(slug, 'metal'),
      };
      // Oro y plata comparten deliberadamente el arquetipo de moneda; los
      // otros cinco usan estados físicos distintos.
      expect(variants, hasLength(6));
      expect(materiaVariant('mercurio-metal', 'metal'), 3);
      expect(materiaVariant('hierro', 'metal'), 5);
    });

    test('las piedras tienen 23 firmas visuales individuales', () {
      const slugs = [
        'turmalina-negra',
        'labradorita',
        'lapislazuli',
        'hematita',
        'citrino',
        'malaquita',
        'agata-musgo',
        'onix-negro',
        'jade',
        'rodocrosita',
        'sodalita',
        'ojo-de-tigre',
        'piedra-luna',
        'granate',
        'esmeralda',
        'zafiro',
        'rubi',
        'perla',
        'cuarzo-ahumado',
        'cuarzo-claro',
        'amatista',
        'obsidiana',
        'cornalina',
      ];

      final variants = {
        for (final slug in slugs) materiaVariant(slug, 'stone'),
      };
      expect(variants, hasLength(slugs.length));
      for (final variant in variants) {
        expect(
          buildEngraving('stone', variant, 100).computeMetrics(),
          isNotEmpty,
        );
      }
    });

    test('inciensos, aceites y resinas no comparten identidad', () {
      const groups = <String, List<String>>{
        'incense': [
          'copal',
          'benjui',
          'sangre-de-drago',
          'sandalo-blanco',
          'estoraque',
          'galbano',
          'opoponax',
          'nardo',
          'cipres-resina',
          'canfora',
          'olibano',
          'mirra',
        ],
        'oil': [
          'aceite-oliva-sagrado',
          'aceite-solar',
          'aceite-lunar',
          'aceite-mercurial',
          'aceite-venusino',
          'aceite-marcial',
          'aceite-jovial',
          'aceite-saturnino',
        ],
        'resin': [
          'resina-pino',
          'trementina',
          'resina-elemi',
          'resina-labdano',
          'resina-mastix',
        ],
      };

      for (final MapEntry(key: type, value: slugs) in groups.entries) {
        final variants = {for (final slug in slugs) materiaVariant(slug, type)};
        expect(variants, hasLength(slugs.length), reason: type);
        for (final variant in variants) {
          expect(
            buildEngraving(type, variant, 100).computeMetrics(),
            isNotEmpty,
            reason: '$type/$variant',
          );
        }
      }
    });

    test('planetas y ángeles conservan siete sellos individuales', () {
      const planets = [
        'sol',
        'luna',
        'marte',
        'mercurio',
        'jupiter',
        'venus',
        'saturno',
      ];
      const angels = [
        'miguel',
        'gabriel',
        'samael',
        'rafael',
        'sachiel',
        'anael',
        'cassiel',
      ];

      expect({
        for (final name in planets) materiaVariant('planeta-$name', 'planet'),
      }, hasLength(7));
      expect({
        for (final name in angels) materiaVariant('arcangel-$name', 'angel'),
      }, hasLength(7));
    });

    test('los doce signos ocupan posiciones individuales en la rueda', () {
      const signs = [
        'aries',
        'tauro',
        'géminis',
        'cáncer',
        'leo',
        'virgo',
        'libra',
        'escorpio',
        'sagitario',
        'capricornio',
        'acuario',
        'piscis',
      ];

      expect({
        for (final sign in signs) materiaVariant('signo-$sign', 'sign'),
      }, hasLength(12));
    });

    test('el manifiesto resuelve slugs acentuados del backend', () async {
      final manifest = EngravingManifest.instance;
      await manifest.ensureLoaded();
      expect(
        manifest.resolve('beleño')?.assetPath,
        'assets/engravings/hierbas/beleno.svg',
      );
      expect(manifest.resolve('acónito')?.isFinal, isTrue);
    });

    test('all material categories resolve through historical plates', () async {
      const slugs = [
        'oro', 'plata', 'hierro', 'estano', 'plomo', 'mercurio-metal', 'cobre',
        'turmalina-negra', 'labradorita', 'lapislazuli', 'hematita', 'citrino',
        'malaquita', 'agata-musgo', 'onix-negro', 'jade', 'rodocrosita',
        'sodalita', 'ojo-de-tigre', 'piedra-luna', 'granate', 'esmeralda',
        'zafiro', 'rubi', 'perla', 'cuarzo-ahumado', 'cuarzo-claro',
        'amatista', 'obsidiana', 'cornalina',
        'copal', 'benjui', 'sangre-de-drago', 'sandalo-blanco', 'estoraque',
        'galbano', 'opoponax', 'nardo', 'cipres-resina', 'canfora', 'olibano',
        'mirra', 'aceite-oliva-sagrado', 'aceite-solar', 'aceite-lunar',
        'aceite-mercurial', 'aceite-venusino', 'aceite-marcial',
        'aceite-jovial', 'aceite-saturnino', 'resina-pino', 'trementina',
        'resina-elemi', 'resina-labdano', 'resina-mastix',
      ];
      final manifest = EngravingManifest.instance;
      await manifest.ensureLoaded();
      for (final slug in slugs) {
        expect(manifest.resolve(slug)?.isFinal, isTrue, reason: slug);
      }
    });

    test('all 82 historical plates decode as SVG', () async {
      final manifest = EngravingManifest.instance;
      await manifest.ensureLoaded();
      final plates = manifest.all.where((entry) => entry.isFinal).toList();
      expect(plates, hasLength(82));
      expect(
        plates.map((entry) => entry.assetPath).toSet(),
        hasLength(plates.length),
        reason: 'cada materia debe conservar una identidad visual propia',
      );

      for (final plate in plates) {
        final picture = await vg.loadPicture(
          SvgAssetLoader(plate.assetPath!),
          null,
        );
        picture.picture.dispose();
      }
    });
  });
}
