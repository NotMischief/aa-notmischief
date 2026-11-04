"""
AA NotMischef - Python vision helper (runs hidden next to the AutoHotkey macro).

Does the heavy screen work fast:
  * place  - reads the game's green / red placement paint and picks a spot (NumPy + OpenCV)
  * ocr    - reads text with RapidOCR (better on the small game numbers than Windows OCR)

Talks to the macro only through small text files in Logs\\vision_ipc (no network, no ports).
Quits by itself when the macro closes.
"""
from __future__ import annotations

import ctypes
import os
import random
import sys
import time
import traceback

IPC = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..", "Logs", "vision_ipc")
PARENT = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
LOG = os.path.join(IPC, "helper.log")
# [Lag fix] debug pictures go in their own folder: the request loop lists IPC ~50 times a second, and
# thousands of old pictures in it cost real CPU/disk time. Only the newest ones are kept.
PIC_DIR = os.path.join(IPC, "pics")
_PIC_N = [0]


def _pic(name: str) -> str:
    os.makedirs(PIC_DIR, exist_ok=True)
    _PIC_N[0] += 1
    if _PIC_N[0] % 25 == 1:
        try:
            old = sorted((e for e in os.scandir(PIC_DIR) if e.name.endswith(".jpg")), key=lambda e: e.stat().st_mtime)
            for e in old[:-300]:
                os.remove(e.path)
        except OSError:
            pass
    return os.path.join(PIC_DIR, name)
os.makedirs(IPC, exist_ok=True)


def log(msg: str) -> None:
    try:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(time.strftime("%H:%M:%S ") + msg + "\n")
    except OSError:
        pass


def parent_alive() -> bool:
    if not PARENT or os.name != "nt":
        return True
    k32 = ctypes.windll.kernel32
    h = k32.OpenProcess(0x00100000, False, PARENT)  # SYNCHRONIZE
    if not h:
        return False
    try:
        return k32.WaitForSingleObject(h, 0) == 0x102  # WAIT_TIMEOUT = still running
    finally:
        k32.CloseHandle(h)


log(f"helper process up (python {sys.version.split()[0]}) - loading libraries")
try:
    import numpy as np  # noqa: E402
    import cv2  # noqa: E402
    import mss  # noqa: E402
except Exception:
    log("could not load libraries:\n" + traceback.format_exc())
    raise

_sct = mss.mss()
_ocr = None


def grab(x: int, y: int, w: int, h: int) -> np.ndarray:
    shot = _sct.grab({"left": x, "top": y, "width": w, "height": h})
    return np.asarray(shot)[:, :, :3]  # BGR


def get_ocr():
    global _ocr
    if _ocr is None:
        try:
            from rapidocr import RapidOCR
        except ImportError:
            from rapidocr_onnxruntime import RapidOCR
        import logging
        for n in ("RapidOCR", "rapidocr"):
            logging.getLogger(n).setLevel(logging.ERROR)
        _ocr = RapidOCR()
    return _ocr


def ocr_text(img: np.ndarray) -> str:
    res = get_ocr()(img)
    if isinstance(res, tuple):  # older rapidocr_onnxruntime API
        items = res[0] or []
        items = sorted(items, key=lambda it: (min(p[1] for p in it[0]), min(p[0] for p in it[0])))
        return " ".join(str(it[1]) for it in items)
    txts = getattr(res, "txts", None) or ()
    boxes = getattr(res, "boxes", None)
    if boxes is not None and len(boxes) == len(txts):
        order = sorted(range(len(txts)), key=lambda i: (float(np.min(np.array(boxes[i])[:, 1])), float(np.min(np.array(boxes[i])[:, 0]))))
        return " ".join(str(txts[i]) for i in order)
    return " ".join(str(t) for t in txts)


def ocr_items(img: np.ndarray):
    """OCR with positions: list of (text, cx, cy) in image pixels."""
    res = get_ocr()(img)
    out = []
    if isinstance(res, tuple):
        for it in (res[0] or []):
            b = np.array(it[0], dtype=float)
            out.append((str(it[1]), float(b[:, 0].mean()), float(b[:, 1].mean())))
        return out
    txts = getattr(res, "txts", None) or ()
    boxes = getattr(res, "boxes", None)
    if boxes is not None and len(boxes) == len(txts):
        for t, b in zip(txts, boxes):
            b = np.array(b, dtype=float)
            out.append((str(t), float(b[:, 0].mean()), float(b[:, 1].mean())))
    return out


def cmd_find(a: dict) -> dict:
    """Find words on screen: returns 'text|x|y' lines (client coordinates) for every piece of text,
    so the macro can click a button by its label even after a UI redesign."""
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    img = grab(x, y, w, h)
    scale = float(a.get("scale", "1"))
    if scale != 1:
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
    items = ocr_items(img)
    lines = [f"{t.replace('|', ' ').replace(';', ' ')}|{int(cx / scale)}|{int(cy / scale)}" for t, cx, cy in items]
    return {"ok": "1", "items": ";;".join(lines)}


def cmd_ocr(a: dict) -> dict:
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    img = grab(x, y, w, h)
    scale = float(a.get("scale", "2"))
    if scale != 1:
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
    return {"ok": "1", "text": ocr_text(img).replace("\n", " ")}


def excluded_mask(h: int, w: int) -> np.ndarray:
    ys, xs = np.mgrid[0:h, 0:w]
    fx, fy = xs / w, ys / h
    # + the new minimap (bottom right) and the taller "Level info" panel (right side) from the UI update
    return ((fy < 0.22) | (fy > 0.84) | (fx < 0.05) | (fx > 0.95) | ((fx > 0.76) & (fy > 0.25) & (fy < 0.60))
            | ((fx > 0.80) & (fy > 0.72)))


_LAST: dict = {"img": None}
_SAVED = {"n": 0}


def _save_paint(name: str) -> None:
    """Keep a few pictures of the placement paint so the colour rules can be checked (max 60)."""
    if _LAST["img"] is None or _SAVED["n"] >= 60:
        return
    _SAVED["n"] += 1
    try:
        cv2.imwrite(_pic(f"paint_{time.strftime('%H%M%S')}_{name}.jpg"), _LAST["img"])
    except Exception:
        pass


_ROOM: dict = {"id": None, "shape": None, "path": None, "path_px": 0, "covs": {}}


def _read_paint(x: int, y: int, w: int, h: int, s: int):
    """Grab the map; if the paint isn't showing yet, look again a few times (fast paint check)."""
    for attempt in range(4):
        full = grab(x, y, w, h)
        _LAST["img"] = full
        img = full.astype(np.int16)[::s, ::s]
        B, G, R = img[:, :, 0], img[:, :, 1], img[:, :, 2]
        red = (R >= 100) & (R - G >= 70) & (R > B)
        green = (G >= 170) & (R < 120) & (B < 140) & ~red
        # the path paint itself is a bright, pure red (about 240, 10, 0); red roofs / bricks are duller
        # on yellow / sandy maps the paint blends to orange (about 250, 110, 10) - still bright and red-shifted
        strict = (R >= 225) & (R - G >= 110) & (B <= 90)
        excl = excluded_mask(*red.shape)
        if (red & ~excl).sum() > 0.02 * red.size or attempt == 3:
            return red, green, excl, attempt, strict
        time.sleep(0.07)


def _strip_ring(red: np.ndarray, mx: float, my: float):
    """The unit we're holding draws its range ring around the mouse. That ring is not path and not
    blocked ground - remove it. Its radius is the unit's real reach, so return that too."""
    ys, xs = np.nonzero(red)
    if len(xs) < 50:
        return red, None
    d = np.hypot(xs - mx, ys - my)
    hist = np.bincount(np.round(d).astype(int))
    if len(hist) < 30:
        return red, None
    sm = np.convolve(hist, np.ones(5), "same")
    sm[:20] = 0                                    # ignore anything right under the mouse
    r0 = int(np.argmax(sm))
    peak = sm[r0]
    base = np.median(sm[max(20, r0 - 40):r0 + 40]) + 1
    if peak < 60 or peak < 4 * base:               # no clear ring
        return red, None
    out = red.copy()
    ring = np.abs(d - r0) <= 5
    out[ys[ring], xs[ring]] = False
    return out, r0


def _room_path(room: str, red: np.ndarray, excl: np.ndarray):
    """Path map for this room, learnt from the first read (before our units add their own red circles)."""
    if _ROOM["id"] != room or _ROOM["shape"] != red.shape or _ROOM["path"] is None:
        path = (red & ~excl).astype(np.uint8)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(path, connectivity=8)
        keep = np.zeros_like(path)
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= 250:      # drop small specks
                keep[lab == i] = 1
        _ROOM.update(id=room, shape=red.shape, path=keep, path_px=int(keep.sum()), covs={})
        log(f"room {room}: learnt path ({int(keep.sum())} px)")
        if room != "warmup":
            _save_paint("room")
    return _ROOM["path"]


def _room_cov(room: str, red: np.ndarray, excl: np.ndarray, r: int):
    """How much path each spot reaches with reach r (cached per room and reach)."""
    path = _room_path(room, red, excl)
    r = max(8, int(round(r / 4.0) * 4))            # round so similar units share the work
    if r not in _ROOM["covs"]:
        disk = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1)).astype(np.float32)
        cov = cv2.filter2D(path.astype(np.float32), -1, disk, borderType=cv2.BORDER_CONSTANT)
        _ROOM["covs"][r] = (cov, float(disk.sum()))
    return _ROOM["covs"][r]


MEM_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Settings", "PlacementMemory")
_MEM: dict = {}


def _mem_name(map_name: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in map_name.strip())[:60] or ""


def _mem_get(map_name: str, shape):
    """Places on this map where units could not go (buildings etc.), learnt from failed placements."""
    key = _mem_name(map_name)
    if not key or key in ("no_map_found", "_"):
        return None
    m = _MEM.get(key)
    if m is None or m.shape != shape:
        m = np.zeros(shape, np.uint8)
        path = os.path.join(MEM_DIR, key + ".png")
        if os.path.exists(path):
            img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
            if img is not None:
                m = cv2.resize(img, (shape[1], shape[0]), interpolation=cv2.INTER_NEAREST).astype(np.uint8)
        _MEM[key] = m
    return m


def _mem_save(map_name: str) -> None:
    key = _mem_name(map_name)
    if key in _MEM:
        os.makedirs(MEM_DIR, exist_ok=True)
        cv2.imwrite(os.path.join(MEM_DIR, key + ".png"), _MEM[key])   # value = times it failed there


def cmd_fail(a: dict) -> dict:
    """A unit could not be placed at x,y (and it wasn't money): learn the whole building/object there.
    Grows a region of similar colour from that point on the last picture; small cap so it never eats the map."""
    s = 2
    img = _LAST["img"]
    if img is None:
        return {"ok": "0", "info": "no picture"}
    small = cv2.GaussianBlur(img[::s, ::s].copy(), (5, 5), 0)
    hh, ww = small.shape[:2]
    px, py = int(a["x"]) // s, int(a["y"]) // s
    if not (0 <= px < ww and 0 <= py < hh):
        return {"ok": "0", "info": "outside"}
    ff = np.zeros((hh + 2, ww + 2), np.uint8)
    cv2.floodFill(small, ff, (px, py), (0, 0, 0), (10, 10, 10), (10, 10, 10),
                  4 | cv2.FLOODFILL_MASK_ONLY | cv2.FLOODFILL_FIXED_RANGE | (255 << 8))
    region = ff[1:-1, 1:-1] > 0
    area = int(region.sum())
    if area < 150 or area > 0.06 * hh * ww:     # too small to mean anything, or spilled into the ground
        region = np.zeros((hh, ww), bool)
        cv2.circle(region.view(np.uint8), (px, py), 16, 1, -1)
        kind = "circle"
    else:
        region = cv2.dilate(region.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        kind = "object"
    m = _mem_get(a.get("map", ""), (hh, ww))
    if m is not None:
        # counted per visit: a place only becomes "never try" on this map after failing in 2 rooms,
        # so one unlucky miss (e.g. an unseen money message) can't block a good spot for good
        m[region] = np.minimum(m[region] + 1, 9)
        _mem_save(a.get("map", ""))
    _ROOM_BAD.setdefault(a.get("room", ""), np.zeros((hh, ww), bool))
    if _ROOM_BAD[a.get("room", "")].shape == (hh, ww):
        _ROOM_BAD[a.get("room", "")] |= region
    log(f"failed spot {a['x']},{a['y']} on {a.get('map', '?')}: marked {kind} ({int(region.sum())} px)")
    return {"ok": "1", "info": f"marked {kind} {int(region.sum())} px"}


_ROOM_BAD: dict = {}
_BASE: dict = {"img": None, "key": None, "t": 0.0}


_HOVER = {"n": 0}


def _ring_strength(mask: np.ndarray, cx: float, cy: float, rmin: int = 40, rmax: int = 230):
    """How much of a circle around (cx, cy) the pixels of ``mask`` cover, at the best radius:
    (fraction of 120 directions that hit the mask within +-3 px, radius). A dashed range ring
    covers roughly half of its circle; a path strip crossing it only a few percent."""
    h, w = mask.shape
    ang = np.linspace(0, 2 * np.pi, 120, endpoint=False)
    ca, sa = np.cos(ang), np.sin(ang)
    best, br = 0.0, 0
    m = cv2.dilate(mask.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    for r in range(rmin, rmax + 1, 3):
        xs = np.round(cx + r * ca).astype(int)
        ys = np.round(cy + r * sa).astype(int)
        inside = (xs >= 0) & (xs < w) & (ys >= 0) & (ys < h)
        if inside.sum() < 40:
            continue
        hit = m[ys[inside], xs[inside]]
        f = float(hit.mean())
        if f > best:
            best, br = f, r
    return best, br


def cmd_hover(a: dict) -> dict:
    """The unit is held over the spot (mouse at cx, cy). Its range ring is drawn blue on a usable spot
    and red on one you can't use. Returns how ring-like the red and the blue pixels are around the
    mouse, and keeps a few pictures (with the result added later by the macro) to tune the rule."""
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    cx, cy = float(a["cx"]), float(a["cy"])
    img = grab(x, y, w, h)
    I = img.astype(np.int16)
    B, G, R = I[:, :, 0], I[:, :, 1], I[:, :, 2]
    red = (R >= 170) & (R - G >= 90) & (R - B >= 70)
    blue = (B >= 180) & (B - R >= 80)
    excl = excluded_mask(h, w)
    red &= ~excl
    blue &= ~excl
    rs, rr = _ring_strength(red, cx, cy)
    bs, br = _ring_strength(blue, cx, cy)
    # the small preview disc right under the unit (6-28 px around the mouse)
    ang = np.linspace(0, 2 * np.pi, 24, endpoint=False)
    pts = [(int(round(cx + rad * np.cos(t))), int(round(cy + rad * np.sin(t)))) for rad in (8, 14, 20, 26) for t in ang]
    pts = [(px, py) for px, py in pts if 0 <= px < w and 0 <= py < h]
    dr = sum(1 for px, py in pts if red[py, px]) / max(1, len(pts))
    db = sum(1 for px, py in pts if blue[py, px]) / max(1, len(pts))
    if _HOVER["n"] < 80:
        _HOVER["n"] += 1
        try:
            cv2.imwrite(_pic(f"hover_{time.strftime('%H%M%S')}_{int(cx)}_{int(cy)}.jpg"), img)
        except Exception:
            pass
    return {"ok": "1", "red": f"{rs:.2f}", "rr": str(rr), "blue": f"{bs:.2f}", "br": str(br),
            "dred": f"{dr:.2f}", "dblue": f"{db:.2f}"}


def cmd_base(a: dict) -> dict:
    """Picture of the map just BEFORE the unit is picked up. While a unit is held the game tints every
    spot you can't use red (other units' footprints - also other players' - trees, the path). Comparing
    the two pictures finds those tints even where they're too faint for the plain red test."""
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    img = grab(x, y, w, h)
    _BASE.update(img=img, key=(x, y, w, h), t=time.time())
    return {"ok": "1"}


def _tint_mask(x, y, w, h, s):
    """Pixels that turned redder after picking the unit up (None if no fresh 'before' picture)."""
    if _BASE["img"] is None or _BASE["key"] != (x, y, w, h) or time.time() - _BASE["t"] > 4.0:
        return None
    held = _LAST.get("img")
    if held is None or held.shape != _BASE["img"].shape:
        return None
    hb = cv2.GaussianBlur(held, (5, 5), 0)[::s, ::s].astype(np.int16)
    bb = cv2.GaussianBlur(_BASE["img"], (5, 5), 0)[::s, ::s].astype(np.int16)
    shift = (hb[:, :, 2] - hb[:, :, 1]) - (bb[:, :, 2] - bb[:, :, 1])
    tint = (shift > 35).astype(np.uint8)
    tint = cv2.morphologyEx(tint, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))   # drop specks (moving enemies)
    return tint > 0


def cmd_place(a: dict) -> dict:
    t0 = time.perf_counter()
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    utype = a.get("type", "Hybrid")
    s = 2  # half resolution
    red, green, excl, waits, strict = _read_paint(x, y, w, h, s)
    hh, ww = red.shape
    mx = float(a.get("mx", w * 0.03)) / s
    my = float(a.get("my", h * 0.95)) / s
    red, ring = _strip_ring(red, mx, my)
    rng = ring if ring else max(8, int(a.get("range", "140")) // s)
    tint = _tint_mask(x, y, w, h, s)
    if tint is not None and tint.shape == red.shape:
        red = red | tint          # faint red tints are blocked ground too
    ground = ~red & ~green
    allowed = {"Hill": green, "Ground": ground}.get(utype, green | ground) & ~excl
    mem = _mem_get(a.get("map", ""), (hh, ww))            # buildings learnt on earlier visits to this map
    if mem is not None:
        allowed &= mem < 2
    rb = _ROOM_BAD.get(a.get("room", ""))                 # and in this room
    if rb is not None and rb.shape == (hh, ww):
        allowed &= ~rb
    for pair in filter(None, a.get("avoid", "").split(";")):      # spots that already failed
        try:
            ax, ay = (int(v) // s for v in pair.split(":"))
            allowed[max(0, ay - 15):ay + 15, max(0, ax - 15):ax + 15] = False
        except ValueError:
            pass
    margin = 32 / s   # a bit more room from the path edge - spots hugging it often failed
    ok = cv2.distanceTransform(allowed.astype(np.uint8), cv2.DIST_L2, 3) >= margin
    counts = f"ground={int((ground & ~excl).sum())} red={int((red & ~excl).sum())} green={int((green & ~excl).sum())}" + (f" tint={int((tint & ~excl).sum())}" if tint is not None else "")
    reach = f"reach {rng * s}px{' (from its ring)' if ring else ' (default)'}"
    ms = lambda: f"{(time.perf_counter() - t0) * 1000:.0f}"
    if not ok.any():
        return {"ok": "0", "info": "no good spot " + counts, "ms": ms()}
    room = a.get("room", "")
    if a.get("avoid"):
        _save_paint("miss")   # an earlier spot failed - keep the picture to see why
    if room:
        # path = the pure paint red; on dark / tinted maps (night, blizzard) the paint is duller and
        # almost none of it passes, so then use the normal red (the held unit's ring already removed)
        src = strict if int((strict & ~excl).sum()) >= 0.004 * strict.size else red
        cov, disk_area = _room_cov(room, src, excl, rng)
    else:
        cov, disk_area = None, 1.0
    if cov is not None and _ROOM["path_px"] > 0 and float(cov.max()) > 0:
        mincov = float(a.get("mincov", "0.15"))   # lower when a unit has waited long for any spot at all
        score = cov.copy()
        # spread out: spots close to our own units are worth less (they'd cover the same stretch)
        top = float(cov.max())
        for pair in filter(None, a.get("placed", "").split(";")):
            try:
                px, py = (int(v) // s for v in pair.split(":"))
            except ValueError:
                continue
            d = np.hypot(np.arange(ww)[None, :] - px, np.arange(hh)[:, None] - py)
            score -= 0.25 * top * np.clip(1 - d / (min(rng, 70) * 0.8), 0, 1)
        score += np.random.uniform(0, 0.02 * top, score.shape)
        base = score.copy()
        score[~ok] = -np.inf
        iy, ix = np.unravel_index(int(np.argmax(score)), score.shape)
        if cov[iy, ix] < mincov * top:
            # nothing useful left at the normal distance - allow spots a little closer to things
            ok2 = cv2.distanceTransform(allowed.astype(np.uint8), cv2.DIST_L2, 3) >= (18 / s)
            base[~ok2] = -np.inf
            jy, jx = np.unravel_index(int(np.argmax(base)), base.shape)
            if cov[jy, jx] > cov[iy, ix]:
                iy, ix = jy, jx
        if cov[iy, ix] < mincov * top:
            # a unit that can't reach the path is wasted money - let the normal pattern place it instead
            return {"ok": "0", "info": f"no spot near the path left ({counts})", "ms": ms()}
        pct = int(round(100 * cov[iy, ix] / max(1.0, min(disk_area, _ROOM["path_px"]))))
        info = f"{counts} {reach} covers {int(cov[iy, ix])} path px ({pct}%), paint waits {waits}"
    else:
        dist_red = cv2.distanceTransform((~red).astype(np.uint8), cv2.DIST_L2, 3)
        ys, xs = np.mgrid[0:hh, 0:ww]
        score = dist_red + (np.abs(xs - ww / 2) + np.abs(ys - hh / 2)) / 8 + np.random.uniform(0, 3, dist_red.shape)
        score[~ok] = np.inf
        iy, ix = np.unravel_index(int(np.argmin(score)), score.shape)
        info = counts + " (no path map)"
    return {"ok": "1", "x": str(int(ix * s + s // 2)), "y": str(int(iy * s + s // 2)), "info": info, "ms": ms()}


def cmd_nomoney(a: dict) -> dict:
    """Is the game's red "Not enough money!" message showing (bottom middle of the screen)?"""
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    bx, by, bw, bh = x + int(w * 0.22), y + int(h * 0.70), int(w * 0.56), int(h * 0.12)
    img = grab(bx, by, bw, bh).astype(np.int16)
    B, G, R = img[:, :, 0], img[:, :, 1], img[:, :, 2]
    # the message is a pinkish red (about 255, 80, 80) spread across the middle; enemy health bars and
    # name tags are pure red (almost no green) and small - those used to fool the old check
    m = (R >= 215) & (G >= 45) & (G <= 150) & (B >= 45) & (B <= 150) & (R - G >= 90)
    n = int(m.sum())
    spread = float((m.sum(0) >= 2).mean())
    if _SAVED["n"] < 60 and a.get("save") == "1":
        _SAVED["n"] += 1
        try:
            cv2.imwrite(_pic(f"nomoney_{time.strftime('%H%M%S')}_{n}.jpg"), img.astype(np.uint8))
        except Exception:
            pass
    return {"ok": "1", "nomoney": "1" if (n >= 600 and spread >= 0.25) else "0", "px": f"{n} spread {spread:.2f}"}


PRINT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Settings", "MapPrints")


def _print_of(x, y, w, h):
    img = grab(x, y, w, h)
    hh, ww = img.shape[:2]
    crop = img[int(hh * 0.25):int(hh * 0.80), int(ww * 0.15):int(ww * 0.80)]   # skip vote box, buttons, minimap
    small = cv2.resize(crop, (48, 32), interpolation=cv2.INTER_AREA)
    return cv2.GaussianBlur(small, (3, 3), 0)


def cmd_print(a: dict) -> dict:
    """Fingerprint of the view right after teleport-to-spawn: 'save' it under a map name, or 'match' it
    against the saved ones - recognises maps that have no loading-screen picture or readable banner."""
    x, y, w, h = (int(a[k]) for k in ("x", "y", "w", "h"))
    fp = _print_of(x, y, w, h).astype(np.int16)
    os.makedirs(PRINT_DIR, exist_ok=True)
    if a.get("mode") == "save":
        name = "".join(ch if ch.isalnum() or ch in " ()-" else "_" for ch in a.get("name", ""))[:60]
        cv2.imwrite(os.path.join(PRINT_DIR, name + ".png"), fp.astype(np.uint8))
        return {"ok": "1", "info": "saved " + name}
    best, best_d = "", 999.0
    for fn in os.listdir(PRINT_DIR):
        if not fn.endswith(".png") or fn.startswith("_"):
            continue
        ref = cv2.imread(os.path.join(PRINT_DIR, fn))
        if ref is None or ref.shape != fp.shape:
            continue
        d = float(np.abs(ref.astype(np.int16) - fp).mean())
        if d < best_d:
            best, best_d = fn[:-4], d
    ok = best != "" and best_d < 22
    return {"ok": "1", "name": best if ok else "", "dist": f"{best_d:.1f}", "nearest": best}


MINI_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Settings", "MiniMaps")
_MINI_K = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))


def _mini_mask(x: int, y: int) -> np.ndarray:
    """The green enemy path drawn on the minimap (bottom right of the 800x600 game picture). The minimap
    doesn't move or turn, so each map's path has one fixed shape. x, y = the game picture's top-left."""
    img = grab(x + 645, y + 440, 150, 155)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    m = cv2.inRange(hsv, (38, 110, 130), (80, 255, 255))
    m[:10, :] = 0
    m[-10:, :] = 0
    m[:, :10] = 0
    m[:, -10:] = 0      # the minimap's own green frame
    return (m > 0).astype(np.uint8)


def _mini_score(q: np.ndarray, r: np.ndarray):
    """(precision, recall): how much of the path seen now lies on the saved path, and the other way round.
    Enemies walking on the path hide bits of it, so neither needs to be perfect."""
    qd = cv2.dilate(q, _MINI_K)
    rd = cv2.dilate(r, _MINI_K)
    prec = float((q & rd).sum()) / max(1.0, float(q.sum()))
    rec = float((r & qd).sum()) / max(1.0, float(r.sum()))
    return prec, rec


def cmd_mini(a: dict) -> dict:
    """Minimap path shape: 'save' it under a map name, or 'match' it against the saved ones."""
    x, y = int(a["x"]), int(a["y"])
    q = _mini_mask(x, y)
    px = int(q.sum())
    if px < 250:
        return {"ok": "0", "info": f"no minimap path visible ({px} px)"}
    if a.get("mode") == "save" and px < 350:     # enemies already covering much of it - not a clean picture
        return {"ok": "0", "info": f"minimap path too hidden to save ({px} px)"}
    os.makedirs(MINI_DIR, exist_ok=True)
    if a.get("mode") == "score":   # how well the minimap on screen fits ONE saved map
        name = "".join(ch if ch.isalnum() or ch in " ()-" else "_" for ch in a.get("name", ""))[:60]
        ref = cv2.imread(os.path.join(MINI_DIR, name + ".png"), cv2.IMREAD_GRAYSCALE)
        if ref is None or ref.shape != q.shape:
            return {"ok": "0", "info": "no saved minimap for " + name}
        p, r = _mini_score(q, (ref > 127).astype(np.uint8))
        f = 2 * p * r / max(1e-6, p + r)
        return {"ok": "1", "score": f"{f:.2f}", "info": f"{name}: {f:.2f} (on path {p:.2f}, path seen {r:.2f})"}
    if a.get("mode") == "save":
        name = "".join(ch if ch.isalnum() or ch in " ()-" else "_" for ch in a.get("name", ""))[:60]
        if not name:
            return {"ok": "0", "info": "no name"}
        cv2.imwrite(os.path.join(MINI_DIR, name + ".png"), q * 255)
        return {"ok": "1", "info": f"saved {name} ({px} px)"}
    res = []
    for fn in os.listdir(MINI_DIR):
        if not fn.endswith(".png") or fn.startswith("_"):
            continue
        ref = cv2.imread(os.path.join(MINI_DIR, fn), cv2.IMREAD_GRAYSCALE)
        if ref is None or ref.shape != q.shape:
            continue
        p, r = _mini_score(q, (ref > 127).astype(np.uint8))
        f = 2 * p * r / max(1e-6, p + r)
        res.append((f, p, r, fn[:-4]))
    if not res:
        return {"ok": "1", "name": "", "info": "no saved minimaps yet"}
    res.sort(reverse=True)
    f, p, r, n = res[0]
    second = res[1][0] if len(res) > 1 else 0.0
    ok = p >= 0.6 and r >= 0.7 and f >= 0.65 and f - second >= 0.15
    info = f"{n} match {f:.2f} (on path {p:.2f}, path seen {r:.2f}), next best {second:.2f}"
    return {"ok": "1", "name": n if ok else "", "nearest": n, "info": info}


def cmd_forget(a: dict) -> dict:
    """A new walk for this map: drop the places that failed before (they were for the old view)."""
    key = _mem_name(a.get("name", ""))
    if not key:
        return {"ok": "0", "info": "no name"}
    _MEM.pop(key, None)
    path = os.path.join(MEM_DIR, key + ".png")
    if os.path.exists(path):
        os.replace(path, path + ".old_" + time.strftime("%m%d_%H%M"))
    return {"ok": "1", "info": "forgot " + key}


def handle(a: dict) -> dict:
    c = a.get("cmd")
    if c == "ping":
        return {"ok": "1", "ocr": "rapidocr"}
    if c == "ocr":
        return cmd_ocr(a)
    if c == "place":
        return cmd_place(a)
    if c == "nomoney":
        return cmd_nomoney(a)
    if c == "fail":
        return cmd_fail(a)
    if c == "find":
        return cmd_find(a)
    if c == "print":
        return cmd_print(a)
    if c == "mini":
        return cmd_mini(a)
    if c == "forget":
        return cmd_forget(a)
    if c == "base":
        return cmd_base(a)
    if c == "hover":
        return cmd_hover(a)
    if c == "quit":
        raise SystemExit
    return {"ok": "0", "info": "unknown command"}


def main() -> None:
    log(f"helper started (python {sys.version.split()[0]}), watching {IPC}")
    try:
        get_ocr()  # load the models now so the first real request is fast
        log("RapidOCR ready")
    except Exception as e:  # OCR is optional - placement still works
        log(f"RapidOCR not available: {e}")
    try:  # warm up OpenCV so the first real placement is fast
        z = np.zeros((300, 400), bool)
        _room_cov("warmup", z, z, 45)
        _ROOM["id"] = None
        _ROOM["path"] = None
    except Exception as e:
        log(f"warm-up failed: {e}")
    with open(os.path.join(IPC, "ready.txt"), "w", encoding="utf-8") as fh:
        fh.write(str(os.getpid()))
    last_check = 0.0
    last_req = time.time()
    while True:
        names = [n for n in os.listdir(IPC) if n.startswith("req_") and n.endswith(".txt")]
        if names:
            last_req = time.time()
        for n in names:
            rid = n[4:-4]
            path = os.path.join(IPC, n)
            try:
                with open(path, encoding="utf-8") as fh:
                    args = dict(l.split("=", 1) for l in fh.read().splitlines() if "=" in l)
                os.remove(path)
            except OSError:
                continue
            try:
                out = handle(args)
            except SystemExit:
                log("quit requested")
                return
            except Exception as e:
                out = {"ok": "0", "info": "error: " + str(e).replace("\n", " ")}
                log(traceback.format_exc())
            tmp = os.path.join(IPC, f"resp_{rid}.tmp")
            with open(tmp, "w", encoding="utf-8") as fh:
                fh.write("\n".join(f"{k}={v}" for k, v in out.items()))
            os.replace(tmp, os.path.join(IPC, f"resp_{rid}.txt"))
        now = time.time()
        if now - last_check > 2:
            last_check = now
            if not parent_alive():
                log("macro closed - helper exiting")
                return
        # [Lag] look for new requests often while the macro is busy, much less often when it's idle
        idle = time.time() - last_req
        time.sleep(0.01 if names else (0.02 if idle < 3 else 0.06))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log("helper crashed:\n" + traceback.format_exc())
    finally:
        try:
            os.remove(os.path.join(IPC, "ready.txt"))
        except OSError:
            pass
