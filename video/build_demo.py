#!/usr/bin/env python3
"""Build a narrated PayWatch demo: slides + English TTS + burned-in captions."""
from __future__ import annotations

import subprocess
import textwrap
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/workspace/competitions-2/reactive-paywatch")
OUT_MP4 = ROOT / "demo.mp4"
OUT_SRT = ROOT / "demo.srt"
LOGO = ROOT / "logo.png"
COVER = ROOT / "cover.png"
WORK = Path("/tmp/paywatch-demo")
AUDIO = WORK / "audio"
FRAMES = WORK / "frames"
EDGE_TTS = "/workspace/codegeist/.venv-video/bin/edge-tts"
VOICE = "en-US-AndrewNeural"
W, H = 1920, 1080

BG = (7, 10, 18)
AMBER = (255, 176, 32)
AMBER_DIM = (140, 96, 20)
CYAN = (90, 200, 255)
WHITE = (232, 238, 246)
DIM = (120, 138, 158)
PANEL = (14, 20, 32)
LINE = (36, 50, 72)
OK = (80, 220, 140)
MUTED = (70, 86, 104)

NARRATION = [
    (
        "title",
        "title",
        "PayWatch is a personal large-transfer watchdog you can leave running.",
    ),
    (
        "problem",
        "problem",
        "People still screenshot a payment, or run a watcher script that dies when the laptop sleeps. PayWatch does the same job on-chain. There is no bot to keep online.",
    ),
    (
        "architecture",
        "architecture",
        "A reactive contract on Lasna watches ERC-20 Transfer logs on Base Sepolia. If a watched wallet sends or receives at or above your cap, it requests a callback.",
    ),
    (
        "board",
        "board",
        "An AlertBoard on Base Sepolia records the event. Only the official callback proxy can write it, and only on behalf of the authorized reactive contract.",
    ),
    (
        "tests",
        "tests",
        "The Foundry suite covers subscribe on construct, incoming and outgoing hits, below-threshold noise, cooldown, and AlertBoard authentication. Fourteen tests, all passing.",
    ),
    (
        "demo",
        "demo",
        "In the demo, we mint mock dollars and send two hundred and fifty, above a one hundred cap. The board's alert count goes from zero to one: origin transfer, reactive ThresholdHit, then the callback.",
    ),
    (
        "close",
        "close",
        "PayWatch. Set it, and forget it. Built for the Reactive Omni Buildathon, Set It and Forget It track.",
    ),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    )
    if Path(path).exists():
        return ImageFont.FreeTypeFont(path, size)
    return ImageFont.load_default()


def font_mono(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            return ImageFont.FreeTypeFont(p, size)
    return font(size, bold)


def new_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 8], fill=AMBER)
    return im, d


def header(d: ImageDraw.ImageDraw, right: str) -> None:
    d.text((48, 22), "PAYWATCH", fill=AMBER, font=font(28, bold=True))
    d.text((240, 28), "Reactive Omni Buildathon  ·  Set It and Forget It", fill=DIM, font=font(20))
    bbox = d.textbbox((0, 0), right, font=font(18))
    d.text((W - 48 - (bbox[2] - bbox[0]), 28), right, fill=DIM, font=font(18))


def rounded_rect(d: ImageDraw.ImageDraw, box, fill, outline=None, width=1, radius=16) -> None:
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def wrap_text(d, text, fnt, max_width) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = (cur + " " + w).strip()
        if d.textbbox((0, 0), trial, font=fnt)[2] <= max_width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def make_logo() -> None:
    size = 1024
    im = Image.new("RGB", (size, size), (8, 12, 22))
    d = ImageDraw.Draw(im)
    # faint rings
    for r, col in ((460, (18, 26, 42)), (400, (24, 34, 52))):
        d.ellipse([size // 2 - r, size // 2 - r - 40, size // 2 + r, size // 2 + r - 40], outline=col, width=3)
    cx, cy = size // 2, size // 2 - 40
    # bezel
    d.ellipse([cx - 280, cy - 280, cx + 280, cy + 280], outline=AMBER, width=14)
    d.ellipse([cx - 252, cy - 252, cx + 252, cy + 252], outline=AMBER_DIM, width=3)
    # tick marks
    import math
    for i in range(12):
        ang = math.radians(i * 30 - 90)
        inner, outer = (210, 238) if i % 3 == 0 else (220, 236)
        x1, y1 = cx + inner * math.cos(ang), cy + inner * math.sin(ang)
        x2, y2 = cx + outer * math.cos(ang), cy + outer * math.sin(ang)
        d.line([(x1, y1), (x2, y2)], fill=AMBER if i % 3 == 0 else AMBER_DIM, width=6 if i % 3 == 0 else 3)
    # eye
    d.ellipse([cx - 150, cy - 90, cx + 150, cy + 90], outline=CYAN, width=8)
    d.ellipse([cx - 48, cy - 48, cx + 48, cy + 48], fill=AMBER)
    d.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=BG)
    # alert pip
    d.ellipse([cx + 150, cy - 190, cx + 198, cy - 142], fill=AMBER)
    d.text((64, 860), "PAYWATCH", fill=AMBER, font=font(92, bold=True))
    d.text((68, 960), "SET IT  ·  FORGET IT", fill=DIM, font=font(28))
    im.save(LOGO, optimize=True)
    print("logo", LOGO, LOGO.stat().st_size)


def make_cover() -> None:
    im, d = new_canvas()
    d.text((80, 120), "PAYWATCH", fill=AMBER, font=font(112, bold=True))
    d.text((84, 260), "A personal large-transfer watchdog you can leave running.", fill=WHITE, font=font(36))
    d.text((84, 330), "Reactive Omni Buildathon  ·  Set It and Forget It  ·  Lasna + Base Sepolia", fill=DIM, font=font(26))
    # three step chips
    steps = [
        ("01", "ORIGIN", "MockUSD.Transfer\nBase Sepolia"),
        ("02", "REACTIVE", "PayWatchReactive\nLasna"),
        ("03", "CALLBACK", "AlertBoard\nBase Sepolia"),
    ]
    x = 80
    for num, label, body in steps:
        rounded_rect(d, [x, 480, x + 520, 860], PANEL, outline=LINE, width=2, radius=20)
        d.text((x + 32, 508), num, fill=AMBER, font=font(28, bold=True))
        d.text((x + 100, 508), label, fill=CYAN, font=font(28, bold=True))
        yy = 600
        for line in body.split("\n"):
            d.text((x + 32, yy), line, fill=WHITE, font=font(32, bold=True) if yy == 600 else font(28))
            yy += 56
        x += 580
        if num != "03":
            d.polygon(
                [(x - 40, 650), (x - 16, 670), (x - 40, 690)],
                fill=AMBER,
            )
    d.text((84, 960), "github.com/w1nter625/paywatch", fill=DIM, font=font(26))
    im.save(COVER, optimize=True)
    print("cover", COVER, COVER.stat().st_size)


def frame_title() -> Image.Image:
    im, d = new_canvas()
    d.text((160, 300), "PAYWATCH", fill=AMBER, font=font(140, bold=True))
    d.text((168, 470), "A personal large-transfer watchdog", fill=WHITE, font=font(44))
    d.text((168, 540), "you can leave running.", fill=WHITE, font=font(44))
    d.text((168, 680), "Reactive Omni Buildathon  ·  Set It and Forget It", fill=DIM, font=font(30))
    d.text((168, 860), "No bot to keep online.  ·  MIT license.", fill=DIM, font=font(26))
    return im


def frame_problem() -> Image.Image:
    im, d = new_canvas()
    header(d, "THE HABIT")
    cards = [
        ("The old way", "Screenshot a payment.\nRun a watcher script.\nIt dies when the laptop sleeps."),
        ("PayWatch", "A cap you actually want to keep.\nA reactive contract watches Transfer logs.\nThe alert is recorded on-chain."),
    ]
    x = 80
    for i, (title, body) in enumerate(cards):
        outline = AMBER if i == 1 else LINE
        rounded_rect(d, [x, 160, x + 860, 860], PANEL, outline=outline, width=3, radius=24)
        d.text((x + 48, 200), title, fill=AMBER if i == 1 else DIM, font=font(40, bold=True))
        yy = 320
        for line in body.split("\n"):
            d.text((x + 48, yy), line, fill=WHITE, font=font(32))
            yy += 80
        x += 900
    return im


def frame_architecture() -> Image.Image:
    im, d = new_canvas()
    header(d, "THE LOOP")
    cols = [
        ("BASE SEPOLIA", "84532", "MockUSD", "Transfer log\nwatched wallet\namount ≥ cap"),
        ("LASNA", "5318007", "PayWatchReactive", "react()\nfilter + cooldown\nrequestCallback"),
        ("BASE SEPOLIA", "84532", "AlertBoard", "recordAlert\nvia callback proxy\nalertCount += 1"),
    ]
    x = 80
    for i, (chain, cid, contract, body) in enumerate(cols):
        rounded_rect(d, [x, 160, x + 540, 900], PANEL, outline=LINE, width=2, radius=24)
        d.text((x + 36, 190), chain, fill=CYAN, font=font(24, bold=True))
        d.text((x + 36, 230), f"chain {cid}", fill=DIM, font=font(20))
        d.text((x + 36, 300), contract, fill=AMBER, font=font(32, bold=True))
        yy = 400
        for line in body.split("\n"):
            d.text((x + 36, yy), line, fill=WHITE, font=font(30))
            yy += 70
        if i < 2:
            d.polygon([(x + 560, 500), (x + 600, 530), (x + 560, 560)], fill=AMBER)
        x += 610
    return im


def frame_board() -> Image.Image:
    im, d = new_canvas()
    header(d, "AUTHENTICATION")
    rounded_rect(d, [80, 160, 1840, 900], PANEL, outline=LINE, width=2, radius=24)
    rows = [
        ("Who may call", "Only the official Base Sepolia callback proxy."),
        ("Proxy address", "0x476F44b11F5C942c58f4c8E3d0300E5710743585"),
        ("On behalf of", "The authorized PayWatchReactive contract on Lasna."),
        ("What is stored", "Wallet, counterparty, token, amount, direction, origin tx."),
        ("Cooldown", "Seconds via block.timestamp — required on 200 ms Base Sepolia."),
        ("Why it matters", "A forged alert from any other address is rejected."),
    ]
    yy = 200
    for label, value in rows:
        d.text((120, yy), label, fill=DIM, font=font(26))
        d.text((520, yy), value, fill=WHITE, font=font(28, bold=True) if value.startswith("0x") else font(28))
        yy += 110
    return im


def frame_tests() -> Image.Image:
    im, d = new_canvas()
    header(d, "FOUNDRY  ·  14 / 14")
    rounded_rect(d, [80, 140, 1840, 980], (10, 14, 22), outline=LINE, width=2, radius=20)
    d.ellipse([110, 168, 132, 190], fill=(255, 95, 86))
    d.ellipse([148, 168, 170, 190], fill=(255, 189, 46))
    d.ellipse([186, 168, 208, 190], fill=(39, 201, 63))
    d.text((240, 160), "forge test -vv   ·   PayWatch.t.sol", fill=DIM, font=font_mono(22))
    tests = [
        "test_alertBoardRecordsFromProxy",
        "test_alertBoardRejectsNonProxy",
        "test_alertBoardRejectsWrongReactive",
        "test_belowThresholdIgnored",
        "test_constructorSubscribes",
        "test_cooldownSuppressesSecondFire",
        "test_mockUsdTransferEmitsAndMovesBalance",
        "test_noCallbackUntilBoardSet",
        "test_reactIncomingAboveThresholdRequestsCallback",
        "test_reactOnlySystem",
        "test_reactOutgoingAboveThresholdRequestsCallback",
        "test_setBoardOnlyOwner",
        "test_unrelatedWalletIgnored",
        "test_wrongTokenIgnored",
    ]
    col_w = 840
    for i, name in enumerate(tests):
        col = 0 if i < 7 else 1
        row = i if i < 7 else i - 7
        x = 120 + col * col_w
        y = 230 + row * 90
        d.text((x, y), "[PASS]", fill=OK, font=font_mono(24, bold=True))
        d.text((x + 130, y), name, fill=WHITE, font=font_mono(22))
    d.text((120, 900), "Suite result: ok.  14 passed;  0 failed;  0 skipped.", fill=OK, font=font_mono(24, bold=True))
    return im


def frame_demo() -> Image.Image:
    im, d = new_canvas()
    header(d, "DEMO LOOP")
    steps = [
        ("1", "Mint 1,000 pUSD", "to the watched wallet\non Base Sepolia"),
        ("2", "Transfer 250 pUSD", "above the 100 cap\nemits Transfer"),
        ("3", "ThresholdHit", "PayWatchReactive\nemits on Lasna"),
        ("4", "alertCount = 1", "AlertBoard callback\non Base Sepolia"),
    ]
    x = 60
    for i, (num, title, body) in enumerate(steps):
        rounded_rect(d, [x, 200, x + 420, 780], PANEL, outline=AMBER if i == 3 else LINE, width=3, radius=20)
        d.ellipse([x + 36, 236, x + 96, 296], outline=AMBER, width=3)
        bbox = d.textbbox((0, 0), num, font=font(28, bold=True))
        tw = bbox[2] - bbox[0]
        d.text((x + 66 - tw / 2, 244), num, fill=AMBER, font=font(28, bold=True))
        d.text((x + 36, 340), title, fill=WHITE, font=font(28, bold=True))
        yy = 430
        for line in body.split("\n"):
            d.text((x + 36, yy), line, fill=DIM, font=font(24))
            yy += 44
        if i < 3:
            d.polygon([(x + 436, 470), (x + 468, 496), (x + 436, 522)], fill=AMBER)
        x += 470
    d.text((80, 860), "Origin Transfer  →  Lasna ThresholdHit  →  AlertBoard.AlertRecorded", fill=CYAN, font=font(28))
    d.text((80, 920), "Live transaction hashes will be recorded in demo-txs.md after testnet funding.", fill=DIM, font=font(22))
    return im


def frame_close() -> Image.Image:
    im, d = new_canvas()
    d.text((160, 280), "PAYWATCH", fill=AMBER, font=font(120, bold=True))
    d.text((168, 430), "Set it, and forget it.", fill=WHITE, font=font(44))
    d.text((168, 560), "github.com/w1nter625/paywatch", fill=CYAN, font=font(36))
    d.text((168, 680), "Reactive Omni Buildathon  ·  Set It and Forget It", fill=DIM, font=font(28))
    d.text((168, 860), "MIT license.  No custody.  No off-chain bot.", fill=DIM, font=font(24))
    return im


def render_still(kind: str, dest: Path) -> None:
    makers = {
        "title": frame_title,
        "problem": frame_problem,
        "architecture": frame_architecture,
        "board": frame_board,
        "tests": frame_tests,
        "demo": frame_demo,
        "close": frame_close,
        "end": frame_close,
    }
    im = makers[kind]()
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, optimize=True)


def tts(key: str, text: str) -> tuple[Path, Path, float]:
    AUDIO.mkdir(parents=True, exist_ok=True)
    mp3 = AUDIO / f"{key}.mp3"
    srt = AUDIO / f"{key}.srt"
    if mp3.exists() and mp3.stat().st_size >= 1000 and srt.exists():
        dur = float(
            subprocess.check_output(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(mp3)],
                text=True,
            ).strip()
        )
        print(f"tts {key}: {dur:.2f}s (cached)")
        return mp3, srt, dur
    last_err = None
    for attempt in range(1, 6):
        try:
            if mp3.exists():
                mp3.unlink()
            subprocess.run(
                [
                    EDGE_TTS,
                    "--voice",
                    VOICE,
                    "--rate=-5%",
                    "--text",
                    text,
                    "--write-media",
                    str(mp3),
                    "--write-subtitles",
                    str(srt),
                    "--no-progress",
                ],
                check=True,
            )
            if mp3.exists() and mp3.stat().st_size >= 1000:
                break
            last_err = f"tiny file ({mp3.stat().st_size if mp3.exists() else 0} bytes)"
        except subprocess.CalledProcessError as e:
            last_err = e
        time.sleep(1.5 * attempt)
    else:
        raise SystemExit(f"TTS failed for {key}: {last_err}")
    dur = float(
        subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(mp3)],
            text=True,
        ).strip()
    )
    print(f"tts {key}: {dur:.2f}s")
    return mp3, srt, dur


def ts(x: float) -> str:
    if x < 0:
        x = 0
    h = int(x // 3600)
    m = int(x % 3600 // 60)
    s = x % 60
    return f"{h:02}:{m:02}:{int(s):02},{int(round((s - int(s)) * 1000)):03}"


def parse_ts(s: str) -> float:
    h, m, r = s.split(":")
    sec, ms = r.split(",")
    return int(h) * 3600 + int(m) * 60 + int(sec) + int(ms) / 1000


def build_video() -> float:
    FRAMES.mkdir(parents=True, exist_ok=True)
    AUDIO.mkdir(parents=True, exist_ok=True)
    segs = []
    srt_blocks = []
    n = 1
    off = 0.0
    pad_after = 0.65
    pre_roll = 0.25

    for key, beat, text in NARRATION:
        mp3, part_srt, dur = tts(key, text)
        hold = dur + pre_roll + pad_after
        frame = FRAMES / f"{key}.png"
        render_still(beat, frame)
        out = WORK / f"seg_{key}.mp4"
        fade_out_start = max(0.05, hold - 0.25)
        vf = f"fade=t=in:st=0:d=0.2,fade=t=out:st={fade_out_start:.2f}:d=0.25,format=yuv420p"
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error",
                "-loop", "1", "-framerate", "30", "-i", str(frame),
                "-i", str(mp3),
                "-af", f"adelay={int(pre_roll*1000)}|{int(pre_roll*1000)},apad",
                "-t", f"{hold:.2f}",
                "-vf", vf,
                "-c:v", "libx264", "-preset", "medium", "-crf", "18",
                "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-ac", "2",
                "-pix_fmt", "yuv420p",
                str(out),
            ],
            check=True,
        )
        segs.append(out)
        raw = part_srt.read_text().strip()
        if raw:
            for blk in raw.split("\n\n"):
                lines = blk.split("\n")
                if len(lines) < 3:
                    continue
                a, b = lines[1].split(" --> ")
                txt = " ".join(lines[2:])
                srt_blocks.append(
                    f"{n}\n{ts(off + pre_roll + parse_ts(a))} --> {ts(off + pre_roll + parse_ts(b))}\n{txt}\n"
                )
                n += 1
        off += hold

    end_hold = 2.8
    end_frame = FRAMES / "end.png"
    render_still("end", end_frame)
    end_out = WORK / "seg_end.mp4"
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-loop", "1", "-framerate", "30", "-i", str(end_frame),
            "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
            "-t", f"{end_hold:.2f}",
            "-vf", "fade=t=in:st=0:d=0.3,format=yuv420p",
            "-c:v", "libx264", "-preset", "medium", "-crf", "18",
            "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-ac", "2",
            "-pix_fmt", "yuv420p", "-shortest",
            str(end_out),
        ],
        check=True,
    )
    segs.append(end_out)
    off += end_hold

    lst = WORK / "list.txt"
    lst.write_text("".join(f"file '{s}'\n" for s in segs))
    OUT_SRT.write_text("\n".join(srt_blocks) + "\n")
    raw = WORK / "raw.mp4"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(raw)],
        check=True,
    )
    style = (
        "FontName=DejaVu Sans,FontSize=28,PlayResX=1920,PlayResY=1080,"
        "PrimaryColour=&H00EAF8FF,OutlineColour=&H80000000,BackColour=&H90000000,"
        "BorderStyle=3,Outline=2,Shadow=0,MarginV=36,Alignment=2"
    )
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(raw),
            "-vf", f"subtitles={OUT_SRT}:force_style='{style}'",
            "-c:v", "libx264", "-preset", "medium", "-crf", "18",
            "-c:a", "copy",
            "-movflags", "+faststart",
            "-pix_fmt", "yuv420p",
            str(OUT_MP4),
        ],
        check=True,
    )
    print("wrote", OUT_MP4, "duration", round(off, 2))
    return off


def main() -> None:
    make_logo()
    make_cover()
    total = build_video()
    probe = float(
        subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(OUT_MP4)],
            text=True,
        ).strip()
    )
    print("FINAL", OUT_MP4, f"{probe:.2f}s", OUT_MP4.stat().st_size, "bytes")
    if probe > 180:
        raise SystemExit(f"demo is {probe:.1f}s, over the 3 minute limit")


if __name__ == "__main__":
    main()
