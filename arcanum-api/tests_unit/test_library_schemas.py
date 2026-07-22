"""Tests de los contratos de Lecturas.

Verifican las invariantes que el cliente da por hechas y que, si se rompieran,
fallarían en silencio: el original siempre viaja, las anclas son estables, y el
aviso histórico acompaña al texto.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from app.schemas.library import (  # noqa: E402
    ChapterDetail,
    ChapterSummary,
    ParagraphResponse,
    WorkDetail,
    WorkSummary,
)
from ingest_library import parse_culpeper  # noqa: E402


class TestParagraphResponse:
    def test_el_original_es_obligatorio(self):
        """Sin original no se puede verificar la traducción ni citar el pasaje."""
        with pytest.raises(Exception):
            ParagraphResponse(anchor="a.b.0", position=0)

    def test_la_traduccion_es_opcional(self):
        # Una obra a medio traducir debe poder servirse igual.
        p = ParagraphResponse(anchor="a.b.0", position=0, text_original="It is an herb")
        assert p.text_es is None
        assert p.translation_status is None

    def test_conserva_ambos_idiomas(self):
        p = ParagraphResponse(
            anchor="culpeper-complete-herbal.all-heal.3",
            position=3,
            text_original="It is under the dominion of Mars",
            text_es="Está bajo el dominio de Marte",
            translation_status="machine",
        )
        assert p.text_original and p.text_es
        assert p.translation_status == "machine"


class TestChapterDetail:
    def _chapter(self, **kwargs):
        base = dict(
            id="0f6f7a2e-1f4a-4c1a-9b0e-2f2c9a1d4e55",
            slug="all-heal",
            title="All-Heal",
            kind="herb",
            position=2,
            meta={"ruling_planet": "mars"},
            work_slug="culpeper-complete-herbal",
            work_title="The Complete Herbal",
            paragraphs=[],
        )
        base.update(kwargs)
        return ChapterDetail(**base)

    def test_el_aviso_viaja_con_el_capitulo(self):
        """Debe estar donde se lee el texto, no solo en la portada de la obra."""
        chapter = self._chapter(advisory="Documento histórico de 1653.")
        assert "1653" in chapter.advisory

    def test_conserva_el_planeta_regente(self):
        # Es el puente con Materia Arcana.
        assert self._chapter().meta["ruling_planet"] == "mars"

    def test_sabe_a_que_obra_pertenece(self):
        chapter = self._chapter()
        assert chapter.work_slug == "culpeper-complete-herbal"


class TestWorkSummary:
    def test_reporta_el_avance_de_traduccion(self):
        """El cliente puede avisar de que una obra está a medias en vez de
        mostrar huecos sin explicación."""
        w = WorkSummary(
            slug="culpeper-complete-herbal",
            title="The Complete Herbal",
            author="Nicholas Culpeper",
            year=1653,
            language="en",
            chapter_count=423,
            translated_chapters=10,
        )
        assert w.translated_chapters < w.chapter_count


class TestWorkDetail:
    def test_la_licencia_es_obligatoria(self):
        """Se guarda con el contenido: si hay que justificar la distribución,
        está ahí y no en un documento aparte."""
        with pytest.raises(Exception):
            WorkDetail(
                slug="x", title="T", author="A", language="en", chapters=[]
            )

    def test_el_indice_no_lleva_texto(self):
        # Culpeper son 423 capítulos: mandar el libro entero por una lista que
        # el usuario solo va a ojear serían ~1,7 MB.
        assert "paragraphs" not in ChapterSummary.model_fields
        assert "text_original" not in ChapterSummary.model_fields


class TestAnclasEstables:
    """Un resaltado guardado hace meses debe seguir resolviendo al mismo texto."""

    @pytest.fixture(scope="class")
    def obra(self):
        source = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "library_data"
            / "culpeper-complete-herbal.json"
        )
        if not source.exists():
            pytest.skip("Falta el JSON ingerido: ejecuta ingest_library.py")
        return json.loads(source.read_text(encoding="utf-8"))

    def test_todas_las_anclas_son_unicas(self, obra):
        anchors = [p["anchor"] for c in obra["chapters"] for p in c["paragraphs"]]
        duplicadas = {a for a in anchors if anchors.count(a) > 1} if len(anchors) < 200 else None
        assert len(anchors) == len(set(anchors)), f"anclas repetidas: {duplicadas}"

    def test_el_ancla_codifica_obra_capitulo_y_posicion(self, obra):
        for chapter in obra["chapters"][:20]:
            for index, paragraph in enumerate(chapter["paragraphs"]):
                assert paragraph["anchor"] == f"{obra['slug']}.{chapter['slug']}.{index}"

    def test_la_reingesta_produce_las_mismas_anclas(self, obra):
        """Determinismo: reingerir no puede mover un ancla a otro párrafo."""
        raw_path = Path(__file__).resolve().parents[1] / "scripts" / "library_data"
        cached = raw_path / "culpeper-complete-herbal.source.txt"
        if not cached.exists():
            pytest.skip("Sin copia local de la fuente para reingerir")
        again = parse_culpeper(cached.read_text(encoding="utf-8"))
        before = [p["anchor"] for c in obra["chapters"] for p in c["paragraphs"]]
        after = [p.anchor for c in again.chapters for p in c.paragraphs]
        assert before == after
