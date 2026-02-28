#!/usr/bin/env python3
"""Second expansion pass: add more missing curriculum characters."""
import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHARS_PATH = os.path.join(SCRIPT_DIR, "ChineseWriting", "Resources", "characters.json")

# Format: simplified|traditional|pinyin|meaning|word|wordTrad|wordPinyin|wordMeaning

GRADE1_MORE = """
雨|雨|yǔ|rain|下雨|下雨|xià yǔ|rain
电|電|diàn|electric|电话|電話|diàn huà|phone
得|得|dé|get|得到|得到|dé dào|obtain
从|從|cóng|from|从前|從前|cóng qián|before
现|現|xiàn|now|现在|現在|xiàn zài|now
些|些|xiē|some|一些|一些|yī xiē|some
意|意|yì|meaning|意思|意思|yì si|meaning
于|於|yú|at|由于|由於|yóu yú|due to
发|發|fā|send|发现|發現|fā xiàn|discover
如|如|rú|like|如果|如果|rú guǒ|if
第|第|dì|ordinal|第一|第一|dì yī|first
但|但|dàn|but|但是|但是|dàn shì|but
作|作|zuò|work|工作|工作|gōng zuò|work
老|老|lǎo|old|老师|老師|lǎo shī|teacher
其|其|qí|its|其他|其他|qí tā|other
所|所|suǒ|place|所以|所以|suǒ yǐ|therefore
而|而|ér|and|而且|而且|ér qiě|moreover
代|代|dài|generation|时代|時代|shí dài|era
将|將|jiāng|will|将来|將來|jiāng lái|future
并|並|bìng|moreover|并且|並且|bìng qiě|and
件|件|jiàn|piece (MW)|一件|一件|yī jiàn|one (item)
候|候|hòu|wait|时候|時候|shí hou|time
向|向|xiàng|toward|方向|方向|fāng xiàng|direction
至|至|zhì|to|至少|至少|zhì shǎo|at least
解|解|jiě|solve|了解|了解|liǎo jiě|understand
法|法|fǎ|law|办法|辦法|bàn fǎ|method
总|總|zǒng|always|总是|總是|zǒng shì|always
期|期|qī|period|时期|時期|shí qī|period
定|定|dìng|fix|决定|決定|jué dìng|decide
球|球|qiú|ball|足球|足球|zú qiú|soccer
呵|呵|hē|ah|呵护|呵護|hē hù|care for
活|活|huó|live|生活|生活|shēng huó|life
"""

GRADE2_MORE = """
场|場|chǎng|field|操场|操場|cāo chǎng|playground
业|業|yè|business|作业|作業|zuò yè|homework
功|功|gōng|merit|成功|成功|chéng gōng|succeed
化|化|huà|change|变化|變化|biàn huà|change
童|童|tóng|child|儿童|兒童|ér tóng|child
言|言|yán|speech|语言|語言|yǔ yán|language
理|理|lǐ|reason|道理|道理|dào lǐ|reason
由|由|yóu|from|自由|自由|zì yóu|freedom
典|典|diǎn|canon|字典|字典|zì diǎn|dictionary
遇|遇|yù|meet|遇到|遇到|yù dào|encounter
课|課|kè|class|上课|上課|shàng kè|attend class
导|導|dǎo|guide|领导|領導|lǐng dǎo|leader
师|師|shī|teacher|老师|老師|lǎo shī|teacher
量|量|liàng|measure|力量|力量|lì liàng|strength
园|園|yuán|garden|公园|公園|gōng yuán|park
选|選|xuǎn|choose|选择|選擇|xuǎn zé|choose
必|必|bì|must|必须|必須|bì xū|must
求|求|qiú|seek|要求|要求|yāo qiú|demand
练|練|liàn|practice|练习|練習|liàn xí|practice
妻|妻|qī|wife|妻子|妻子|qī zi|wife
根|根|gēn|root|根本|根本|gēn běn|fundamental
般|般|bān|sort|一般|一般|yī bān|generally
系|系|xì|system|关系|關係|guān xi|relationship
受|受|shòu|receive|接受|接受|jiē shòu|accept
深|深|shēn|deep|深刻|深刻|shēn kè|profound
程|程|chéng|process|过程|過程|guò chéng|process
度|度|dù|degree|温度|溫度|wēn dù|temperature
步|步|bù|step|跑步|跑步|pǎo bù|jog
利|利|lì|benefit|利用|利用|lì yòng|utilize
民|民|mín|people|人民|人民|rén mín|people
政|政|zhèng|politics|政府|政府|zhèng fǔ|government
治|治|zhì|govern|治理|治理|zhì lǐ|govern
经|經|jīng|classic|经过|經過|jīng guò|pass through
济|濟|jì|aid|经济|經濟|jīng jì|economy
科|科|kē|science|科学|科學|kē xué|science
技|技|jì|skill|技术|技術|jì shù|technology
术|術|shù|art|美术|美術|měi shù|fine arts
研|研|yán|study|研究|研究|yán jiū|research
究|究|jiū|investigate|究竟|究竟|jiū jìng|after all
报|報|bào|report|报纸|報紙|bào zhǐ|newspaper
通|通|tōng|through|交通|交通|jiāo tōng|traffic
交|交|jiāo|hand over|交友|交友|jiāo yǒu|make friends
息|息|xī|breath|消息|消息|xiāo xi|news
消|消|xiāo|disappear|消失|消失|xiāo shī|disappear
失|失|shī|lose|失去|失去|shī qù|lose
望|望|wàng|hope|希望|希望|xī wàng|hope
应|應|yīng|should|应该|應該|yīng gāi|should
系|係|xì|relate|关系|關係|guān xi|relationship
影|影|yǐng|shadow|影响|影響|yǐng xiǎng|influence
响|響|xiǎng|sound|响声|響聲|xiǎng shēng|sound
保|保|bǎo|protect|保护|保護|bǎo hù|protect
护|護|hù|protect|保护|保護|bǎo hù|protect
传|傳|chuán|pass|传统|傳統|chuán tǒng|tradition
统|統|tǒng|system|统一|統一|tǒng yī|unity
注|注|zhù|pour|注意|注意|zhù yì|pay attention
另|另|lìng|other|另外|另外|lìng wài|in addition
虽|雖|suī|although|虽然|雖然|suī rán|although
油|油|yóu|oil|油画|油畫|yóu huà|oil painting
旦|旦|dàn|dawn|元旦|元旦|yuán dàn|New Year's Day
份|份|fèn|portion|身份|身份|shēn fèn|identity
般|般|bān|kind|一般|一般|yī bān|general
态|態|tài|state|态度|態度|tài du|attitude
势|勢|shì|force|形势|形勢|xíng shì|situation
若|若|ruò|if|若是|若是|ruò shì|if
灵|靈|líng|spirit|灵活|靈活|líng huó|flexible
巧|巧|qiǎo|clever|巧妙|巧妙|qiǎo miào|clever
算|算|suàn|calculate|计算|計算|jì suàn|calculate
则|則|zé|rule|规则|規則|guī zé|rule
令|令|lìng|order|命令|命令|mìng lìng|order
命|命|mìng|life|生命|生命|shēng mìng|life
任|任|rèn|appoint|任何|任何|rèn hé|any
达|達|dá|reach|到达|到達|dào dá|arrive
责|責|zé|duty|责任|責任|zé rèn|responsibility
制|制|zhì|make|制度|制度|zhì dù|system
限|限|xiàn|limit|限制|限制|xiàn zhì|restrict
居|居|jū|reside|居民|居民|jū mín|resident
虑|慮|lǜ|consider|考虑|考慮|kǎo lǜ|consider
"""

GRADE3_MORE = """
符|符|fú|symbol|符号|符號|fú hào|symbol
号|號|hào|number|号码|號碼|hào mǎ|number
刊|刊|kān|publish|刊物|刊物|kān wù|publication
仅|僅|jǐn|only|仅仅|僅僅|jǐn jǐn|only
读|讀|dú|read|阅读|閱讀|yuè dú|read
阅|閱|yuè|review|阅读|閱讀|yuè dú|read
创|創|chuàng|create|创造|創造|chuàng zào|create
型|型|xíng|model|类型|類型|lèi xíng|type
类|類|lèi|kind|类似|類似|lèi sì|similar
针|針|zhēn|needle|针对|針對|zhēn duì|target
药|藥|yào|medicine|吃药|吃藥|chī yào|take medicine
片|片|piàn|slice|照片|照片|zhào piàn|photo
粒|粒|lì|grain|一粒|一粒|yī lì|one grain
域|域|yù|domain|区域|區域|qū yù|area
抗|抗|kàng|resist|抵抗|抵抗|dǐ kàng|resist
议|議|yì|discuss|会议|會議|huì yì|meeting
纷|紛|fēn|numerous|纷纷|紛紛|fēn fēn|one after another
逐|逐|zhú|chase|逐渐|逐漸|zhú jiàn|gradually
漫|漫|màn|overflow|浪漫|浪漫|làng màn|romantic
曲|曲|qǔ|song|歌曲|歌曲|gē qǔ|song
歌|歌|gē|song|唱歌|唱歌|chàng gē|sing
唱|唱|chàng|sing|唱歌|唱歌|chàng gē|sing
奏|奏|zòu|play (music)|演奏|演奏|yǎn zòu|perform
敲|敲|qiāo|knock|敲门|敲門|qiāo mén|knock door
弦|弦|xián|string|琴弦|琴弦|qín xián|string
谱|譜|pǔ|score|乐谱|樂譜|yuè pǔ|sheet music
贴|貼|tiē|paste|粘贴|粘貼|zhān tiē|paste
寻|尋|xún|seek|寻找|尋找|xún zhǎo|seek
适|適|shì|suitable|适合|適合|shì hé|suitable
令|令|lìng|cause|令人|令人|lìng rén|make people
乘|乘|chéng|ride|乘车|乘車|chéng chē|ride
厢|廂|xiāng|compartment|车厢|車廂|chē xiāng|carriage
旅|旅|lǚ|travel|旅行|旅行|lǚ xíng|travel
客|客|kè|guest|旅客|旅客|lǚ kè|passenger
沟|溝|gōu|ditch|水沟|水溝|shuǐ gōu|ditch
肉|肉|ròu|meat|猪肉|豬肉|zhū ròu|pork
鲜|鮮|xiān|fresh|新鲜|新鮮|xīn xiān|fresh
零|零|líng|zero|零食|零食|líng shí|snack
嘴|嘴|zuǐ|mouth|嘴巴|嘴巴|zuǐ ba|mouth
脑|腦|nǎo|brain|大脑|大腦|dà nǎo|brain
袋|袋|dài|bag|口袋|口袋|kǒu dài|pocket
概|概|gài|general|大概|大概|dà gài|roughly
杯|杯|bēi|cup|杯子|杯子|bēi zi|cup
件|件|jiàn|item|事件|事件|shì jiàn|event
替|替|tì|replace|代替|代替|dài tì|replace
丝|絲|sī|silk|丝绸|絲綢|sī chóu|silk
织|織|zhī|weave|编织|編織|biān zhī|weave
编|編|biān|compile|编辑|編輯|biān jí|edit
寄|寄|jì|mail|寄信|寄信|jì xìn|mail letter
封|封|fēng|seal|信封|信封|xìn fēng|envelope
拼|拼|pīn|spell|拼音|拼音|pīn yīn|pinyin
钉|釘|dīng|nail|钉子|釘子|dīng zi|nail
陈|陳|chén|display|陈列|陳列|chén liè|display
构|構|gòu|structure|结构|結構|jié gòu|structure
结|結|jié|tie|结果|結果|jié guǒ|result
沙|沙|shā|sand|沙子|沙子|shā zi|sand
漠|漠|mò|desert|沙漠|沙漠|shā mò|desert
雾|霧|wù|fog|大雾|大霧|dà wù|heavy fog
候|候|hòu|weather|气候|氣候|qì hòu|climate
植|植|zhí|plant|植物|植物|zhí wù|plant
粮|糧|liáng|grain|粮食|糧食|liáng shi|food grain
蔬|蔬|shū|vegetable|蔬菜|蔬菜|shū cài|vegetable
菜|菜|cài|vegetable|蔬菜|蔬菜|shū cài|vegetable
吨|噸|dūn|ton|一吨|一噸|yī dūn|one ton
钢|鋼|gāng|steel|钢铁|鋼鐵|gāng tiě|steel
铁|鐵|tiě|iron|铁路|鐵路|tiě lù|railway
煤|煤|méi|coal|煤炭|煤炭|méi tàn|coal
油|油|yóu|oil|石油|石油|shí yóu|petroleum
饱|飽|bǎo|full|吃饱|吃飽|chī bǎo|full
温|溫|wēn|warm|温暖|溫暖|wēn nuǎn|warm
季|季|jì|season|四季|四季|sì jì|seasons
繁|繁|fán|complex|繁忙|繁忙|fán máng|busy
殖|殖|zhí|breed|繁殖|繁殖|fán zhí|breed
孙|孫|sūn|grandson|子孙|子孫|zǐ sūn|descendants
落|落|luò|fall|落下|落下|luò xià|fall
降|降|jiàng|fall|下降|下降|xià jiàng|descend
拾|拾|shí|pick up|拾起|拾起|shí qǐ|pick up
辨|辨|biàn|distinguish|辨别|辨別|biàn bié|distinguish
"""

GRADE4_MORE = """
宣|宣|xuān|announce|宣布|宣佈|xuān bù|announce
传|傳|chuán|spread|传播|傳播|chuán bō|spread
统|統|tǒng|unite|统一|統一|tǒng yī|unite
改|改|gǎi|change|改革|改革|gǎi gé|reform
革|革|gé|leather|改革|改革|gǎi gé|reform
据|據|jù|according|根据|根據|gēn jù|according to
制|制|zhì|system|制造|製造|zhì zào|manufacture
治|治|zhì|rule|治理|治理|zhì lǐ|govern
导|導|dǎo|lead|引导|引導|yǐn dǎo|guide
引|引|yǐn|lead|引起|引起|yǐn qǐ|cause
科|科|kē|subject|科技|科技|kē jì|technology
究|究|jiū|study|研究|研究|yán jiū|research
深|深|shēn|deep|深入|深入|shēn rù|in-depth
接|接|jiē|connect|接近|接近|jiē jìn|approach
求|求|qiú|ask|请求|請求|qǐng qiú|request
受|受|shòu|accept|感受|感受|gǎn shòu|feel
程|程|chéng|journey|路程|路程|lù chéng|distance
职|職|zhí|duty|职业|職業|zhí yè|career
仰|仰|yǎng|look up|仰望|仰望|yǎng wàng|look up
俯|俯|fǔ|bow|俯视|俯視|fǔ shì|overlook
杰|傑|jié|hero|杰出|傑出|jié chū|outstanding
览|覽|lǎn|view|浏览|瀏覽|liú lǎn|browse
刑|刑|xíng|punishment|刑罚|刑罰|xíng fá|punishment
斩|斬|zhǎn|behead|斩断|斬斷|zhǎn duàn|sever
奈|奈|nài|how|无奈|無奈|wú nài|helpless
矿|礦|kuàng|mine|矿产|礦產|kuàng chǎn|mineral
卫|衛|wèi|guard|卫生|衛生|wèi shēng|hygiene
段|段|duàn|section|阶段|階段|jiē duàn|phase
旋|旋|xuán|rotate|旋转|旋轉|xuán zhuǎn|rotate
隐|隱|yǐn|hide|隐藏|隱藏|yǐn cáng|hide
秩|秩|zhì|order|秩序|秩序|zhì xù|order
序|序|xù|order|顺序|順序|shùn xù|order
弃|棄|qì|abandon|放弃|放棄|fàng qì|give up
拓|拓|tuò|expand|开拓|開拓|kāi tuò|pioneer
凭|憑|píng|lean|凭借|憑藉|píng jiè|rely on
裂|裂|liè|crack|裂开|裂開|liè kāi|crack open
厌|厭|yàn|dislike|讨厌|討厭|tǎo yàn|hate
讨|討|tǎo|discuss|讨论|討論|tǎo lùn|discuss
论|論|lùn|discuss|讨论|討論|tǎo lùn|discuss
描|描|miáo|trace|描写|描寫|miáo xiě|describe
绘|繪|huì|draw|描绘|描繪|miáo huì|depict
拢|攏|lǒng|gather|聚拢|聚攏|jù lǒng|gather
掠|掠|lüè|skim|掠过|掠過|lüè guò|skim past
偶|偶|ǒu|occasional|偶然|偶然|ǒu rán|by chance
尔|爾|ěr|you|偶尔|偶爾|ǒu ěr|occasionally
胜|勝|shèng|win|胜利|勝利|shèng lì|victory
仅|僅|jǐn|merely|不仅|不僅|bù jǐn|not only
凡|凡|fán|ordinary|凡是|凡是|fán shì|any
绩|績|jī|merit|成绩|成績|chéng jī|achievement
恕|恕|shù|forgive|饶恕|饒恕|ráo shù|forgive
索|索|suǒ|search|索取|索取|suǒ qǔ|demand
厨|廚|chú|kitchen|厨房|廚房|chú fáng|kitchen
糟|糟|zāo|messy|糟糕|糟糕|zāo gāo|terrible
漏|漏|lòu|leak|漏水|漏水|lòu shuǐ|leak
喂|餵|wèi|feed|喂食|餵食|wèi shí|feed
汤|湯|tāng|soup|鸡汤|雞湯|jī tāng|chicken soup
陡|陡|dǒu|steep|陡峭|陡峭|dǒu qiào|steep
链|鏈|liàn|chain|锁链|鎖鏈|suǒ liàn|chain
颤|顫|chàn|shake|颤抖|顫抖|chàn dǒu|tremble
攀|攀|pān|climb|攀登|攀登|pān dēng|climb
聪|聰|cōng|clever|聪明|聰明|cōng míng|clever
操|操|cāo|exercise|操场|操場|cāo chǎng|playground
纪|紀|jì|era|世纪|世紀|shì jì|century
约|約|yuē|about|大约|大約|dà yuē|roughly
钓|釣|diào|fish|钓鱼|釣魚|diào yú|go fishing
"""

GRADE5_MORE = """
幕|幕|mù|curtain|幕布|幕布|mù bù|curtain
宵|宵|xiāo|night|元宵|元宵|yuán xiāo|Lantern Festival
摊|攤|tān|spread|摊开|攤開|tān kāi|spread out
贩|販|fàn|peddle|小贩|小販|xiǎo fàn|vendor
吆|吆|yāo|shout|吆喝|吆喝|yāo he|shout
喝|喝|hè|shout|吆喝|吆喝|yāo he|shout
闸|閘|zhá|sluice|闸门|閘門|zhá mén|sluice gate
拆|拆|chāi|tear down|拆除|拆除|chāi chú|demolish
辞|辭|cí|word|辞职|辭職|cí zhí|resign
抵|抵|dǐ|resist|抵达|抵達|dǐ dá|arrive
押|押|yā|pledge|押金|押金|yā jīn|deposit
签|簽|qiān|sign|签名|簽名|qiān míng|sign
颁|頒|bān|issue|颁奖|頒獎|bān jiǎng|award
仪|儀|yí|ceremony|仪式|儀式|yí shì|ceremony
眷|眷|juàn|family|亲眷|親眷|qīn juàn|relatives
庇|庇|bì|shelter|庇护|庇護|bì hù|protect
爆|爆|bào|explode|爆炸|爆炸|bào zhà|explode
维|維|wéi|dimension|维持|維持|wéi chí|maintain
杖|杖|zhàng|staff|手杖|手杖|shǒu zhàng|walking stick
竭|竭|jié|exhaust|竭力|竭力|jié lì|do one's best
铸|鑄|zhù|cast|铸造|鑄造|zhù zào|cast
逮|逮|dǎi|catch|逮捕|逮捕|dài bǔ|arrest
铐|銬|kào|handcuffs|手铐|手銬|shǒu kào|handcuffs
盼|盼|pàn|hope|盼望|盼望|pàn wàng|hope for
柜|櫃|guì|cabinet|柜台|櫃台|guì tái|counter
喉|喉|hóu|throat|喉咙|喉嚨|hóu lóng|throat
咙|嚨|lóng|throat|喉咙|喉嚨|hóu lóng|throat
沮|沮|jǔ|depressed|沮丧|沮喪|jǔ sàng|depressed
咐|咐|fù|tell|吩咐|吩咐|fēn fù|instruct
吩|吩|fēn|instruct|吩咐|吩咐|fēn fù|instruct
饼|餅|bǐng|cake|饼干|餅乾|bǐng gān|cookie
缸|缸|gāng|jar|水缸|水缸|shuǐ gāng|water jar
嗅|嗅|xiù|smell|嗅觉|嗅覺|xiù jué|sense of smell
酱|醬|jiàng|sauce|酱油|醬油|jiàng yóu|soy sauce
醋|醋|cù|vinegar|吃醋|吃醋|chī cù|jealous
翼|翼|yì|wing|羽翼|羽翼|yǔ yì|wings
厘|釐|lí|centimeter|厘米|釐米|lí mǐ|centimeter
愈|愈|yù|heal|治愈|治癒|zhì yù|cure
辅|輔|fǔ|assist|辅助|輔助|fǔ zhù|assist
缝|縫|féng|sew|缝补|縫補|féng bǔ|mend
刺|刺|cì|thorn|刺激|刺激|cì jī|stimulate
猬|蝟|wèi|hedgehog|刺猬|刺蝟|cì wèi|hedgehog
畅|暢|chàng|smooth|畅通|暢通|chàng tōng|smooth
销|銷|xiāo|sell|销售|銷售|xiāo shòu|sell
魄|魄|pò|spirit|气魄|氣魄|qì pò|spirit
拐|拐|guǎi|turn|拐弯|拐彎|guǎi wān|turn
乞|乞|qǐ|beg|乞丐|乞丐|qǐ gài|beggar
"""

GRADE6_MORE = """
缕|縷|lǚ|strand|一缕|一縷|yī lǚ|one strand
幽|幽|yōu|quiet|幽静|幽靜|yōu jìng|secluded
雅|雅|yǎ|refined|典雅|典雅|diǎn yǎ|elegant
搏|搏|bó|struggle|拼搏|拼搏|pīn bó|fight hard
吻|吻|wěn|mouth|亲吻|親吻|qīn wěn|kiss
汪|汪|wāng|pool|汪洋|汪洋|wāng yáng|vast ocean
旺|旺|wàng|flourishing|兴旺|興旺|xīng wàng|prosperous
瀑|瀑|pù|waterfall|瀑布|瀑布|pù bù|waterfall
峡|峽|xiá|gorge|峡谷|峽谷|xiá gǔ|canyon
桂|桂|guì|osmanthus|桂花|桂花|guì huā|osmanthus
兀|兀|wù|abrupt|突兀|突兀|tū wù|abrupt
绵|綿|mián|silk|绵延|綿延|mián yán|stretch
拙|拙|zhuō|clumsy|笨拙|笨拙|bèn zhuō|clumsy
簇|簇|cù|cluster|一簇|一簇|yī cù|a cluster
苔|苔|tái|moss|苔藓|苔蘚|tái xiǎn|moss
藓|蘚|xiǎn|moss|苔藓|苔蘚|tái xiǎn|moss
坪|坪|píng|level ground|草坪|草坪|cǎo píng|lawn
蔗|蔗|zhè|sugarcane|甘蔗|甘蔗|gān zhè|sugarcane
辟|闢|pì|open up|开辟|開闢|kāi pì|open up
巫|巫|wū|witch|巫师|巫師|wū shī|wizard
嫦|嫦|cháng|Chang'e|嫦娥|嫦娥|cháng é|Chang'e
娥|娥|é|beautiful|嫦娥|嫦娥|cháng é|Chang'e
庐|廬|lú|hut|庐山|廬山|lú shān|Mount Lu
瀑|瀑|pù|waterfall|瀑布|瀑布|pù bù|waterfall
缀|綴|zhuì|embellish|点缀|點綴|diǎn zhuì|adorn
磁|磁|cí|magnet|磁铁|磁鐵|cí tiě|magnet
斑|斑|bān|spot|斑点|斑點|bān diǎn|spot
篷|篷|péng|canopy|帐篷|帳篷|zhàng péng|tent
寨|寨|zhài|stockade|山寨|山寨|shān zhài|mountain village
冤|冤|yuān|injustice|冤枉|冤枉|yuān wang|wronged
枉|枉|wǎng|in vain|冤枉|冤枉|yuān wang|wronged
寝|寢|qǐn|sleep|寝室|寢室|qǐn shì|dormitory
频|頻|pín|frequent|频率|頻率|pín lǜ|frequency
赴|赴|fù|go to|奔赴|奔赴|bēn fù|rush to
尴|尷|gān|awkward|尴尬|尷尬|gān gà|awkward
尬|尬|gà|awkward|尴尬|尷尬|gān gà|awkward
煌|煌|huáng|brilliant|辉煌|輝煌|huī huáng|brilliant
拙|拙|zhuō|clumsy|拙劣|拙劣|zhuō liè|clumsy
簸|簸|bǒ|winnow|颠簸|顛簸|diān bǒ|bumpy
砂|砂|shā|sand|砂石|砂石|shā shí|gravel
裕|裕|yù|abundant|富裕|富裕|fù yù|wealthy
僵|僵|jiāng|stiff|僵硬|僵硬|jiāng yìng|stiff
绣|繡|xiù|embroider|刺绣|刺繡|cì xiù|embroidery
徽|徽|huī|emblem|徽章|徽章|huī zhāng|badge
冶|冶|yě|smelt|冶炼|冶煉|yě liàn|smelt
锤|錘|chuí|hammer|锤子|錘子|chuí zi|hammer
炼|煉|liàn|refine|锻炼|鍛煉|duàn liàn|exercise
泄|洩|xiè|leak|泄露|洩露|xiè lù|divulge
惧|懼|jù|fear|恐惧|恐懼|kǒng jù|fear
措|措|cuò|arrange|措施|措施|cuò shī|measure
颅|顱|lú|skull|头颅|頭顱|tóu lú|head
拯|拯|zhěng|save|拯救|拯救|zhěng jiù|rescue
溃|潰|kuì|burst|溃败|潰敗|kuì bài|rout
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
        (1, GRADE1_MORE),
        (2, GRADE2_MORE),
        (3, GRADE3_MORE),
        (4, GRADE4_MORE),
        (5, GRADE5_MORE),
        (6, GRADE6_MORE),
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


if __name__ == "__main__":
    main()
