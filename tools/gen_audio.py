# 냉털 셰프 오디오 생성기: BGM과 효과음을 numpy로 직접 합성해 game/audio/*.ogg 로 저장
# 외부 샘플 없음 (저작권 문제 없음). 실행: python3 tools/gen_audio.py  (numpy, ffmpeg 필요)
import os
import subprocess
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "audio")
rng = np.random.default_rng(7)


def save(name, x):
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = x[:, None]
    pk = np.max(np.abs(x))
    if pk > 0.98:
        x = x * (0.98 / pk)
    pcm = (x * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", str(x.shape[1]),
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "5", path], input=pcm, check=True)


def norm(x, peak=0.9):
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def band(x, lo, hi, slope=0.15):
    """FFT 대역 필터 (원형이라 루프가 끊김 없이 이어짐)"""
    n = len(x)
    X = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(n, 1 / SR)
    m = np.ones_like(f)
    if lo > 0:
        m *= 1 / (1 + (lo / np.maximum(f, 1)) ** (1 / slope * 0.5))
    if hi > 0:
        m *= 1 / (1 + (f / hi) ** (1 / slope * 0.5))
    if X.ndim == 2:
        m = m[:, None]
    return np.fft.irfft(X * m, n, axis=0)


def noise(n):
    return rng.standard_normal(n)


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def add_at(buf, x, i, wrap=True):
    n = len(buf)
    idx = (np.arange(len(x)) + i)
    if wrap:
        np.add.at(buf, idx % n, x)
    else:
        idx = idx[idx < n]
        buf[idx] += x[:len(idx)]


def creverb(x, sec=1.6, tau=0.38, wet=0.2, seed=1):
    """원형 컨볼루션 리버브 (루프 이음매 없음)"""
    r = np.random.default_rng(seed)
    n = len(x)
    out = np.zeros_like(x)
    for ch in range(x.shape[1]):
        m = int(sec * SR)
        ir = r.standard_normal(m) * np.exp(-np.arange(m) / (tau * SR))
        ir = band(ir, 200, 5000)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        h = np.zeros(n)
        h[:m] = ir
        out[:, ch] = np.fft.irfft(np.fft.rfft(x[:, ch]) * np.fft.rfft(h), n)
    return x + out * wet


# =====================================================================
# BGM: 느긋한 스윙 주방 재즈 (96 BPM, F장조, 16마디 루프)
# =====================================================================
BPM = 96
BEAT = 60 / BPM
BARS = 16
LOOP = int(round(BARS * 4 * BEAT * SR))
SW = 0.62  # 스윙 8분 뒷박 위치


def mtof(m):
    return 440 * 2 ** ((m - 69) / 12)


def t2i(bar, beat):
    return int(round((bar * 4 + beat) * BEAT * SR))


def ep_note(m, dur, vel):
    """일렉 피아노: FM 벨 어택 + 부드러운 사인 몸통"""
    f = mtof(m)
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    idx = 1.3 * np.exp(-t / 0.18) + 0.15
    car = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    body = 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.4)
    e = np.exp(-t / 1.4)
    rel = np.clip((dur - t) / 0.12 + 1, 0, 1) ** 2
    e = e * np.where(t < dur, 1, rel)
    a = np.minimum(1, t / 0.004)
    return (car + body) * e * a * vel


def marimba(m, dur, vel):
    f = mtof(m)
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / (0.32 + 0.2 * (72 / m)))
    x += 0.35 * np.sin(2 * np.pi * 3.93 * f * t) * np.exp(-t / 0.05)
    x += 0.12 * np.sin(2 * np.pi * 9.2 * f * t) * np.exp(-t / 0.015)
    x *= np.minimum(1, t / 0.002)
    return x * vel


def bass_note(m, dur, vel):
    f = mtof(m)
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.25) + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.1)
    e = np.exp(-t / 0.9) * np.minimum(1, t / 0.006)
    e *= np.where(t < dur, 1, np.clip(1 - (t - dur) / 0.08, 0, 1))
    return x * e * vel


def kick(vel):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 48 + 70 * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / 0.12) * vel


def brush(vel, length=0.18):
    n = int(length * SR)
    x = band(noise(n), 1500, 9000)
    t = np.arange(n) / SR
    return norm(x) * np.exp(-t / (length / 3.5)) * np.minimum(1, t / 0.01) * vel


def rim(vel):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1750 * t) * np.exp(-t / 0.012) + 0.6 * norm(band(noise(n), 2000, 7000)) * np.exp(-t / 0.02)
    return x * vel


def hat(vel):
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    return norm(band(noise(n), 6000, 14000)) * np.exp(-t / 0.012) * vel


# 마디별 코드: (박, 루트 midi, 보이싱)
CH = {
    "F": (41, [57, 60, 64, 67]), "Dm": (38, [53, 57, 60, 64]), "Gm": (43, [58, 62, 65, 69]),
    "C7": (36, [58, 62, 64, 69]), "Am": (45, [55, 60, 64, 67]), "D7": (38, [54, 60, 64, 69]),
    "Bb": (46, [57, 62, 65, 69]), "Bbm": (46, [56, 61, 65, 67]),
}
PROG = [["F"], ["Dm"], ["Gm"], ["C7"], ["Am"], ["D7"], ["Gm"], ["C7"],
        ["Bb"], ["Bbm"], ["Am"], ["D7"], ["Gm"], ["C7"], ["F"], ["Gm", "C7"]]

# 멜로디 (마림바): 마디 -> [(박, midi, 길이)]
MEL = {
    0: [(0, 72, .6), (SW, 74, .4), (1, 77, 1.0), (2 + SW, 76, .4), (3, 72, .9)],
    1: [(SW, 69, .4), (1, 72, .6), (1 + SW, 74, .4), (2, 77, 1.8)],
    2: [(2 + SW, 74, .4), (3, 77, .4), (3 + SW, 79, .4)],
    3: [(0, 81, .9), (1, 79, .6), (1 + SW, 76, .4), (2, 79, .5), (2 + SW, 70, .9)],
    4: [(0, 76, 1.0), (1 + SW, 72, .4), (2, 76, .5), (2 + SW, 79, 1.2)],
    5: [(SW, 78, .4), (1, 81, .6), (1 + SW, 78, .4), (2, 76, .6), (2 + SW, 74, 1.2)],
    6: [(0, 70, .6), (SW, 74, .4), (1, 77, .6), (1 + SW, 81, .4), (2, 79, 1.5)],
    7: [(1, 76, .5), (1 + SW, 79, .4), (2, 82, .6), (2 + SW, 81, .4), (3, 79, .8)],
    8: [(0, 77, 1.0), (1 + SW, 74, .4), (2, 81, 1.2), (3 + SW, 77, .3)],
    9: [(0, 73, 1.0), (1 + SW, 77, .4), (2, 79, 1.5)],
    10: [(0, 76, .6), (SW, 79, .4), (1, 84, .6), (1 + SW, 81, .4), (2, 79, .6), (2 + SW, 76, 1.1)],
    11: [(SW, 78, .4), (1, 81, .4), (1 + SW, 84, .4), (2, 81, .6), (2 + SW, 78, .9)],
    12: [(0, 79, .6), (SW, 77, .4), (1, 74, .6), (1 + SW, 70, .4), (2, 74, .6), (2 + SW, 77, .9)],
    13: [(0, 76, 1.0), (1 + SW, 79, .4), (2, 82, .6), (2 + SW, 81, .4), (3, 79, .5)],
    14: [(0, 81, 2.0), (2 + SW, 79, .4), (3, 77, .8)],
    15: [(SW, 74, .4), (1, 77, .4), (2, 76, .6), (2 + SW, 76, .9)],
}

COMP = [[(0, 1.3, .9), (1 + SW, .45, .6), (3 + SW, .4, .55)],
        [(0, 1.5, .9), (2, .45, .6), (2 + SW, 1.1, .7)]]


def make_bgm():
    L = np.zeros((LOOP, 2))
    ep = np.zeros(LOOP); ma = np.zeros(LOOP); bs = np.zeros(LOOP); dr = np.zeros(LOOP); ht = np.zeros(LOOP)
    for b, chords in enumerate(PROG):
        half = 4 / len(chords)
        for ci, c in enumerate(chords):
            root, voi = CH[c]
            off = ci * half
            nxt = PROG[(b + 1) % BARS][0] if ci == len(chords) - 1 else chords[ci + 1]
            # 피아노 컴핑
            pat = COMP[b % 2] if len(chords) == 1 else [(0, 1.2, .9), (1 + SW, .4, .6)]
            for (bt, d, v) in pat:
                for k, m in enumerate(voi):
                    jit = int(k * 0.006 * SR)
                    add_at(ep, ep_note(m, d * BEAT, 0.16 * v), t2i(b, off + bt) + jit)
            # 베이스: 근음, 5도, 다음 코드 반음 접근
            if len(chords) == 1:
                add_at(bs, bass_note(root, 1.7 * BEAT, .45), t2i(b, 0))
                add_at(bs, bass_note(root + 7, 1.0 * BEAT, .38), t2i(b, 2))
                if b % 2 == 1 or b == BARS - 1:
                    tgt = CH[nxt][0]
                    add_at(bs, bass_note(tgt + (1 if tgt < root + 7 else -1), .35 * BEAT, .4), t2i(b, 3 + SW))
                else:
                    add_at(bs, bass_note(root + 12 if root < 40 else root, .5 * BEAT, .35), t2i(b, 3 + SW))
            else:
                add_at(bs, bass_note(root, 1.6 * BEAT, .45), t2i(b, off))
                add_at(bs, bass_note(root + 7, .5 * BEAT, .4), t2i(b, off + 1 + SW))
        # 드럼
        add_at(dr, kick(.75), t2i(b, 0))
        add_at(dr, kick(.45), t2i(b, 2 + SW))
        if b % 4 == 3:
            add_at(dr, kick(.35), t2i(b, 3 + SW))
        for bt in (1, 3):
            add_at(dr, rim(.32), t2i(b, bt))
            add_at(dr, brush(.22, .3), t2i(b, bt))
        for bt in range(4):
            add_at(ht, hat(.20 if bt % 2 else .14), t2i(b, bt))
            add_at(ht, hat(.10), t2i(b, bt + SW))
        for (bt, m, d) in MEL.get(b, []):
            add_at(ma, marimba(m, d, .42), t2i(b, bt))
    # 스테레오 배치
    pan = lambda x, p: np.stack([x * np.cos((p + 1) * np.pi / 4), x * np.sin((p + 1) * np.pi / 4)], 1)
    trem = 1 + 0.12 * np.sin(2 * np.pi * (BPM / 60 * 1.5) * np.arange(LOOP) / SR)
    L += pan(ep * trem, -0.2)
    L += pan(ma, 0.3) + pan(bs, 0) + pan(dr, 0) + pan(ht, 0.35)
    L = creverb(L, wet=0.22)
    L = band(L, 30, 11000)
    # 부드러운 컴프레서 대용 (tanh)
    L = np.tanh(norm(L, 1.0) * 1.4) / np.tanh(1.4)
    save("bgm", norm(L, 0.9))


# =====================================================================
# 주방 기기 루프 (원형 생성이라 루프 이음매 없음)
# =====================================================================
def loop_events(sec, rate, maker, seed):
    r = np.random.default_rng(seed)
    n = int(sec * SR)
    buf = np.zeros(n)
    t = 0.0
    while t < sec:
        t += r.exponential(1 / rate)
        add_at(buf, maker(r), int(t * SR) % n)
    return buf


def crackle(r):
    m = int(r.uniform(0.002, 0.008) * SR)
    x = r.standard_normal(m) * np.exp(-np.arange(m) / (m / 4))
    return x * r.uniform(0.2, 1.0) ** 2


def bubble(r, lo=180, hi=520):
    d = r.uniform(0.02, 0.06)
    m = int(d * SR)
    t = np.arange(m) / SR
    f0 = r.uniform(lo, hi)
    f = f0 * (1 + 1.6 * t / d)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) ** 0.7
    return x * r.uniform(0.3, 1.0)


def slow_lfo(n, seed, depth=0.3, rate=0.6):
    r = np.random.default_rng(seed)
    k = np.zeros(n // 2 + 1, complex)
    f = np.fft.rfftfreq(n, 1 / SR)
    sel = (f > 0) & (f < rate)
    k[sel] = r.standard_normal(sel.sum()) + 1j * r.standard_normal(sel.sum())
    x = np.fft.irfft(k, n)
    return 1 + depth * x / (np.max(np.abs(x)) + 1e-9)


def make_loops():
    n = 4 * SR
    # 지글지글 (굽기/볶기)
    hiss = norm(band(noise(n), 3000, 12000)) * 0.25
    cr = band(loop_events(4, 260, crackle, 1), 1500, 0)
    save("sizzle", norm((hiss + norm(cr) * 0.8) * slow_lfo(n, 2, 0.25)))
    # 튀김: 더 굵은 기름 소리
    roar = norm(band(noise(n), 400, 5000)) * 0.35
    cr2 = band(loop_events(4, 520, crackle, 3), 800, 0)
    bb = loop_events(4, 40, lambda r: bubble(r, 300, 700), 4)
    save("fryer", norm((roar + norm(cr2) + norm(bb) * 0.3) * slow_lfo(n, 5, 0.2)))
    # 보글보글 (끓이기)
    bb = loop_events(4, 26, bubble, 6)
    rum = norm(band(noise(n), 60, 600)) * 0.25
    save("boil", norm(norm(band(bb, 120, 3000)) + rum))
    # 찜기 김
    save("steam", norm(norm(band(noise(n), 2500, 8000)) * slow_lfo(n, 8, 0.35, 1.2) + norm(loop_events(4, 6, lambda r: bubble(r, 150, 300), 9)) * 0.25))
    # 가스 불꽃 (예열 중)
    save("flame", norm(band(noise(n), 80, 900) * slow_lfo(n, 10, 0.2, 2.0)))
    # 오븐: 팬 + 낮은 웅웅
    t = np.arange(n) / SR
    hum = np.sin(2 * np.pi * 60 * t) * 0.5 + np.sin(2 * np.pi * 120 * t) * 0.35 + np.sin(2 * np.pi * 180 * t) * 0.1
    fan = norm(band(noise(n), 150, 1800)) * 0.5
    save("oven", norm(hum * 0.6 + fan))
    # 전자레인지: 120Hz 윙 + 고음
    buzz = sum(np.sin(2 * np.pi * 120 * k * t) / k ** 1.3 for k in range(1, 12))
    save("micro", norm(buzz * 0.6 + norm(band(noise(n), 300, 3000)) * 0.35))
    # 블렌더: 모터 + 갈리는 소리
    f = 190 * (1 + 0.015 * np.sin(2 * np.pi * 7 * t))  # 4초에 정수 주기
    ph = 2 * np.pi * np.cumsum(f) / SR
    ph *= (2 * np.pi * round(ph[-1] / (2 * np.pi))) / ph[-1]
    mot = sum(np.sin(k * ph) / k for k in range(1, 18))
    grind = norm(band(noise(n), 800, 7000)) * slow_lfo(n, 11, 0.5, 6)
    save("blender", norm(band(mot, 0, 4000) * 0.7 + grind * 0.45))


# =====================================================================
# 한 번 재생 효과음
# =====================================================================
def make_oneshots():
    # 칼질: 도마 위 3번 탁탁탁
    n = int(0.62 * SR)
    x = np.zeros(n)
    for i, (tt, v) in enumerate([(0.0, 1.0), (0.17, 0.85), (0.34, 0.95)]):
        m = int(0.14 * SR)
        t = np.arange(m) / SR
        wood = np.sin(2 * np.pi * (210 + 15 * i) * t) * np.exp(-t / 0.035) + 0.5 * np.sin(2 * np.pi * 820 * t) * np.exp(-t / 0.018)
        clk = norm(band(noise(m), 2500, 9000)) * np.exp(-t / 0.006) * 0.7
        add_at(x, (wood + clk) * v * np.minimum(1, t / 0.0008), int(tt * SR), wrap=False)
    save("chop", norm(x))
    # 완료 알림: 주방 타이머 벨
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    bell = np.zeros(n)
    for k, (r_, a, d) in enumerate([(1, 1, .9), (2.76, .45, .35), (5.4, .25, .15), (8.9, .12, .06)]):
        bell += a * np.sin(2 * np.pi * 1320 * r_ * t) * np.exp(-t / d)
    bell *= np.minimum(1, t / 0.001)
    save("ding", norm(creverb(bell[:, None], 1.0, 0.25, 0.15)[:, 0], 0.8))
    # 물 씻기
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    w = norm(band(noise(n), 500, 6000)) * slow_lfo(n, 12, 0.6, 18)
    w += norm(loop_events(1.1, 30, lambda r: bubble(r, 600, 1400), 13)) * 0.5
    w *= np.minimum(1, t / 0.08) * np.minimum(1, (1.1 - t) / 0.25)
    save("water", norm(w, 0.7))
    # 문 여닫기 (오븐/전자레인지/냉동고)
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    d = np.sin(2 * np.pi * 95 * t) * np.exp(-t / 0.05) + norm(band(noise(n), 300, 3000)) * np.exp(-t / 0.015) * 0.6
    save("door", norm(d))
    # 접시 담기: 도자기 딸깍
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    c = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / dd) for f, a, dd in [(2150, 1, .12), (3420, .6, .07), (5100, .35, .04)])
    c += norm(band(noise(n), 3000, 10000)) * np.exp(-t / 0.004) * 0.5
    save("plate", norm(c, 0.6))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_bgm()
    make_loops()
    make_oneshots()
    print("ok", sorted(os.listdir(OUT)))
