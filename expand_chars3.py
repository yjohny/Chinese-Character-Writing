#!/usr/bin/env python3
"""Third expansion pass: fill remaining curriculum gaps."""
import json, os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHARS_PATH = os.path.join(SCRIPT_DIR, "ChineseWriting", "Resources", "characters.json")

# Grade 1-2: More essential characters for basic literacy
GRADE1_EXTRA = """
手|手|shǒu|hand|手工|手工|shǒu gōng|handcraft
足|足|zú|foot|满足|滿足|mǎn zú|satisfied
已|已|yǐ|already|已经|已經|yǐ jīng|already
哈|哈|hā|ha|哈哈|哈哈|hā hā|haha
太|太|tài|too much|太好|太好|tài hǎo|too good
"""

GRADE2_EXTRA = """
级|級|jí|level|年级|年級|nián jí|grade
班|班|bān|class|班级|班級|bān jí|class
考|考|kǎo|test|考试|考試|kǎo shì|exam
试|試|shì|try|尝试|嘗試|cháng shì|try
决|決|jué|decide|解决|解決|jiě jué|solve
增|增|zēng|increase|增加|增加|zēng jiā|increase
减|減|jiǎn|decrease|减少|減少|jiǎn shǎo|decrease
集|集|jí|collect|集中|集中|jí zhōng|concentrate
数|數|shù|count|数字|數字|shù zì|number
倍|倍|bèi|times|加倍|加倍|jiā bèi|double
持|持|chí|hold|坚持|堅持|jiān chí|persist
坚|堅|jiān|firm|坚强|堅強|jiān qiáng|strong
推|推|tuī|push|推动|推動|tuī dòng|promote
拉|拉|lā|pull|拉住|拉住|lā zhù|hold
抓|抓|zhuā|grab|抓住|抓住|zhuā zhù|grab
摸|摸|mō|touch|摸索|摸索|mō suǒ|grope
扔|扔|rēng|throw|扔掉|扔掉|rēng diào|throw away
盒|盒|hé|box|盒子|盒子|hé zi|box
碗|碗|wǎn|bowl|饭碗|飯碗|fàn wǎn|rice bowl
盘|盤|pán|plate|盘子|盤子|pán zi|plate
勺|勺|sháo|spoon|勺子|勺子|sháo zi|spoon
壶|壺|hú|pot|茶壶|茶壺|chá hú|teapot
瓶|瓶|píng|bottle|瓶子|瓶子|píng zi|bottle
扇|扇|shàn|fan|扇子|扇子|shàn zi|fan
伞|傘|sǎn|umbrella|雨伞|雨傘|yǔ sǎn|umbrella
绳|繩|shéng|rope|绳子|繩子|shéng zi|rope
针|針|zhēn|needle|打针|打針|dǎ zhēn|injection
线|線|xiàn|line|线条|線條|xiàn tiáo|line
布|布|bù|cloth|布料|布料|bù liào|fabric
棉|棉|mián|cotton|棉花|棉花|mián hua|cotton
麦|麥|mài|wheat|小麦|小麥|xiǎo mài|wheat
稻|稻|dào|rice plant|稻田|稻田|dào tián|rice paddy
松|松|sōng|pine|松树|松樹|sōng shù|pine tree
柏|柏|bǎi|cypress|松柏|松柏|sōng bǎi|pine and cypress
杨|楊|yáng|poplar|白杨|白楊|bái yáng|poplar
梧|梧|wú|parasol tree|梧桐|梧桐|wú tóng|parasol tree
桐|桐|tóng|paulownia|梧桐|梧桐|wú tóng|parasol tree
枫|楓|fēng|maple|枫叶|楓葉|fēng yè|maple leaf
柿|柿|shì|persimmon|柿子|柿子|shì zi|persimmon
莓|莓|méi|berry|草莓|草莓|cǎo méi|strawberry
葡|葡|pú|grape|葡萄|葡萄|pú tao|grape
萄|萄|táo|grape|葡萄|葡萄|pú tao|grape
瓜|瓜|guā|melon|南瓜|南瓜|nán guā|pumpkin
豆|豆|dòu|bean|大豆|大豆|dà dòu|soybean
麻|麻|má|hemp|芝麻|芝麻|zhī ma|sesame
藕|藕|ǒu|lotus root|莲藕|蓮藕|lián ǒu|lotus root
蘑|蘑|mó|mushroom|蘑菇|蘑菇|mó gu|mushroom
菇|菇|gū|mushroom|蘑菇|蘑菇|mó gu|mushroom
虾|蝦|xiā|shrimp|龙虾|龍蝦|lóng xiā|lobster
蟹|蟹|xiè|crab|螃蟹|螃蟹|páng xiè|crab
蝴|蝴|hú|butterfly|蝴蝶|蝴蝶|hú dié|butterfly
蚁|蟻|yǐ|ant|蚂蚁|螞蟻|mǎ yǐ|ant
蚂|螞|mǎ|ant|蚂蚁|螞蟻|mǎ yǐ|ant
蜻|蜻|qīng|dragonfly|蜻蜓|蜻蜓|qīng tíng|dragonfly
蜓|蜓|tíng|dragonfly|蜻蜓|蜻蜓|qīng tíng|dragonfly
鹅|鵝|é|goose|天鹅|天鵝|tiān é|swan
鸽|鴿|gē|pigeon|鸽子|鴿子|gē zi|pigeon
鹰|鷹|yīng|eagle|老鹰|老鷹|lǎo yīng|eagle
鹿|鹿|lù|deer|梅花鹿|梅花鹿|méi huā lù|sika deer
狼|狼|láng|wolf|灰狼|灰狼|huī láng|gray wolf
狐|狐|hú|fox|狐狸|狐狸|hú li|fox
狸|狸|lí|raccoon|狐狸|狐狸|hú li|fox
猴|猴|hóu|monkey|猴子|猴子|hóu zi|monkey
兔|兔|tù|rabbit|兔子|兔子|tù zi|rabbit
鼠|鼠|shǔ|rat|老鼠|老鼠|lǎo shǔ|mouse
龟|龜|guī|turtle|乌龟|烏龜|wū guī|turtle
蛇|蛇|shé|snake|毒蛇|毒蛇|dú shé|snake
"""

GRADE3_EXTRA = """
翅|翅|chì|wing|翅膀|翅膀|chì bǎng|wing
膀|膀|bǎng|shoulder|肩膀|肩膀|jiān bǎng|shoulder
稿|稿|gǎo|manuscript|稿件|稿件|gǎo jiàn|manuscript
删|刪|shān|delete|删除|刪除|shān chú|delete
词|詞|cí|word|词语|詞語|cí yǔ|word
诗|詩|shī|poem|诗歌|詩歌|shī gē|poem
拜|拜|bài|worship|拜访|拜訪|bài fǎng|visit
致|致|zhì|cause|导致|導致|dǎo zhì|cause
敬|敬|jìng|respect|尊敬|尊敬|zūn jìng|respect
骄|驕|jiāo|proud|骄傲|驕傲|jiāo ào|proud
傲|傲|ào|proud|骄傲|驕傲|jiāo ào|proud
虚|虛|xū|humble|谦虚|謙虛|qiān xū|modest
端|端|duān|end|端正|端正|duān zhèng|upright
德|德|dé|virtue|道德|道德|dào dé|morality
尊|尊|zūn|respect|尊重|尊重|zūn zhòng|respect
遵|遵|zūn|follow|遵守|遵守|zūn shǒu|obey
罪|罪|zuì|crime|犯罪|犯罪|fàn zuì|commit crime
罚|罰|fá|fine|罚款|罰款|fá kuǎn|fine
赔|賠|péi|compensate|赔偿|賠償|péi cháng|compensate
偿|償|cháng|repay|赔偿|賠償|péi cháng|compensate
债|債|zhài|debt|债务|債務|zhài wù|debt
款|款|kuǎn|fund|存款|存款|cún kuǎn|deposit
捐|捐|juān|donate|捐款|捐款|juān kuǎn|donate
贫|貧|pín|poor|贫穷|貧窮|pín qióng|poor
税|稅|shuì|tax|税收|稅收|shuì shōu|tax revenue
储|儲|chǔ|store|储存|儲存|chǔ cún|store
省|省|shěng|save|节省|節省|jié shěng|save
积|積|jī|accumulate|积累|積累|jī lěi|accumulate
累|累|lěi|accumulate|积累|積累|jī lěi|accumulate
拥|擁|yōng|embrace|拥挤|擁擠|yōng jǐ|crowded
挤|擠|jǐ|squeeze|拥挤|擁擠|yōng jǐ|crowded
载|載|zài|carry|装载|裝載|zhuāng zài|load
装|裝|zhuāng|install|安装|安裝|ān zhuāng|install
卸|卸|xiè|unload|卸货|卸貨|xiè huò|unload
输|輸|shū|transport|运输|運輸|yùn shū|transport
赢|贏|yíng|win|赢得|贏得|yíng dé|win
败|敗|bài|lose|失败|失敗|shī bài|fail
罢|罷|bà|stop|罢休|罷休|bà xiū|give up
惭|慚|cán|ashamed|惭愧|慚愧|cán kuì|ashamed
愧|愧|kuì|ashamed|惭愧|慚愧|cán kuì|ashamed
恍|恍|huǎng|dazed|恍惚|恍惚|huǎng hū|dazed
惚|惚|hū|absent-minded|恍惚|恍惚|huǎng hū|dazed
忧|憂|yōu|worry|担忧|擔憂|dān yōu|worry
虑|慮|lǜ|concern|顾虑|顧慮|gù lǜ|concern
恐|恐|kǒng|fear|恐怕|恐怕|kǒng pà|afraid
惊|驚|jīng|alarm|吃惊|吃驚|chī jīng|surprised
疑|疑|yí|doubt|怀疑|懷疑|huái yí|doubt
"""

GRADE4_EXTRA = """
盾|盾|dùn|shield|矛盾|矛盾|máo dùn|contradiction
锋|鋒|fēng|blade|先锋|先鋒|xiān fēng|pioneer
吨|噸|dūn|ton|吨位|噸位|dūn wèi|tonnage
肩|肩|jiān|shoulder|肩膀|肩膀|jiān bǎng|shoulder
胸|胸|xiōng|chest|胸口|胸口|xiōng kǒu|chest
腹|腹|fù|belly|腹部|腹部|fù bù|abdomen
臂|臂|bì|arm|手臂|手臂|shǒu bì|arm
掌|掌|zhǎng|palm|手掌|手掌|shǒu zhǎng|palm
肝|肝|gān|liver|肝脏|肝臟|gān zàng|liver
肺|肺|fèi|lung|肺部|肺部|fèi bù|lung
肾|腎|shèn|kidney|肾脏|腎臟|shèn zàng|kidney
胃|胃|wèi|stomach|胃口|胃口|wèi kǒu|appetite
肠|腸|cháng|intestine|肠子|腸子|cháng zi|intestine
骨|骨|gǔ|bone|骨头|骨頭|gǔ tou|bone
筋|筋|jīn|tendon|脑筋|腦筋|nǎo jīn|brain
肌|肌|jī|muscle|肌肉|肌肉|jī ròu|muscle
肤|膚|fū|skin|皮肤|皮膚|pí fū|skin
染|染|rǎn|dye|污染|污染|wū rǎn|pollute
污|污|wū|dirty|污水|污水|wū shuǐ|sewage
毒|毒|dú|poison|毒素|毒素|dú sù|toxin
细|細|xì|thin|细胞|細胞|xì bāo|cell
胞|胞|bāo|cell|细胞|細胞|xì bāo|cell
菌|菌|jūn|bacteria|细菌|細菌|xì jūn|bacteria
疫|疫|yì|epidemic|疫情|疫情|yì qíng|epidemic
症|症|zhèng|symptom|症状|症狀|zhèng zhuàng|symptom
吐|吐|tù|vomit|呕吐|嘔吐|ǒu tù|vomit
泻|瀉|xiè|diarrhea|腹泻|腹瀉|fù xiè|diarrhea
疗|療|liáo|treat|治疗|治療|zhì liáo|treat
愈|愈|yù|heal|治愈|治癒|zhì yù|cure
肿|腫|zhǒng|swollen|肿瘤|腫瘤|zhǒng liú|tumor
察|察|chá|examine|观察|觀察|guān chá|observe
辨|辨|biàn|distinguish|分辨|分辨|fēn biàn|distinguish
析|析|xī|analyze|分析|分析|fēn xī|analyze
判|判|pàn|judge|判断|判斷|pàn duàn|judge
评|評|píng|comment|评价|評價|píng jià|evaluate
价|價|jià|price|价值|價值|jià zhí|value
估|估|gū|estimate|估计|估計|gū jì|estimate
额|額|é|forehead|额头|額頭|é tou|forehead
预|預|yù|predict|预测|預測|yù cè|predict
防|防|fáng|prevent|防止|防止|fáng zhǐ|prevent
拦|攔|lán|block|拦住|攔住|lán zhù|block
档|檔|dàng|file|档案|檔案|dàng àn|file
挑|挑|tiāo|pick|挑选|挑選|tiāo xuǎn|pick
削|削|xiāo|peel|削皮|削皮|xiāo pí|peel
磨|磨|mó|grind|磨练|磨練|mó liàn|temper
碰|碰|pèng|touch|碰到|碰到|pèng dào|bump into
撞|撞|zhuàng|crash|碰撞|碰撞|pèng zhuàng|collide
挥|揮|huī|wave|发挥|發揮|fā huī|display
"""

GRADE5_EXTRA = """
泰|泰|tài|safe|安泰|安泰|ān tài|peaceful
郑|鄭|zhèng|surname Zheng|郑重|鄭重|zhèng zhòng|solemn
启|啟|qǐ|open|启发|啟發|qǐ fā|inspire
迪|迪|dí|enlighten|启迪|啟迪|qǐ dí|enlighten
钥|鑰|yào|key|钥匙|鑰匙|yào shi|key
匙|匙|shi|spoon|钥匙|鑰匙|yào shi|key
趋|趨|qū|trend|趋势|趨勢|qū shì|trend
矗|矗|chù|stand tall|矗立|矗立|chù lì|stand tall
冈|岡|gāng|ridge|山冈|山岡|shān gāng|ridge
岭|嶺|lǐng|mountain ridge|山岭|山嶺|shān lǐng|mountain ridge
屏|屏|píng|screen|屏幕|屏幕|píng mù|screen
簸|簸|bǒ|winnow|颠簸|顛簸|diān bǒ|bumpy
巍|巍|wēi|lofty|巍峨|巍峨|wēi é|majestic
峨|峨|é|lofty|峨眉|峨眉|é méi|Emei
涓|涓|juān|trickle|涓涓|涓涓|juān juān|trickling
澜|瀾|lán|wave|波澜|波瀾|bō lán|billows
磅|磅|páng|magnificent|磅礴|磅礴|páng bó|majestic
礴|礴|bó|boundless|磅礴|磅礴|páng bó|majestic
拟|擬|nǐ|imitate|模拟|模擬|mó nǐ|simulate
炸|炸|zhà|fry|爆炸|爆炸|bào zhà|explode
耻|恥|chǐ|shame|可耻|可恥|kě chǐ|shameful
辱|辱|rǔ|disgrace|耻辱|恥辱|chǐ rǔ|disgrace
毅|毅|yì|resolute|毅力|毅力|yì lì|perseverance
铭|銘|míng|inscribe|铭记|銘記|míng jì|remember
刑|刑|xíng|punishment|刑法|刑法|xíng fǎ|criminal law
囚|囚|qiú|prisoner|囚犯|囚犯|qiú fàn|prisoner
押|押|yā|detain|押送|押送|yā sòng|escort
刑|刑|xíng|punish|刑罚|刑罰|xíng fá|penalty
敦|敦|dūn|urge|敦煌|敦煌|dūn huáng|Dunhuang
煌|煌|huáng|bright|辉煌|輝煌|huī huáng|brilliant
粹|粹|cuì|pure|纯粹|純粹|chún cuì|pure
绑|綁|bǎng|bind|捆绑|捆綁|kǔn bǎng|bind
拘|拘|jū|detain|拘留|拘留|jū liú|detain
贬|貶|biǎn|demote|贬值|貶值|biǎn zhí|depreciate
寓|寓|yù|reside|寓言|寓言|yù yán|fable
裁|裁|cái|cut|裁判|裁判|cái pàn|referee
缠|纏|chán|entangle|缠绕|纏繞|chán rào|entangle
辙|轍|zhé|track|车辙|車轍|chē zhé|rut
"""

GRADE6_EXTRA = """
翼|翼|yì|wing|机翼|機翼|jī yì|wing
奏|奏|zòu|play|演奏|演奏|yǎn zòu|perform
拙|拙|zhuō|clumsy|朴拙|樸拙|pǔ zhuō|simple and clumsy
眺|眺|tiào|gaze|远眺|遠眺|yuǎn tiào|gaze afar
骏|駿|jùn|fine horse|骏马|駿馬|jùn mǎ|fine horse
驮|馱|tuó|carry|驮运|馱運|tuó yùn|carry on back
叛|叛|pàn|betray|叛逆|叛逆|pàn nì|rebel
侣|侶|lǚ|companion|伴侣|伴侶|bàn lǚ|companion
驭|馭|yù|drive|驾驭|駕馭|jià yù|control
疆|疆|jiāng|frontier|边疆|邊疆|biān jiāng|frontier
域|域|yù|territory|领域|領域|lǐng yù|field
衔|銜|xián|rank|头衔|頭銜|tóu xián|title
浇|澆|jiāo|water|浇灌|澆灌|jiāo guàn|irrigate
颠|顛|diān|top|颠倒|顛倒|diān dǎo|upside down
杠|槓|gàng|bar|杠杆|槓桿|gàng gǎn|lever
蔓|蔓|màn|vine|蔓延|蔓延|màn yán|spread
拄|拄|zhǔ|lean on|拄拐|拄拐|zhǔ guǎi|use a cane
铭|銘|míng|engrave|铭记|銘記|míng jì|engrave in memory
刻|刻|kè|engrave|铭刻|銘刻|míng kè|engrave
慈|慈|cí|kind|慈祥|慈祥|cí xiáng|kindly
祥|祥|xiáng|auspicious|吉祥|吉祥|jí xiáng|auspicious
悦|悅|yuè|happy|喜悦|喜悅|xǐ yuè|joy
豫|豫|yù|hesitate|犹豫|猶豫|yóu yù|hesitate
犹|猶|yóu|still|犹如|猶如|yóu rú|like
凛|凜|lǐn|cold|凛冽|凜冽|lǐn liè|biting cold
冽|冽|liè|cold|凛冽|凜冽|lǐn liè|biting cold
澎|澎|péng|surge|澎湃|澎湃|péng pài|surge
湃|湃|pài|surge|澎湃|澎湃|péng pài|surge
戈|戈|gē|dagger-axe|干戈|干戈|gān gē|weapons
焚|焚|fén|burn|焚烧|焚燒|fén shāo|burn
腊|臘|là|December|腊月|臘月|là yuè|December
膨|膨|péng|expand|膨胀|膨脹|péng zhàng|expand
胀|脹|zhàng|swell|膨胀|膨脹|péng zhàng|expand
贿|賄|huì|bribe|贿赂|賄賂|huì lù|bribe
赂|賂|lù|bribe|贿赂|賄賂|huì lù|bribe
鼎|鼎|dǐng|cauldron|鼎盛|鼎盛|dǐng shèng|flourishing
魏|魏|wèi|surname Wei|魏国|魏國|wèi guó|State of Wei
韩|韓|hán|surname Han|韩国|韓國|hán guó|Korea
秦|秦|qín|Qin dynasty|秦朝|秦朝|qín cháo|Qin Dynasty
汉|漢|hàn|Chinese|汉字|漢字|hàn zì|Chinese character
唐|唐|táng|Tang dynasty|唐朝|唐朝|táng cháo|Tang Dynasty
宋|宋|sòng|Song dynasty|宋朝|宋朝|sòng cháo|Song Dynasty
隋|隋|suí|Sui dynasty|隋朝|隋朝|suí cháo|Sui Dynasty
帝|帝|dì|emperor|皇帝|皇帝|huáng dì|emperor
臣|臣|chén|minister|大臣|大臣|dà chén|minister
侯|侯|hóu|marquis|王侯|王侯|wáng hóu|nobles
爵|爵|jué|rank|爵位|爵位|jué wèi|title of nobility
丞|丞|chéng|aide|丞相|丞相|chéng xiàng|prime minister
僧|僧|sēng|monk|僧侣|僧侶|sēng lǚ|monk
尼|尼|ní|nun|尼姑|尼姑|ní gū|nun
"""

def parse_data(data_str, grade):
    entries = []
    for line in data_str.strip().split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) != 8:
            continue
        s, t, py, meaning, w, wt, wpy, wm = parts
        entries.append({
            "simplified": s,
            "traditional": t,
            "pinyin": py,
            "meaning": meaning,
            "gradeLevel": grade,
            "exampleWords": [{
                "word": w,
                "wordTraditional": wt,
                "pinyin": wpy,
                "meaning": wm,
                "ttsText": f"{s}，{w}的{s}"
            }]
        })
    return entries


def main():
    with open(CHARS_PATH, encoding="utf-8") as f:
        existing = json.load(f)

    existing_chars = {c["simplified"] for c in existing}
    print(f"Existing characters: {len(existing_chars)}")

    new_data = [
        (1, GRADE1_EXTRA),
        (2, GRADE2_EXTRA),
        (3, GRADE3_EXTRA),
        (4, GRADE4_EXTRA),
        (5, GRADE5_EXTRA),
        (6, GRADE6_EXTRA),
    ]

    added = 0
    for grade, data_str in new_data:
        entries = parse_data(data_str, grade)
        grade_added = 0
        for entry in entries:
            if entry["simplified"] not in existing_chars:
                existing_chars.add(entry["simplified"])
                grade_entries = [c for c in existing if c["gradeLevel"] == grade]
                entry["orderInGrade"] = len(grade_entries) + grade_added
                existing.append(entry)
                grade_added += 1
                added += 1
        print(f"  Grade {grade}: added {grade_added} new characters")

    existing.sort(key=lambda c: (c["gradeLevel"], c.get("orderInGrade", 0)))

    with open(CHARS_PATH, "w", encoding="utf-8") as f:
        json.dump(existing, f, ensure_ascii=False, indent=2)

    print(f"\nTotal characters now: {len(existing)}")
    for g in range(1, 7):
        count = sum(1 for c in existing if c["gradeLevel"] == g)
        print(f"  Grade {g}: {count}")

    # Check stroke coverage
    with open(os.path.join(SCRIPT_DIR, "ChineseWriting", "Resources", "strokes.json"), encoding="utf-8") as f:
        strokes = json.load(f)
    stroke_chars = set(strokes.keys())
    all_chars = {c["simplified"] for c in existing}
    covered = len(all_chars & stroke_chars)
    missing = len(all_chars - stroke_chars)
    print(f"\nStroke data coverage: {covered}/{len(all_chars)} ({100*covered/len(all_chars):.1f}%)")
    print(f"Characters without stroke data: {missing} (will use Vision OCR fallback)")


if __name__ == "__main__":
    main()
