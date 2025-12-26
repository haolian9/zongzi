#!/usr/bin/env python3

# ref: https://zh.wikipedia.org/wiki/%E8%87%AA%E7%84%B6%E7%A0%81

# todo: support multi-byte rune
shengdiao_trans = str.maketrans(
    {
        "ā": "a",
        "á": "a",
        "ǎ": "a",
        "à": "a",
        "ē": "e",
        "é": "e",
        "ě": "e",
        "è": "e",
        "ō": "o",
        "ó": "o",
        "ǒ": "o",
        "ò": "o",
        "ī": "i",
        "í": "i",
        "ǐ": "i",
        "ì": "i",
        "ū": "u",
        "ú": "u",
        "ǔ": "u",
        "ù": "u",
        # üe
        "ü": "v",
        "ǖ": "v",
        "ǘ": "v",
        "ǚ": "v",
        "ǜ": "v",
        "ń": "n",
        "ň": "n",
        "ǹ": "n",
    }
)

shengmu_map = {
    2: {
        "ch": "i",
        "sh": "u",
        "zh": "v",
    },
    1: {
        "b": "b",
        "c": "c",
        "d": "d",
        "f": "f",
        "g": "g",
        "h": "h",
        "j": "j",
        "k": "k",
        "l": "l",
        "m": "m",
        "n": "n",
        "p": "p",
        "q": "q",
        "r": "r",
        "s": "s",
        "t": "t",
        "w": "w",
        "x": "x",
        "y": "y",
        "z": "z",
    },
}

yunmu_map = {
    1: {
        "a": "a",
        "e": "e",
        "i": "i",
        "in": "n",
        "o": "o",
        "u": "u",
        "v": "v",
    },
    2: {
        "ou": "b",
        "en": "f",
        "an": "j",
        "ao": "k",
        "ai": "l",
        "in": "n",
        "uo": "o",
        "un": "p",
        "iu": "q",
        "ue": "t",
        "ve": "t",
        "ui": "v",
        "ia": "w",
        "ua": "w",
        "ie": "x",
        "ei": "z",
    },
    3: {
        "iao": "c",
        "eng": "g",
        "ang": "h",
        "ian": "m",
        "uan": "r",
        "ong": "s",
        "ing": "y",
        "uai": "y",
    },
    4: {
        "iang": "d",
        "uang": "d",
        "iong": "s",
    },
}


def to_ziranma_shuangpin(pinyin):

    if len(pinyin) == 1:
        return pinyin * 2
    if len(pinyin) == 2:
        return pinyin
    # todo: an -> an, aj
    if pinyin == "ang":
        return "ah"
    if pinyin == "eng":
        return "eg"

    sheng = pinyin[:2]
    if sheng in shengmu_map[2]:
        a = shengmu_map[2][sheng]
        yun = pinyin[2:]
        b = yunmu_map[len(yun)][yun]
        return a + b

    sheng = pinyin[:1]
    a = shengmu_map[1][sheng]
    yun = pinyin[1:]
    b = yunmu_map[len(yun)][yun]
    return a + b


def is_valid_pinyin(pinyin: str) -> bool:
    # 多字节音调不能用于str.maketrans
    for diao in {"m̄", "ḿ", "m̀", "ê̄", "ế", "ê̌", "ề"}:
        if diao in pinyin:
            return False

    # 不被支持的拼音
    if pinyin == "hng":
        return False

    return True


def parse_line(line: str):
    def parse_multiple_pinyin(pinyin):
        for pin in pinyin.split(","):
            if not is_valid_pinyin(pin):
                continue

            yield pin.translate(shengdiao_trans)

    # len('㑇\n') == 2
    rune: str = line[-2:-1]

    start = line.find(":")
    if start == -1:
        raise ValueError(f"invalid line format [{line}]")
    start += len(":")
    # len('  # 㑇\n') == 6
    pinyin: str = line[start:-6]
    pinyin = pinyin.strip()

    for pin in set(parse_multiple_pinyin(pinyin)):
        try:
            shuang = to_ziranma_shuangpin(pin)
        except KeyError as e:
            raise RuntimeError(f"convertError: [{rune}] [{pin}]") from e
        else:
            assert len(shuang) == 2

        yield pin, shuang, rune


def main():
    # see: https://github.com/mozillazg/pinyin-data/blob/v0.15.0/pinyin.txt
    data = "pinyin.txt"

    with open(data, "r") as infp, open("shuangpin.data", "w") as shuang_fp:
        for line in infp:
            if line.startswith("#"):
                continue
            if line == "\n":
                continue
            for _, shuang, rune in parse_line(line):
                shuang_fp.write(f"{shuang} {rune}\n")


if __name__ == "__main__":
    main()
