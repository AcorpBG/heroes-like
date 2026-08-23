#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[1]
HEROES_PATH = ROOT / "content" / "heroes.json"
MANIFEST_PATH = ROOT / "content" / "hero_art_manifest.json"
ART_ROOT = ROOT / "art" / "heroes" / "portraits"
PORTRAIT_SIZE = (384, 512)
CURATED_SOURCE_ROOT = ROOT / "art" / "heroes" / "source" / "curated"
CURATED_PORTRAIT_SOURCE_IDS = {
    "hero_brasshollow_daxis_chaincaptain",
    "hero_brasshollow_kuld_varn",
    "hero_brasshollow_lina_gaugesavant",
    "hero_brasshollow_marka_ironclause",
    "hero_brasshollow_odrik_heatpriest",
    "hero_brasshollow_oren_bellfounder",
    "hero_brasshollow_selka_pitmarshal",
    "hero_brasshollow_vellum_quench",
    "hero_caelen",
    "hero_embercourt_belis_rainledger",
    "hero_embercourt_helva_tollbrand",
    "hero_embercourt_jorun_beaconscribe",
    "hero_embercourt_orra_cinderquill",
    "hero_embercourt_saren_lockmaster",
    "hero_lyra",
    "hero_mira",
    "hero_mireclaw_brakka_mudkeel",
    "hero_mireclaw_edda_rotlamp",
    "hero_mireclaw_kessa_chainboom",
    "hero_mireclaw_nix_votivejaw",
    "hero_neral",
    "hero_orrik",
    "hero_sable",
    "hero_seren",
    "hero_solera",
    "hero_sunvault_dovan_lenscaptain",
    "hero_sunvault_essa_daynote",
    "hero_sunvault_ilyr_glassmarshal",
    "hero_sunvault_renn_facetlane",
    "hero_tarn",
    "hero_thalen",
    "hero_thornwake_ardren_briarmarshal",
    "hero_thornwake_elian_loamchant",
    "hero_thornwake_halen_thorncart",
    "hero_thornwake_merek_greenbarrow",
    "hero_thornwake_osmund_pollenglass",
    "hero_thornwake_ralka_mossvein",
    "hero_thornwake_silsa_bramblehound",
    "hero_thornwake_tova_rootwright",
    "hero_thornwake_veyra_seedseer",
    "hero_torren",
    "hero_varis",
    "hero_vaska",
    "hero_veilmourn_cela_mistcorsair",
    "hero_veilmourn_damar_oriflag",
    "hero_veilmourn_ivara_blacktide",
    "hero_veilmourn_jessa_keelwarden",
    "hero_veilmourn_morwen_wakeoracle",
    "hero_veilmourn_ruln_vanehook",
    "hero_veilmourn_sael_mirrorbell",
    "hero_veilmourn_thir_obituaryink",
}

PALETTES = {
    "faction_embercourt": ((184, 66, 36), (237, 157, 63), (50, 25, 22), (237, 202, 132)),
    "faction_mireclaw": ((62, 111, 61), (139, 99, 53), (19, 40, 33), (164, 197, 140)),
    "faction_sunvault": ((202, 169, 59), (91, 130, 210), (38, 40, 70), (242, 232, 161)),
    "faction_thornwake": ((66, 118, 62), (139, 86, 51), (21, 46, 27), (174, 207, 128)),
    "faction_brasshollow": ((176, 119, 46), (98, 105, 110), (41, 32, 28), (224, 179, 87)),
    "faction_veilmourn": ((66, 93, 127), (69, 139, 151), (21, 27, 43), (169, 199, 207)),
}

SKIN_TONES = [
    (244, 203, 169), (222, 171, 133), (195, 137, 101),
    (151, 96, 75), (108, 68, 58), (203, 157, 119),
]


def stable_int(value: str) -> int:
    return int(hashlib.sha256(value.encode("utf-8")).hexdigest()[:16], 16)


def shade(color: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, round(channel * factor))) for channel in color)


def blend(a: tuple[int, int, int], b: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(round(a[index] * (1.0 - amount) + b[index] * amount) for index in range(3))


def polygon_star(cx: int, cy: int, outer: int, inner: int, points: int = 8) -> list[tuple[float, float]]:
    rows = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        angle = -math.pi / 2.0 + math.pi * index / points
        rows.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return rows


def draw_background(draw: ImageDraw.ImageDraw, palette: tuple, seed: int) -> None:
    primary, secondary, shadow, metal = palette
    for y in range(PORTRAIT_SIZE[1]):
        t = y / (PORTRAIT_SIZE[1] - 1)
        color = blend(shade(primary, 0.72), shadow, t * 0.82)
        draw.line((0, y, PORTRAIT_SIZE[0], y), fill=(*color, 255))
    horizon = 96 + seed % 72
    draw.ellipse((-120, horizon - 110, 505, horizon + 300), outline=(*blend(secondary, metal, 0.35), 100), width=7)
    for index in range(7):
        angle = (seed >> (index * 6)) % 360
        radius = 105 + ((seed >> (index * 4)) % 120)
        cx = 192 + round(math.cos(math.radians(angle)) * radius)
        cy = 210 + round(math.sin(math.radians(angle)) * radius * 0.68)
        r = 4 + ((seed >> (index * 3)) % 12)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*secondary, 35))


def draw_faction_crown(draw: ImageDraw.ImageDraw, faction: str, palette: tuple, seed: int) -> None:
    primary, secondary, shadow, metal = palette
    if faction == "faction_sunvault":
        draw.polygon(polygon_star(192, 116, 82, 46, 9), fill=(*metal, 160), outline=(*shadow, 255))
    elif faction == "faction_thornwake":
        for side in (-1, 1):
            points = [(192 + side * 35, 139), (192 + side * 90, 80), (192 + side * 55, 151)]
            draw.line(points, fill=(*metal, 230), width=11, joint="curve")
    elif faction == "faction_brasshollow":
        for index in range(7):
            angle = index * math.tau / 7.0
            cx = 192 + math.cos(angle) * 62
            cy = 130 + math.sin(angle) * 43
            draw.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), outline=(*metal, 230), width=7)
    elif faction == "faction_veilmourn":
        draw.arc((100, 54, 284, 216), 195, 345, fill=(*metal, 220), width=16)
        draw.arc((120, 72, 264, 204), 200, 340, fill=(*secondary, 210), width=9)
    elif faction == "faction_mireclaw":
        draw.arc((100, 66, 284, 220), 200, 340, fill=(*secondary, 230), width=17)
        draw.line((117, 132, 76, 86), fill=(*metal, 210), width=10)
        draw.line((267, 132, 308, 86), fill=(*metal, 210), width=10)
    else:
        for side in (-1, 1):
            draw.polygon([(192 + side * 25, 143), (192 + side * 57, 63), (192 + side * 76, 150)], fill=(*metal, 210))


def draw_hero(hero: dict, path: Path) -> None:
    hero_id = str(hero["id"])
    faction = str(hero.get("faction_id", ""))
    palette = PALETTES[faction]
    primary, secondary, shadow, metal = palette
    seed = stable_int(hero_id)
    skin = SKIN_TONES[seed % len(SKIN_TONES)]
    image = Image.new("RGBA", PORTRAIT_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    draw_background(draw, palette, seed)
    draw_faction_crown(draw, faction, palette, seed)

    # Broad shoulder silhouette gives every portrait the same readable card scale.
    shoulder_y = 352 + seed % 18
    draw.ellipse((-42, shoulder_y, 426, 650), fill=(*shadow, 255), outline=(*metal, 205), width=8)
    draw.polygon([(25, 512), (82, 342), (192, 318), (302, 342), (359, 512)], fill=(*primary, 255))
    draw.line([(25, 512), (82, 342), (192, 318), (302, 342), (359, 512)], fill=(*metal, 215), width=7, joint="curve")
    for offset in (-1, 1):
        x = 192 + offset * 92
        draw.ellipse((x - 42, 340, x + 42, 425), fill=(*secondary, 235), outline=(*metal, 220), width=6)

    face_width = 122 + (seed >> 5) % 25
    face_left = 192 - face_width // 2
    face_right = 192 + face_width // 2
    draw.ellipse((face_left, 128, face_right, 329), fill=(*skin, 255), outline=(*shade(skin, 0.58), 255), width=7)
    draw.polygon([(166, 311), (218, 311), (231, 361), (153, 361)], fill=(*shade(skin, 0.82), 255))

    hair = blend(shadow, secondary, ((seed >> 11) % 45) / 100.0)
    hair_style = (seed >> 18) % 4
    if hair_style == 0:
        draw.pieslice((face_left - 10, 102, face_right + 10, 246), 180, 360, fill=(*hair, 255))
        draw.rectangle((face_left - 8, 176, face_left + 20, 307), fill=(*hair, 240))
    elif hair_style == 1:
        draw.polygon([(face_left - 6, 206), (face_left + 12, 126), (192, 103), (face_right - 8, 131), (face_right + 7, 214), (235, 168), (187, 151), (148, 174)], fill=(*hair, 255))
    elif hair_style == 2:
        draw.arc((face_left - 6, 106, face_right + 6, 238), 180, 360, fill=(*hair, 255), width=32)
        for index in range(5):
            x = face_left + 17 + index * (face_width - 34) / 4
            draw.line((x, 134, x + ((index % 2) * 12 - 6), 201), fill=(*hair, 245), width=18)
    else:
        draw.ellipse((face_left - 4, 108, face_right + 4, 204), fill=(*hair, 255))
        draw.rectangle((face_right - 17, 145, face_right + 14, 287), fill=(*hair, 245))

    eye_y = 222 + ((seed >> 23) % 7)
    eye_color = blend(secondary, (235, 245, 238), 0.45)
    for side in (-1, 1):
        cx = 192 + side * 30
        draw.line((cx - 14, eye_y, cx + 14, eye_y - 1), fill=(*shade(skin, 0.45), 255), width=5)
        draw.ellipse((cx - 5, eye_y - 5, cx + 5, eye_y + 5), fill=(*eye_color, 255))
        draw.ellipse((cx - 2, eye_y - 2, cx + 2, eye_y + 2), fill=(*shadow, 255))
    draw.line((192, eye_y + 7, 184, 264, 198, 267), fill=(*shade(skin, 0.66), 220), width=4)
    mouth_y = 291 + ((seed >> 29) % 5)
    draw.arc((166, mouth_y - 8, 218, mouth_y + 16), 12, 168, fill=(*shade(skin, 0.48), 255), width=4)

    # Command path and archetype alter the insignia while preserving faction identity.
    command_path = str(hero.get("command_path", "might"))
    if command_path == "magic":
        draw.polygon(polygon_star(192, 404, 35, 16, 7), fill=(*secondary, 235), outline=(*metal, 255))
        draw.ellipse((180, 392, 204, 416), fill=(*shadow, 255))
    else:
        draw.polygon([(192, 365), (229, 390), (217, 438), (192, 459), (167, 438), (155, 390)], fill=(*secondary, 235), outline=(*metal, 255))
        draw.line((192, 380, 192, 439), fill=(*metal, 255), width=7)
        draw.line((174, 405, 210, 405), fill=(*metal, 255), width=7)

    # Hash-derived small marks make same-faction silhouettes unmistakably distinct.
    for index in range(5):
        x = 52 + ((seed >> (index * 8)) % 280)
        y = 455 + ((seed >> (index * 5 + 3)) % 42)
        draw.line((x, y, x + 18, y - 10), fill=(*metal, 150), width=4)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def draw_curated_hero_portrait(source_path: Path, path: Path) -> None:
    with Image.open(source_path) as source:
        portrait = ImageOps.fit(
            source.convert("RGB"),
            PORTRAIT_SIZE,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    portrait.save(path, format="PNG", optimize=True)


def main() -> int:
    heroes = json.loads(HEROES_PATH.read_text(encoding="utf-8")).get("items", [])
    ART_ROOT.mkdir(parents=True, exist_ok=True)
    items = []
    for hero in heroes:
        hero_id = str(hero["id"])
        path = ART_ROOT / f"{hero_id}.png"
        source_path = CURATED_SOURCE_ROOT / f"{hero_id}.png"
        if hero_id in CURATED_PORTRAIT_SOURCE_IDS:
            if not source_path.is_file():
                raise FileNotFoundError(f"missing curated hero portrait source: {source_path}")
            draw_curated_hero_portrait(source_path, path)
        else:
            draw_hero(hero, path)
        item = {
            "id": hero_id,
            "hero_id": hero_id,
            "name": str(hero.get("name", hero_id)),
            "faction_id": str(hero.get("faction_id", "")),
            "archetype": str(hero.get("archetype", "")),
            "portrait": "res://" + path.relative_to(ROOT).as_posix(),
        }
        if hero_id in CURATED_PORTRAIT_SOURCE_IDS:
            item["source_kind"] = "curated_original_character"
            item["source_path"] = "res://" + source_path.relative_to(ROOT).as_posix()
            item["source_sha256"] = hashlib.sha256(source_path.read_bytes()).hexdigest()
        items.append(item)
    manifest = {
        "schema_version": 1,
        "generator": "deterministic_hero_portrait_assets_v1",
        "source": "content/heroes.json",
        "surface_size": {"width": PORTRAIT_SIZE[0], "height": PORTRAIT_SIZE[1]},
        "items": items,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"generated {len(items)} hero portraits into {ART_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
