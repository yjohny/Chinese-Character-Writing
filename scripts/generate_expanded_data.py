#!/usr/bin/env python3
"""
Generate expanded characters.json and strokes.json for the Chinese Character Writing app.

Expands character coverage from ~494 to ~2,500 characters, covering the full
Chinese national curriculum for grades 1-6.

Data sources:
- Make Me a Hanzi dictionary.txt: Character pinyin (tone-marked) and definitions
- Make Me a Hanzi graphics.txt: Stroke SVG paths and median centerlines
- CC-CEDICT (via npm cc-cedict): Traditional forms and compound words
- hanziDB.csv: Character frequency rankings
- Existing characters.json/strokes.json: Preserved as-is

Usage:
    cd scripts/
    python3 generate_expanded_data.py
"""

import json
import csv
import re
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
RESOURCES_DIR = os.path.join(SCRIPT_DIR, "..", "ChineseWriting", "Resources")

# Target character counts per grade (based on 部编版 curriculum)
GRADE_TARGETS = {
    1: 300,
    2: 500,
    3: 500,
    4: 400,
    5: 400,
    6: 400,
}
TOTAL_TARGET = sum(GRADE_TARGETS.values())  # 2500


def numbered_pinyin_to_tone_marked(pinyin_str):
    """Convert numbered pinyin (e.g., 'yi1') to tone-marked pinyin (e.g., 'yī')."""
    tone_marks = {
        'a': ['ā', 'á', 'ǎ', 'à', 'a'],
        'e': ['ē', 'é', 'ě', 'è', 'e'],
        'i': ['ī', 'í', 'ǐ', 'ì', 'i'],
        'o': ['ō', 'ó', 'ǒ', 'ò', 'o'],
        'u': ['ū', 'ú', 'ǔ', 'ù', 'u'],
        'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ', 'ü'],
        'v': ['ǖ', 'ǘ', 'ǚ', 'ǜ', 'ü'],
    }

    def convert_syllable(syllable):
        syllable = syllable.strip()
        if not syllable:
            return syllable

        # Extract tone number
        tone = 5  # neutral
        if syllable and syllable[-1] in '12345':
            tone = int(syllable[-1])
            syllable = syllable[:-1]

        if tone == 5:
            return syllable.replace('v', 'ü').replace('V', 'Ü')

        # Replace v/V with ü/Ü
        syllable_lower = syllable.lower()

        # Find where to place the tone mark (standard rules)
        # 1. If there's an 'a' or 'e', it gets the tone mark
        # 2. If there's 'ou', the 'o' gets the tone mark
        # 3. Otherwise, the last vowel gets the tone mark
        vowels = 'aeiouüv'
        tone_idx = -1

        for i, ch in enumerate(syllable_lower):
            if ch in ('a', 'e'):
                tone_idx = i
                break
        if tone_idx == -1:
            # Check for 'ou'
            ou_pos = syllable_lower.find('ou')
            if ou_pos != -1:
                tone_idx = ou_pos
            else:
                # Last vowel
                for i in range(len(syllable_lower) - 1, -1, -1):
                    if syllable_lower[i] in vowels:
                        tone_idx = i
                        break

        if tone_idx == -1:
            return syllable.replace('v', 'ü').replace('V', 'Ü')

        result = list(syllable)
        ch_lower = syllable_lower[tone_idx]
        if ch_lower in tone_marks:
            replacement = tone_marks[ch_lower][tone - 1]
            if result[tone_idx].isupper():
                replacement = replacement.upper()
            result[tone_idx] = replacement
        else:
            result[tone_idx] = syllable[tone_idx]

        return ''.join(result).replace('v', 'ü').replace('V', 'Ü')

    # Split on spaces, convert each syllable
    parts = pinyin_str.split()
    converted = []
    for part in parts:
        # Handle special characters like commas, etc.
        if not any(c.isalpha() for c in part):
            converted.append(part)
        else:
            converted.append(convert_syllable(part))
    return ' '.join(converted)


def load_mmah_dictionary():
    """Load Make Me a Hanzi dictionary.txt → {char: {pinyin, definition}}"""
    path = os.path.join(DATA_DIR, "dictionary.txt")
    result = {}
    with open(path) as f:
        for line in f:
            entry = json.loads(line)
            ch = entry["character"]
            pinyin_list = entry.get("pinyin", [])
            definition = entry.get("definition", "")
            result[ch] = {
                "pinyin": pinyin_list[0] if pinyin_list else "",
                "definition": definition,
            }
    return result


def load_mmah_graphics():
    """Load Make Me a Hanzi graphics.txt → {char: {strokes, medians}}"""
    path = os.path.join(DATA_DIR, "graphics.txt")
    result = {}
    with open(path) as f:
        for line in f:
            entry = json.loads(line)
            ch = entry["character"]
            result[ch] = {
                "character": ch,
                "strokes": entry.get("strokes", []),
                "medians": entry.get("medians", []),
            }
    return result


def load_cedict():
    """Load CC-CEDICT data → character_info dict and word lookup.

    Returns:
        char_info: {simplified: {traditional, pinyin, definition}}
        word_index: {simplified_char: [(word_simplified, word_traditional, pinyin, definition)]}
    """
    path = os.path.join(DATA_DIR, "package", "data", "all.js")
    with open(path) as f:
        content = f.read()

    json_str = content[len("export default "):]
    if json_str.rstrip().endswith(';'):
        json_str = json_str.rstrip()[:-1]

    data = json.loads(json_str)
    entries = data["all"]

    char_info = {}
    word_index = {}

    for entry in entries:
        traditional = entry[0]
        simplified = entry[1]
        pinyin_numbered = entry[2]
        definition = entry[3]

        # Handle definition being a list
        if isinstance(definition, list):
            definition = "; ".join(definition)

        # Single character entries → char_info
        if len(simplified) == 1:
            if simplified not in char_info:
                char_info[simplified] = {
                    "traditional": traditional,
                    "pinyin_numbered": pinyin_numbered,
                    "pinyin": numbered_pinyin_to_tone_marked(pinyin_numbered),
                    "definition": definition,
                }

        # Two-character words → word_index
        if len(simplified) == 2:
            word_entry = (simplified, traditional, pinyin_numbered, definition)
            for ch in simplified:
                if ch not in word_index:
                    word_index[ch] = []
                word_index[ch].append(word_entry)

    return char_info, word_index


def load_hanzidb():
    """Load hanziDB.csv → {char: {frequency_rank, pinyin, definition, stroke_count}}"""
    path = os.path.join(DATA_DIR, "hanziDB.csv")
    result = {}
    with open(path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ch = row['character']
            try:
                rank = int(row['frequency_rank'])
            except ValueError:
                continue
            result[ch] = {
                "frequency_rank": rank,
                "pinyin": row.get('pinyin', ''),
                "definition": row.get('definition', ''),
                "stroke_count": int(row.get('stroke_count', '0').split()[0] or 0),
            }
    return result


def load_existing_characters():
    """Load existing characters.json."""
    path = os.path.join(RESOURCES_DIR, "characters.json")
    with open(path) as f:
        return json.load(f)


def load_existing_strokes():
    """Load existing strokes.json."""
    path = os.path.join(RESOURCES_DIR, "strokes.json")
    with open(path) as f:
        return json.load(f)


# Curated example words for common characters where automated selection fails.
# Format: simplified_char → (word_simplified, word_traditional)
# These are everyday words suitable for a children's learning app.
CURATED_EXAMPLES = {
    "中": ("中国", "中國"), "能": ("能力", "能力"), "而": ("而且", "而且"),
    "得": ("得到", "得到"), "于": ("对于", "對於"), "自": ("自己", "自己"),
    "年": ("新年", "新年"), "发": ("发现", "發現"), "后": ("后来", "後來"),
    "作": ("工作", "工作"), "道": ("知道", "知道"), "所": ("所以", "所以"),
    "然": ("自然", "自然"), "事": ("事情", "事情"), "经": ("已经", "已經"),
    "法": ("办法", "辦法"), "如": ("如果", "如果"), "同": ("同学", "同學"),
    "去": ("过去", "過去"), "学": ("学习", "學習"), "最": ("最后", "最後"),
    "成": ("成功", "成功"), "理": ("道理", "道理"), "全": ("完全", "完全"),
    "部": ("全部", "全部"), "特": ("特别", "特別"), "重": ("重要", "重要"),
    "并": ("并且", "並且"), "意": ("注意", "注意"), "第": ("第一", "第一"),
    "此": ("因此", "因此"), "进": ("进行", "進行"), "使": ("使用", "使用"),
    "定": ("一定", "一定"), "以": ("可以", "可以"), "已": ("已经", "已經"),
    "反": ("反对", "反對"), "由": ("自由", "自由"), "向": ("方向", "方向"),
    "性": ("性格", "性格"), "度": ("温度", "溫度"), "等": ("等待", "等待"),
    "被": ("被子", "被子"), "种": ("种子", "種子"), "关": ("关系", "關係"),
    "点": ("一点", "一點"), "身": ("身体", "身體"), "接": ("接受", "接受"),
    "再": ("再见", "再見"), "表": ("表示", "表示"), "情": ("感情", "感情"),
    "电": ("电话", "電話"), "相": ("互相", "互相"), "应": ("应该", "應該"),
    "想": ("想要", "想要"), "间": ("时间", "時間"), "系": ("关系", "關係"),
    "路": ("走路", "走路"), "带": ("带来", "帶來"), "机": ("飞机", "飛機"),
    "很": ("很多", "很多"), "打": ("打开", "打開"), "通": ("交通", "交通"),
    "放": ("放心", "放心"), "该": ("应该", "應該"), "数": ("数学", "數學"),
    "现": ("现在", "現在"), "些": ("一些", "一些"), "话": ("说话", "說話"),
    "外": ("外面", "外面"), "才": ("刚才", "剛才"), "提": ("提高", "提高"),
    "原": ("原来", "原來"), "走": ("走路", "走路"), "别": ("特别", "特別"),
    "处": ("到处", "到處"), "着": ("看着", "看著"), "动": ("活动", "活動"),
    "常": ("经常", "經常"), "活": ("生活", "生活"), "记": ("记住", "記住"),
    "新": ("新年", "新年"), "次": ("一次", "一次"), "手": ("双手", "雙手"),
    "直": ("一直", "一直"), "只": ("只有", "只有"), "期": ("星期", "星期"),
    "场": ("广场", "廣場"), "报": ("报纸", "報紙"), "总": ("总是", "總是"),
    "且": ("而且", "而且"), "必": ("必须", "必須"), "回": ("回家", "回家"),
    "公": ("公园", "公園"), "实": ("实在", "實在"), "先": ("先生", "先生"),
    "老": ("老师", "老師"), "像": ("好像", "好像"), "气": ("天气", "天氣"),
    "题": ("问题", "問題"), "条": ("条件", "條件"), "视": ("电视", "電視"),
    "快": ("快乐", "快樂"), "许": ("也许", "也許"), "觉": ("感觉", "感覺"),
    "市": ("城市", "城市"), "血": ("血液", "血液"), "毒": ("中毒", "中毒"),
    "贫": ("贫困", "貧困"), "玻": ("玻璃", "玻璃"), "括": ("包括", "包括"),
    "任": ("任务", "任務"), "认": ("认识", "認識"), "位": ("座位", "座位"),
    "持": ("坚持", "堅持"), "影": ("电影", "電影"), "际": ("国际", "國際"),
    "命": ("生命", "生命"), "争": ("战争", "戰爭"), "治": ("政治", "政治"),
    "示": ("表示", "表示"), "容": ("容易", "容易"), "务": ("任务", "任務"),
    "管": ("管理", "管理"), "音": ("声音", "聲音"), "求": ("要求", "要求"),
    "领": ("领导", "領導"), "科": ("科学", "科學"), "验": ("经验", "經驗"),
    "切": ("一切", "一切"), "统": ("传统", "傳統"), "足": ("满足", "滿足"),
    "深": ("深入", "深入"), "断": ("判断", "判斷"), "根": ("根本", "根本"),
    "众": ("群众", "群眾"), "选": ("选择", "選擇"), "达": ("到达", "到達"),
    "备": ("准备", "準備"), "整": ("整个", "整個"), "且": ("而且", "而且"),
    "究": ("研究", "研究"), "品": ("产品", "產品"), "确": ("确实", "確實"),
    "极": ("积极", "積極"), "调": ("调查", "調查"), "单": ("简单", "簡單"),
    "据": ("根据", "根據"), "难": ("困难", "困難"), "装": ("安装", "安裝"),
    "存": ("存在", "存在"), "落": ("落后", "落後"), "致": ("导致", "導致"),
    "形": ("形成", "形成"), "谈": ("谈话", "談話"), "构": ("结构", "結構"),
    "济": ("经济", "經濟"), "势": ("形势", "形勢"), "环": ("环境", "環境"),
    "组": ("组织", "組織"), "限": ("有限", "有限"), "严": ("严格", "嚴格"),
    "农": ("农民", "農民"), "古": ("古代", "古代"), "练": ("练习", "練習"),
    "功": ("成功", "成功"), "响": ("影响", "影響"), "低": ("降低", "降低"),
    "差": ("差别", "差別"), "感": ("感觉", "感覺"), "却": ("忘却", "忘卻"),
    "死": ("死亡", "死亡"), "正": ("正在", "正在"), "把": ("把握", "把握"),
    "过": ("经过", "經過"), "还": ("还是", "還是"), "无": ("无论", "無論"),
    "当": ("当时", "當時"), "产": ("生产", "生產"), "民": ("人民", "人民"),
    "力": ("努力", "努力"), "对": ("对面", "對面"), "内": ("国内", "國內"),
    "加": ("增加", "增加"), "化": ("变化", "變化"), "合": ("合作", "合作"),
    "解": ("理解", "理解"), "制": ("制度", "制度"), "强": ("强大", "強大"),
    "战": ("战争", "戰爭"), "高": ("提高", "提高"), "区": ("地区", "地區"),
    "长": ("长大", "長大"), "安": ("安全", "安全"), "开": ("打开", "打開"),
    "各": ("各种", "各種"), "白": ("明白", "明白"), "近": ("附近", "附近"),
    "保": ("保护", "保護"), "改": ("改变", "改變"), "计": ("计划", "計劃"),
    "半": ("一半", "一半"), "听": ("好听", "好聽"), "张": ("紧张", "緊張"),
    "非": ("非常", "非常"), "准": ("准备", "準備"), "今": ("今天", "今天"),
    "百": ("百分", "百分"), "元": ("单元", "單元"), "连": ("连接", "連接"),
    "乳": ("牛乳", "牛乳"),
}


def find_best_example_word(char, word_index, cedict_chars, hanzidb):
    """Find the best example word for a character from CC-CEDICT.

    Prefers:
    1. Common words (both characters are high-frequency)
    2. Child-appropriate content
    3. Shorter, more concrete definitions
    4. Words where the character is the first character
    """
    candidates = word_index.get(char, [])
    if not candidates:
        return None

    # Words/topics inappropriate for a children's app
    BLOCKED_WORDS = {
        "妓", "娼", "淫", "色情", "赌", "奸",
        "屎", "粪",
    }
    BLOCKED_DEFS = {
        "penis", "vagina", "sex ", "sexual", "erotic", "prostitut",
        "nude", "naked", "obscen", "vulgar", "profan",
        "excrement", "feces",
        "fuck", "shit",
    }

    def is_appropriate(entry):
        word_simplified, _, _, definition = entry
        # Check word itself
        for blocked in BLOCKED_WORDS:
            if blocked in word_simplified and blocked != char:
                return False
        # Check definition
        def_lower = definition.lower() if isinstance(definition, str) else str(definition).lower()
        for blocked in BLOCKED_DEFS:
            if blocked in def_lower:
                return False
        return True

    def word_score(entry):
        word_simplified, word_traditional, pinyin, definition = entry
        score = 0

        if isinstance(definition, list):
            definition = "; ".join(definition)
        def_lower = definition.lower()

        # Primary signal: prefer words where the OTHER character is very common.
        other_char = word_simplified[1] if word_simplified[0] == char else word_simplified[0]
        if other_char in hanzidb:
            other_rank = hanzidb[other_char]["frequency_rank"]
            # Inverse rank: lower rank (more common) = higher score
            score += max(0, 100 - other_rank // 25)

        # Small bonus for words where character is first
        if word_simplified[0] == char:
            score += 3

        # Penalize literary, archaic, dialectal, slang terms
        for marker in ["(literary)", "(archaic)", "(dialect)", "(old)",
                        "(euphemism)", "(classical)", "(formal)", "old variant",
                        "old name for", "variant of", "abbr. for", "surname"]:
            if marker in def_lower:
                score -= 40

        # Mild penalty for proper nouns
        if any(p[0].isupper() for p in pinyin.split() if p and p[0].isalpha()):
            score -= 8

        # Mild penalty for long definitions (usually obscure)
        if len(definition) > 80:
            score -= 5

        return score

    # Filter for appropriate content first
    appropriate = [c for c in candidates if is_appropriate(c)]
    if not appropriate:
        appropriate = candidates  # Fall back if all filtered

    appropriate.sort(key=word_score, reverse=True)
    return appropriate[0]


def make_tts_text(char, word):
    """Generate TTS text in the format: '游，旅游的游'"""
    return f"{char}，{word}的{char}"


def generate_characters_json(existing_chars, mmah_dict, cedict_chars, cedict_words,
                              hanzidb, mmah_graphics):
    """Generate the expanded characters.json data."""
    # Index existing characters
    existing_by_char = {c["simplified"]: c for c in existing_chars}
    existing_set = set(existing_by_char.keys())

    # Count existing per grade
    existing_per_grade = {}
    for c in existing_chars:
        g = c["gradeLevel"]
        existing_per_grade[g] = existing_per_grade.get(g, 0) + 1

    print(f"\nExisting characters per grade:")
    for g in sorted(existing_per_grade):
        print(f"  Grade {g}: {existing_per_grade[g]}")

    # Find characters to add: top TOTAL_TARGET by frequency, minus existing
    freq_sorted = sorted(hanzidb.items(), key=lambda x: x[1]["frequency_rank"])
    candidates = []
    for ch, info in freq_sorted:
        if ch in existing_set:
            continue
        # Only include characters that have stroke data (can actually be practiced)
        if ch not in mmah_graphics:
            continue
        # Only include characters that have definitions
        if ch not in mmah_dict and ch not in cedict_chars:
            continue
        candidates.append((ch, info["frequency_rank"]))
        if len(candidates) + len(existing_set) >= TOTAL_TARGET:
            break

    print(f"\nNew characters to add: {len(candidates)}")

    # Assign grades to new characters based on frequency
    # Fill each grade up to its target, in frequency order
    grade_slots = {}
    for g in range(1, 7):
        needed = GRADE_TARGETS[g] - existing_per_grade.get(g, 0)
        grade_slots[g] = max(0, needed)

    print(f"\nSlots to fill per grade:")
    for g in sorted(grade_slots):
        print(f"  Grade {g}: {grade_slots[g]} new characters needed")

    new_chars_by_grade = {g: [] for g in range(1, 7)}
    candidate_idx = 0
    for grade in range(1, 7):
        slots = grade_slots[grade]
        for _ in range(slots):
            if candidate_idx >= len(candidates):
                break
            ch, freq_rank = candidates[candidate_idx]
            new_chars_by_grade[grade].append(ch)
            candidate_idx += 1

    # Any remaining candidates go into grade 6
    while candidate_idx < len(candidates):
        ch, _ = candidates[candidate_idx]
        new_chars_by_grade[6].append(ch)
        candidate_idx += 1

    # Generate entries for new characters
    all_chars = list(existing_chars)  # Preserve existing entries exactly

    for grade in range(1, 7):
        # Find the max orderInGrade already used in this grade
        existing_orders = [c["orderInGrade"] for c in existing_chars if c["gradeLevel"] == grade]
        start_order = max(existing_orders) + 1 if existing_orders else 0
        for i, ch in enumerate(new_chars_by_grade[grade]):
            entry = generate_char_entry(
                ch, grade, start_order + i,
                mmah_dict, cedict_chars, cedict_words, hanzidb
            )
            if entry:
                all_chars.append(entry)

    # Sort by grade, then orderInGrade, then re-number to be contiguous
    all_chars.sort(key=lambda c: (c["gradeLevel"], c["orderInGrade"]))
    for grade in range(1, 7):
        idx = 0
        for c in all_chars:
            if c["gradeLevel"] == grade:
                c["orderInGrade"] = idx
                idx += 1

    # Clean up example word meanings — remove inappropriate secondary meanings
    for c in all_chars:
        for ew in c.get("exampleWords", []):
            meaning = ew.get("meaning", "")
            # Remove secondary meanings after semicolons that contain inappropriate content
            clean_markers = ["(slang)", "(vulgar)", "(derog)", "(offensive)"]
            if any(m in meaning.lower() for m in clean_markers):
                parts = re.split(r'[;；]', meaning)
                clean_parts = [p for p in parts
                               if not any(m in p.lower() for m in clean_markers)]
                if clean_parts:
                    ew["meaning"] = "; ".join(clean_parts).strip()
                else:
                    ew["meaning"] = parts[0].strip()  # Keep first even if marked

    return all_chars


def generate_char_entry(char, grade, order, mmah_dict, cedict_chars, cedict_words, hanzidb):
    """Generate a single character entry."""
    # Get pinyin (prefer MMAH tone-marked, fall back to hanziDB, then CC-CEDICT)
    pinyin = ""
    if char in mmah_dict and mmah_dict[char]["pinyin"]:
        pinyin = mmah_dict[char]["pinyin"]
    elif char in hanzidb and hanzidb[char]["pinyin"]:
        pinyin = hanzidb[char]["pinyin"]
    elif char in cedict_chars:
        pinyin = cedict_chars[char]["pinyin"]

    if not pinyin:
        print(f"  WARNING: No pinyin for '{char}', skipping")
        return None

    # Get definition (prefer MMAH, fall back to hanziDB, then CC-CEDICT)
    meaning = ""
    if char in mmah_dict and mmah_dict[char]["definition"]:
        meaning = mmah_dict[char]["definition"]
    elif char in hanzidb and hanzidb[char]["definition"]:
        meaning = hanzidb[char]["definition"]
    elif char in cedict_chars:
        meaning = cedict_chars[char]["definition"]

    if not meaning:
        print(f"  WARNING: No definition for '{char}', skipping")
        return None

    # Clean up meaning - truncate very long definitions
    if len(meaning) > 80:
        # Take first few senses
        parts = re.split(r'[;；]', meaning)
        meaning = "; ".join(parts[:3]).strip()
        if len(meaning) > 80:
            meaning = meaning[:77] + "..."

    # Get traditional form (from CC-CEDICT, default to simplified)
    traditional = char
    if char in cedict_chars:
        traditional = cedict_chars[char]["traditional"]

    # Find example word — try curated override first, then automated
    example_words = []

    if char in CURATED_EXAMPLES:
        curated_word, curated_trad = CURATED_EXAMPLES[char]
        # Look up this word in CC-CEDICT for pinyin and meaning
        cedict_entry = None
        for entry in cedict_words.get(char, []):
            if entry[0] == curated_word:
                cedict_entry = entry
                break
        if cedict_entry:
            _, _, word_pinyin_num, word_meaning = cedict_entry
            word_pinyin = numbered_pinyin_to_tone_marked(word_pinyin_num)
            if isinstance(word_meaning, list):
                word_meaning = "; ".join(word_meaning)
            if len(word_meaning) > 60:
                parts = re.split(r'[;；]', word_meaning)
                word_meaning = parts[0].strip()
        else:
            # Fallback pinyin/meaning for curated words not in cedict
            word_pinyin = pinyin
            word_meaning = meaning.split(";")[0].strip() if ";" in meaning else meaning

        example_words.append({
            "word": curated_word,
            "wordTraditional": curated_trad,
            "pinyin": word_pinyin,
            "meaning": word_meaning,
            "ttsText": make_tts_text(char, curated_word),
        })
    else:
        example_word = find_best_example_word(char, cedict_words, cedict_chars, hanzidb)
        if example_word:
            word_simplified, word_traditional, word_pinyin_num, word_meaning = example_word
            word_pinyin = numbered_pinyin_to_tone_marked(word_pinyin_num)

            # Clean up word meaning
            if isinstance(word_meaning, list):
                word_meaning = "; ".join(word_meaning)
            if len(word_meaning) > 60:
                parts = re.split(r'[;；]', word_meaning)
                word_meaning = parts[0].strip()

            example_words.append({
                "word": word_simplified,
                "wordTraditional": word_traditional,
                "pinyin": word_pinyin,
                "meaning": word_meaning,
                "ttsText": make_tts_text(char, word_simplified),
            })
        else:
            # Fallback: use the character itself with its definition
            example_words.append({
                "word": char,
                "wordTraditional": traditional,
                "pinyin": pinyin,
                "meaning": meaning.split(";")[0].strip() if ";" in meaning else meaning,
                "ttsText": f"{char}",
            })

    return {
        "simplified": char,
        "traditional": traditional,
        "pinyin": pinyin,
        "meaning": meaning,
        "gradeLevel": grade,
        "orderInGrade": order,
        "exampleWords": example_words,
    }


def generate_strokes_json(all_chars, existing_strokes, mmah_graphics):
    """Generate the expanded strokes.json with coverage for all characters."""
    result = dict(existing_strokes)  # Preserve existing entries

    new_count = 0
    for char_entry in all_chars:
        ch = char_entry["simplified"]
        if ch in result:
            continue  # Already have stroke data
        if ch in mmah_graphics:
            result[ch] = mmah_graphics[ch]
            new_count += 1

    return result, new_count


def main():
    print("=" * 60)
    print("Chinese Character Data Expansion Script")
    print("=" * 60)

    # Load all data sources
    print("\n[1/6] Loading Make Me a Hanzi dictionary...")
    mmah_dict = load_mmah_dictionary()
    print(f"  Loaded {len(mmah_dict)} character entries")

    print("\n[2/6] Loading Make Me a Hanzi graphics...")
    mmah_graphics = load_mmah_graphics()
    print(f"  Loaded {len(mmah_graphics)} character stroke entries")

    print("\n[3/6] Loading CC-CEDICT...")
    cedict_chars, cedict_words = load_cedict()
    print(f"  Loaded {len(cedict_chars)} character definitions, "
          f"{sum(len(v) for v in cedict_words.values())} word entries")

    print("\n[4/6] Loading hanziDB frequency data...")
    hanzidb = load_hanzidb()
    print(f"  Loaded {len(hanzidb)} frequency-ranked characters")

    print("\n[5/6] Loading existing data...")
    existing_chars = load_existing_characters()
    existing_strokes = load_existing_strokes()
    print(f"  Existing characters.json: {len(existing_chars)} entries")
    print(f"  Existing strokes.json: {len(existing_strokes)} entries")

    # Generate expanded data
    print("\n[6/6] Generating expanded data...")
    all_chars = generate_characters_json(
        existing_chars, mmah_dict, cedict_chars, cedict_words,
        hanzidb, mmah_graphics
    )

    expanded_strokes, new_stroke_count = generate_strokes_json(
        all_chars, existing_strokes, mmah_graphics
    )

    # Write output
    print(f"\n{'=' * 60}")
    print(f"RESULTS")
    print(f"{'=' * 60}")

    chars_output = os.path.join(RESOURCES_DIR, "characters.json")
    with open(chars_output, "w", encoding="utf-8") as f:
        json.dump(all_chars, f, ensure_ascii=False, indent=2)
    print(f"\nWrote {len(all_chars)} characters to {chars_output}")

    # Print per-grade breakdown
    grade_counts = {}
    for c in all_chars:
        g = c["gradeLevel"]
        grade_counts[g] = grade_counts.get(g, 0) + 1
    for g in sorted(grade_counts):
        print(f"  Grade {g}: {grade_counts[g]} characters")

    strokes_output = os.path.join(RESOURCES_DIR, "strokes.json")
    with open(strokes_output, "w", encoding="utf-8") as f:
        json.dump(expanded_strokes, f, ensure_ascii=False)
    print(f"\nWrote {len(expanded_strokes)} stroke entries to {strokes_output}")
    print(f"  ({new_stroke_count} new entries added)")

    # Validation
    print(f"\n{'=' * 60}")
    print(f"VALIDATION")
    print(f"{'=' * 60}")

    chars_with_strokes = sum(1 for c in all_chars if c["simplified"] in expanded_strokes)
    chars_without_strokes = sum(1 for c in all_chars if c["simplified"] not in expanded_strokes)
    chars_with_examples = sum(1 for c in all_chars
                              if c["exampleWords"] and len(c["exampleWords"][0].get("word", "")) > 1)
    print(f"Characters with stroke data: {chars_with_strokes}/{len(all_chars)}")
    print(f"Characters WITHOUT stroke data: {chars_without_strokes}")
    print(f"Characters with compound word examples: {chars_with_examples}/{len(all_chars)}")

    # Check original characters preserved
    existing_set = {c["simplified"] for c in existing_chars}
    new_set = {c["simplified"] for c in all_chars}
    missing_originals = existing_set - new_set
    if missing_originals:
        print(f"WARNING: {len(missing_originals)} original characters missing!")
    else:
        print(f"All {len(existing_set)} original characters preserved ✓")


if __name__ == "__main__":
    main()
