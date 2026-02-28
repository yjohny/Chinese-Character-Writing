#!/usr/bin/env python3
"""
Expand characters.json with complete Grade 1-6 curriculum characters.

Reads existing characters.json, adds missing standard curriculum characters,
and writes the expanded file. Preserves all existing entries unchanged.

Character data sourced from the standard PRC primary school Chinese language
curriculum (部编版小学语文写字表).
"""
import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHARS_PATH = os.path.join(SCRIPT_DIR, "ChineseWriting", "Resources", "characters.json")

# ──────────────────────────────────────────────────────────────────────
# NEW CHARACTER DATA
# Format: simplified|traditional|pinyin|meaning|word|wordTrad|wordPinyin|wordMeaning
# Characters already in the app are skipped automatically.
# ──────────────────────────────────────────────────────────────────────

GRADE1_NEW = """
去|去|qù|go|回去|回去|huí qù|go back
牛|牛|niú|cow|牛奶|牛奶|niú nǎi|milk
鸟|鳥|niǎo|bird|小鸟|小鳥|xiǎo niǎo|small bird
早|早|zǎo|early|早上|早上|zǎo shang|morning
木|木|mù|wood|树木|樹木|shù mù|trees
林|林|lín|forest|树林|樹林|shù lín|forest
心|心|xīn|heart|开心|開心|kāi xīn|happy
中|中|zhōng|middle|中国|中國|zhōng guó|China
立|立|lì|stand|立正|立正|lì zhèng|stand at attention
后|後|hòu|after|后面|後面|hòu miàn|behind
好|好|hǎo|good|好的|好的|hǎo de|okay
比|比|bǐ|compare|比较|比較|bǐ jiào|compare
才|才|cái|talent|刚才|剛才|gāng cái|just now
同|同|tóng|same|同学|同學|tóng xué|classmate
学|學|xué|study|学习|學習|xué xí|study
自|自|zì|self|自己|自己|zì jǐ|oneself
己|己|jǐ|self|自己|自己|zì jǐ|oneself
衣|衣|yī|clothing|衣服|衣服|yī fu|clothes
牙|牙|yá|tooth|牙齿|牙齒|yá chǐ|teeth
只|只|zhī|only|一只|一隻|yī zhī|one (animal)
工|工|gōng|work|工人|工人|gōng rén|worker
厂|廠|chǎng|factory|工厂|工廠|gōng chǎng|factory
雪|雪|xuě|snow|下雪|下雪|xià xuě|snowing
娃|娃|wá|baby|娃娃|娃娃|wá wa|doll
吓|嚇|xià|scare|吓人|嚇人|xià rén|scary
想|想|xiǎng|think|想念|想念|xiǎng niàn|miss
思|思|sī|think|思想|思想|sī xiǎng|thought
感|感|gǎn|feel|感觉|感覺|gǎn jué|feel
很|很|hěn|very|很好|很好|hěn hǎo|very good
像|像|xiàng|resemble|好像|好像|hǎo xiàng|seems like
数|數|shù|number|数学|數學|shù xué|math
千|千|qiān|thousand|千万|千萬|qiān wàn|must
首|首|shǒu|head; first|首先|首先|shǒu xiān|first
采|採|cǎi|pick|采花|採花|cǎi huā|pick flowers
无|無|wú|without|无法|無法|wú fǎ|unable
树|樹|shù|tree|大树|大樹|dà shù|big tree
爱|愛|ài|love|爱心|愛心|ài xīn|love
尖|尖|jiān|sharp|尖锐|尖銳|jiān ruì|sharp
角|角|jiǎo|corner|角度|角度|jiǎo dù|angle
亮|亮|liàng|bright|明亮|明亮|míng liàng|bright
机|機|jī|machine|飞机|飛機|fēi jī|airplane
台|臺|tái|platform|台上|臺上|tái shàng|on stage
朵|朵|duǒ|flower (MW)|一朵|一朵|yī duǒ|one (flower)
美|美|měi|beautiful|美丽|美麗|měi lì|beautiful
呀|呀|ya|ah|好呀|好呀|hǎo ya|okay!
边|邊|biān|side|旁边|旁邊|páng biān|beside
次|次|cì|time (MW)|一次|一次|yī cì|once
找|找|zhǎo|look for|找到|找到|zhǎo dào|found
平|平|píng|flat|平安|平安|píng ān|safe
办|辦|bàn|handle|办法|辦法|bàn fǎ|method
包|包|bāo|bag|书包|書包|shū bāo|schoolbag
钟|鐘|zhōng|clock|时钟|時鐘|shí zhōng|clock
元|元|yuán|yuan|一元|一元|yī yuán|one yuan
共|共|gòng|together|一共|一共|yī gòng|altogether
经|經|jīng|pass through|已经|已經|yǐ jīng|already
坐|坐|zuò|sit|坐下|坐下|zuò xià|sit down
百|百|bǎi|hundred|一百|一百|yī bǎi|one hundred
舌|舌|shé|tongue|舌头|舌頭|shé tou|tongue
点|點|diǎn|dot; point|一点|一點|yī diǎn|a little
非|非|fēi|not|非常|非常|fēi cháng|very
常|常|cháng|often|经常|經常|jīng cháng|often
瓜|瓜|guā|melon|西瓜|西瓜|xī guā|watermelon
病|病|bìng|ill|生病|生病|shēng bìng|get sick
医|醫|yī|doctor|医生|醫生|yī shēng|doctor
别|別|bié|don't|别人|別人|bié rén|others
奇|奇|qí|strange|奇怪|奇怪|qí guài|strange
怕|怕|pà|fear|害怕|害怕|hài pà|afraid
条|條|tiáo|strip (MW)|一条|一條|yī tiáo|one (strip)
爬|爬|pá|climb|爬山|爬山|pá shān|climb mountain
姐|姐|jiě|older sister|姐姐|姐姐|jiě jie|older sister
您|您|nín|you (polite)|您好|您好|nín hǎo|hello (polite)
草|草|cǎo|grass|小草|小草|xiǎo cǎo|small grass
房|房|fáng|room|房子|房子|fáng zi|house
居|居|jū|live|居住|居住|jū zhù|reside
招|招|zhāo|beckon|招手|招手|zhāo shǒu|wave hand
呼|呼|hū|call|呼吸|呼吸|hū xī|breathe
讲|講|jiǎng|speak|讲话|講話|jiǎng huà|speak
床|床|chuáng|bed|起床|起床|qǐ chuáng|get up
前|前|qián|front|前面|前面|qián miàn|in front
光|光|guāng|light|阳光|陽光|yáng guāng|sunlight
低|低|dī|low|低头|低頭|dī tóu|bow head
故|故|gù|old; reason|故事|故事|gù shi|story
乡|鄉|xiāng|village|家乡|家鄉|jiā xiāng|hometown
晚|晚|wǎn|late|晚上|晚上|wǎn shang|evening
再|再|zài|again|再见|再見|zài jiàn|goodbye
网|網|wǎng|net|上网|上網|shàng wǎng|go online
造|造|zào|make|创造|創造|chuàng zào|create
迷|迷|mí|lost|迷路|迷路|mí lù|get lost
年|年|nián|year|今年|今年|jīn nián|this year
夜|夜|yè|night|夜晚|夜晚|yè wǎn|night
送|送|sòng|send|送给|送給|sòng gěi|give
忙|忙|máng|busy|帮忙|幫忙|bāng máng|help
被|被|bèi|by (passive)|被子|被子|bèi zi|quilt
路|路|lù|road|马路|馬路|mǎ lù|road
原|原|yuán|original|原来|原來|yuán lái|originally
做|做|zuò|do|做事|做事|zuò shì|do things
蛙|蛙|wā|frog|青蛙|青蛙|qīng wā|frog
卖|賣|mài|sell|卖东西|賣東西|mài dōng xi|sell things
抬|抬|tái|lift|抬头|抬頭|tái tóu|raise head
指|指|zhǐ|point|手指|手指|shǒu zhǐ|finger
接|接|jiē|receive|接受|接受|jiē shòu|accept
惊|驚|jīng|surprise|惊讶|驚訝|jīng yà|surprised
梨|梨|lí|pear|梨子|梨子|lí zi|pear
粗|粗|cū|thick|粗心|粗心|cū xīn|careless
答|答|dá|answer|回答|回答|huí dá|answer
问|問|wèn|ask|问题|問題|wèn tí|question
笨|笨|bèn|stupid|笨蛋|笨蛋|bèn dàn|fool
哪|哪|nǎ|which|哪里|哪裡|nǎ lǐ|where
谁|誰|shuí|who|谁的|誰的|shuí de|whose
怎|怎|zěn|how|怎么|怎麼|zěn me|how
钱|錢|qián|money|零钱|零錢|líng qián|change
最|最|zuì|most|最好|最好|zuì hǎo|best
该|該|gāi|should|应该|應該|yīng gāi|should
语|語|yǔ|language|语文|語文|yǔ wén|Chinese class
告|告|gào|tell|告诉|告訴|gào su|tell
诉|訴|sù|tell|告诉|告訴|gào su|tell
狗|狗|gǒu|dog|小狗|小狗|xiǎo gǒu|puppy
猪|豬|zhū|pig|小猪|小豬|xiǎo zhū|piglet
象|象|xiàng|elephant|大象|大象|dà xiàng|elephant
鸡|雞|jī|chicken|公鸡|公雞|gōng jī|rooster
鸭|鴨|yā|duck|鸭子|鴨子|yā zi|duck
羊|羊|yáng|sheep|山羊|山羊|shān yáng|goat
面|面|miàn|face|面前|面前|miàn qián|in front of
黄|黃|huáng|yellow|黄色|黃色|huáng sè|yellow
"""

GRADE2_NEW = """
雷|雷|léi|thunder|打雷|打雷|dǎ léi|thunder
需|需|xū|need|需要|需要|xū yào|need
世|世|shì|world|世界|世界|shì jiè|world
复|復|fù|again|复习|復習|fù xí|review
苏|蘇|sū|revive|苏醒|蘇醒|sū xǐng|wake up
柳|柳|liǔ|willow|柳树|柳樹|liǔ shù|willow tree
笋|筍|sǔn|bamboo shoot|竹笋|竹筍|zhú sǔn|bamboo shoot
荡|蕩|dàng|swing|荡秋千|蕩鞦韆|dàng qiū qiān|swing
桃|桃|táo|peach|桃子|桃子|táo zi|peach
杏|杏|xìng|apricot|杏花|杏花|xìng huā|apricot flower
客|客|kè|guest|客人|客人|kè rén|guest
暗|暗|àn|dark|黑暗|黑暗|hēi àn|dark
丑|醜|chǒu|ugly|丑小鸭|醜小鴨|chǒu xiǎo yā|ugly duckling
永|永|yǒng|forever|永远|永遠|yǒng yuǎn|forever
饱|飽|bǎo|full|吃饱|吃飽|chī bǎo|eat full
温|溫|wēn|warm|温暖|溫暖|wēn nuǎn|warm
暖|暖|nuǎn|warm|温暖|溫暖|wēn nuǎn|warm
能|能|néng|can|能力|能力|néng lì|ability
事|事|shì|matter|事情|事情|shì qing|matter
互|互|hù|mutual|互相|互相|hù xiāng|mutual
令|令|lìng|order|命令|命令|mìng lìng|command
变|變|biàn|change|变化|變化|biàn huà|change
极|極|jí|extreme|极了|極了|jí le|extremely
傍|傍|bàng|near|傍晚|傍晚|bàng wǎn|dusk
李|李|lǐ|plum|李子|李子|lǐ zi|plum
香|香|xiāng|fragrant|香味|香味|xiāng wèi|fragrance
密|密|mì|dense|秘密|秘密|mì mì|secret
使|使|shǐ|use|使用|使用|shǐ yòng|use
劲|勁|jìn|strength|使劲|使勁|shǐ jìn|exert
勇|勇|yǒng|brave|勇敢|勇敢|yǒng gǎn|brave
亭|亭|tíng|pavilion|亭子|亭子|tíng zi|pavilion
鲜|鮮|xiān|fresh|新鲜|新鮮|xīn xiān|fresh
尝|嘗|cháng|taste|品尝|品嘗|pǐn cháng|taste
碧|碧|bì|jade green|碧绿|碧綠|bì lǜ|jade green
紫|紫|zǐ|purple|紫色|紫色|zǐ sè|purple
段|段|duàn|section|一段|一段|yī duàn|a section
吸|吸|xī|inhale|呼吸|呼吸|hū xī|breathe
夫|夫|fū|husband|大夫|大夫|dài fu|doctor
示|示|shì|show|表示|表示|biǎo shì|express
忘|忘|wàng|forget|忘记|忘記|wàng jì|forget
助|助|zhù|help|帮助|幫助|bāng zhù|help
强|強|qiáng|strong|强大|強大|qiáng dà|powerful
问|問|wèn|ask|问题|問題|wèn tí|question
楼|樓|lóu|building|楼房|樓房|lóu fáng|building
年|年|nián|year|今年|今年|jīn nián|this year
帮|幫|bāng|help|帮忙|幫忙|bāng máng|help
穿|穿|chuān|wear|穿衣|穿衣|chuān yī|dress
弯|彎|wān|bend|弯曲|彎曲|wān qū|curved
背|背|bēi|carry|背书|背書|bēi shū|recite
油|油|yóu|oil|石油|石油|shí yóu|petroleum
粮|糧|liáng|grain|粮食|糧食|liáng shi|food
食|食|shí|eat|食物|食物|shí wù|food
苦|苦|kǔ|bitter|辛苦|辛苦|xīn kǔ|hard work
辛|辛|xīn|hard|辛苦|辛苦|xīn kǔ|hard work
忍|忍|rěn|endure|忍耐|忍耐|rěn nài|endure
劳|勞|láo|labor|劳动|勞動|láo dòng|labor
观|觀|guān|view|观看|觀看|guān kàn|watch
摆|擺|bǎi|place|摆放|擺放|bǎi fàng|arrange
架|架|jià|frame|书架|書架|shū jià|bookshelf
困|困|kùn|trapped|困难|困難|kùn nan|difficult
难|難|nán|difficult|困难|困難|kùn nan|difficult
此|此|cǐ|this|因此|因此|yīn cǐ|therefore
刻|刻|kè|carve|时刻|時刻|shí kè|moment
留|留|liú|stay|留下|留下|liú xià|stay
弄|弄|nòng|do|玩弄|玩弄|wán nòng|play with
满|滿|mǎn|full|满意|滿意|mǎn yì|satisfied
棵|棵|kē|tree (MW)|一棵|一棵|yī kē|one (tree)
精|精|jīng|essence|精神|精神|jīng shén|spirit
忽|忽|hū|suddenly|忽然|忽然|hū rán|suddenly
然|然|rán|so|然后|然後|rán hòu|then
底|底|dǐ|bottom|到底|到底|dào dǐ|after all
富|富|fù|rich|丰富|豐富|fēng fù|rich
突|突|tū|sudden|突然|突然|tū rán|suddenly
掉|掉|diào|drop|掉下|掉下|diào xià|fall down
桌|桌|zhuō|table|桌子|桌子|zhuō zi|table
极|極|jí|pole|南极|南極|nán jí|South Pole
汽|汽|qì|steam|汽车|汽車|qì chē|car
拿|拿|ná|take|拿走|拿走|ná zǒu|take away
喝|喝|hē|drink|喝水|喝水|hē shuǐ|drink water
具|具|jù|tool|工具|工具|gōng jù|tool
食|食|shí|food|食品|食品|shí pǐn|food
店|店|diàn|shop|商店|商店|shāng diàn|shop
脸|臉|liǎn|face|洗脸|洗臉|xǐ liǎn|wash face
眼|眼|yǎn|eye|眼睛|眼睛|yǎn jing|eye
睛|睛|jīng|eyeball|眼睛|眼睛|yǎn jing|eye
泪|淚|lèi|tear|眼泪|眼淚|yǎn lèi|tear
重|重|zhòng|heavy|重要|重要|zhòng yào|important
味|味|wèi|taste|味道|味道|wèi dào|taste
道|道|dào|road; way|知道|知道|zhī dào|know
忆|憶|yì|remember|回忆|回憶|huí yì|recall
异|異|yì|different|差异|差異|chā yì|difference
遥|遙|yáo|distant|遥远|遙遠|yáo yuǎn|far away
插|插|chā|insert|插花|插花|chā huā|arrange flowers
抄|抄|chāo|copy|抄写|抄寫|chāo xiě|copy
冷|冷|lěng|cold|冰冷|冰冷|bīng lěng|ice cold
热|熱|rè|hot|热情|熱情|rè qíng|enthusiasm
淡|淡|dàn|light|淡水|淡水|dàn shuǐ|fresh water
穷|窮|qióng|poor|穷人|窮人|qióng rén|poor person
死|死|sǐ|die|死亡|死亡|sǐ wáng|death
活|活|huó|live|生活|生活|shēng huó|life
苹|蘋|píng|apple|苹果|蘋果|píng guǒ|apple
预|預|yù|advance|预习|預習|yù xí|preview
累|累|lèi|tired|劳累|勞累|láo lèi|tired
切|切|qiē|cut|一切|一切|yī qiè|everything
新|新|xīn|new|新的|新的|xīn de|new
旧|舊|jiù|old|新旧|新舊|xīn jiù|new and old
符|符|fú|symbol|符号|符號|fú hào|symbol
座|座|zuò|seat|座位|座位|zuò wèi|seat
急|急|jí|urgent|着急|著急|zháo jí|anxious
被|被|bèi|by (passive)|被子|被子|bèi zi|quilt
容|容|róng|contain|容易|容易|róng yì|easy
易|易|yì|easy|容易|容易|róng yì|easy
哭|哭|kū|cry|哭泣|哭泣|kū qì|cry
笔|筆|bǐ|pen|毛笔|毛筆|máo bǐ|brush pen
灯|燈|dēng|lamp|电灯|電燈|diàn dēng|electric light
窗|窗|chuāng|window|窗户|窗戶|chuāng hu|window
户|戶|hù|door|户口|戶口|hù kǒu|household
纸|紙|zhǐ|paper|纸张|紙張|zhǐ zhāng|paper
船|船|chuán|boat|小船|小船|xiǎo chuán|small boat
弟|弟|dì|younger brother|弟弟|弟弟|dì di|younger brother
"""

GRADE3_NEW = """
融|融|róng|melt|融化|融化|róng huà|melt
燕|燕|yàn|swallow (bird)|燕子|燕子|yàn zi|swallow
鸳|鴛|yuān|mandarin duck|鸳鸯|鴛鴦|yuān yāng|mandarin duck
鸯|鴦|yāng|mandarin duck|鸳鸯|鴛鴦|yuān yāng|mandarin duck
惠|惠|huì|benefit|优惠|優惠|yōu huì|discount
崇|崇|chóng|worship|崇拜|崇拜|chóng bài|worship
芦|蘆|lú|reed|芦苇|蘆葦|lú wěi|reed
芽|芽|yá|sprout|发芽|發芽|fā yá|sprout
短|短|duǎn|short|短小|短小|duǎn xiǎo|small
梅|梅|méi|plum|梅花|梅花|méi huā|plum blossom
麻|麻|má|hemp|麻烦|麻煩|má fan|trouble
绿|綠|lǜ|green|绿色|綠色|lǜ sè|green
集|集|jí|gather|集合|集合|jí hé|gather
般|般|bān|kind|一般|一般|yī bān|generally
精|精|jīng|fine|精美|精美|jīng měi|exquisite
载|載|zài|carry|记载|記載|jì zài|record
舞|舞|wǔ|dance|跳舞|跳舞|tiào wǔ|dance
蝶|蝶|dié|butterfly|蝴蝶|蝴蝶|hú dié|butterfly
蜂|蜂|fēng|bee|蜜蜂|蜜蜂|mì fēng|bee
碎|碎|suì|broken|破碎|破碎|pò suì|shatter
拂|拂|fú|brush|吹拂|吹拂|chuī fú|breeze
聚|聚|jù|gather|聚集|聚集|jù jí|gather
形|形|xíng|shape|形状|形狀|xíng zhuàng|shape
掠|掠|lüè|plunder|掠过|掠過|lüè guò|sweep past
偶|偶|ǒu|even; pair|偶尔|偶爾|ǒu ěr|occasionally
尔|爾|ěr|you (archaic)|偶尔|偶爾|ǒu ěr|occasionally
沾|沾|zhān|dip|沾水|沾水|zhān shuǐ|dip in water
倦|倦|juàn|tired|疲倦|疲倦|pí juàn|tired
闲|閒|xián|idle|空闲|空閒|kòng xián|free time
散|散|sàn|scatter|散步|散步|sàn bù|stroll
纤|纖|xiān|fine|纤细|纖細|xiān xì|slender
杆|桿|gān|pole|旗杆|旗桿|qí gān|flagpole
绸|綢|chóu|silk|丝绸|絲綢|sī chóu|silk
裁|裁|cái|cut|裁剪|裁剪|cái jiǎn|cut
剪|剪|jiǎn|scissors|剪刀|剪刀|jiǎn dāo|scissors
寄|寄|jì|send|寄信|寄信|jì xìn|mail letter
宿|宿|sù|stay|住宿|住宿|zhù sù|lodging
徒|徒|tú|apprentice|徒弟|徒弟|tú dì|apprentice
程|程|chéng|journey|过程|過程|guò chéng|process
魔|魔|mó|demon|魔术|魔術|mó shù|magic
术|術|shù|skill|技术|技術|jì shù|technology
欧|歐|ōu|Europe|欧洲|歐洲|ōu zhōu|Europe
洲|洲|zhōu|continent|亚洲|亞洲|yà zhōu|Asia
社|社|shè|society|社会|社會|shè huì|society
志|志|zhì|will|志向|志向|zhì xiàng|aspiration
借|借|jiè|borrow|借书|借書|jiè shū|borrow book
板|板|bǎn|board|黑板|黑板|hēi bǎn|blackboard
破|破|pò|break|破坏|破壞|pò huài|destroy
仍|仍|réng|still|仍然|仍然|réng rán|still
便|便|biàn|convenient|方便|方便|fāng biàn|convenient
硬|硬|yìng|hard|坚硬|堅硬|jiān yìng|hard
砍|砍|kǎn|chop|砍树|砍樹|kǎn shù|chop tree
挡|擋|dǎng|block|阻挡|阻擋|zǔ dǎng|block
劈|劈|pī|split|劈开|劈開|pī kāi|split open
屈|屈|qū|bend|委屈|委屈|wěi qū|wronged
缩|縮|suō|shrink|缩小|縮小|suō xiǎo|shrink
努|努|nǔ|effort|努力|努力|nǔ lì|work hard
怒|怒|nù|anger|愤怒|憤怒|fèn nù|angry
既|既|jì|already|既然|既然|jì rán|since
柱|柱|zhù|pillar|柱子|柱子|zhù zi|pillar
渐|漸|jiàn|gradually|渐渐|漸漸|jiàn jiàn|gradually
油|油|yóu|oil|石油|石油|shí yóu|petroleum
检|檢|jiǎn|examine|检查|檢查|jiǎn chá|inspect
测|測|cè|measure|测量|測量|cè liáng|measure
冰|冰|bīng|ice|冰冷|冰冷|bīng lěng|ice cold
柜|櫃|guì|cabinet|柜子|櫃子|guì zi|cabinet
吞|吞|tūn|swallow|吞下|吞下|tūn xià|swallow
固|固|gù|solid|固定|固定|gù dìng|fix
赵|趙|zhào|surname Zhao|赵国|趙國|zhào guó|State of Zhao
鉴|鑒|jiàn|mirror|鉴定|鑒定|jiàn dìng|appraise
假|假|jiǎ|false|假如|假如|jiǎ rú|if
威|威|wēi|power|威力|威力|wēi lì|might
武|武|wǔ|martial|武术|武術|wǔ shù|martial arts
镜|鏡|jìng|mirror|镜子|鏡子|jìng zi|mirror
映|映|yìng|reflect|反映|反映|fǎn yìng|reflect
泥|泥|ní|mud|泥土|泥土|ní tǔ|mud
铺|鋪|pū|spread|铺开|鋪開|pū kāi|spread out
晶|晶|jīng|crystal|水晶|水晶|shuǐ jīng|crystal
紧|緊|jǐn|tight|紧张|緊張|jǐn zhāng|nervous
院|院|yuàn|yard|医院|醫院|yī yuàn|hospital
除|除|chú|remove|除了|除了|chú le|except
纷|紛|fēn|chaotic|纷纷|紛紛|fēn fēn|one after another
仙|仙|xiān|immortal|仙人|仙人|xiān rén|immortal
卡|卡|kǎ|card|卡片|卡片|kǎ piàn|card
趣|趣|qù|interest|有趣|有趣|yǒu qù|interesting
味|味|wèi|flavor|味道|味道|wèi dào|taste
带|帶|dài|carry|带来|帶來|dài lái|bring
领|領|lǐng|lead|领导|領導|lǐng dǎo|leader
实|實|shí|real|实际|實際|shí jì|reality
考|考|kǎo|test|考试|考試|kǎo shì|exam
试|試|shì|try|考试|考試|kǎo shì|exam
验|驗|yàn|verify|经验|經驗|jīng yàn|experience
证|證|zhèng|prove|证明|證明|zhèng míng|prove
约|約|yuē|approximately|大约|大約|dà yuē|approximately
省|省|shěng|province|省钱|省錢|shěng qián|save money
差|差|chà|differ|差别|差別|chā bié|difference
阻|阻|zǔ|block|阻止|阻止|zǔ zhǐ|prevent
末|末|mò|end|末尾|末尾|mò wěi|end
初|初|chū|beginning|初始|初始|chū shǐ|initial
沿|沿|yán|along|沿着|沿著|yán zhe|along
镜|鏡|jìng|mirror|眼镜|眼鏡|yǎn jìng|glasses
永|永|yǒng|forever|永远|永遠|yǒng yuǎn|forever
望|望|wàng|hope|希望|希望|xī wàng|hope
算|算|suàn|calculate|计算|計算|jì suàn|calculate
蒜|蒜|suàn|garlic|大蒜|大蒜|dà suàn|garlic
寒|寒|hán|cold|寒冷|寒冷|hán lěng|cold
雀|雀|què|sparrow|麻雀|麻雀|má què|sparrow
郎|郎|láng|young man|新郎|新郎|xīn láng|groom
概|概|gài|general|大概|大概|dà gài|probably
柴|柴|chái|firewood|柴火|柴火|chái huo|firewood
煮|煮|zhǔ|boil|煮饭|煮飯|zhǔ fàn|cook rice
材|材|cái|material|材料|材料|cái liào|material
纪|紀|jì|era|世纪|世紀|shì jì|century
系|系|xì|system|关系|關係|guān xi|relationship
修|修|xiū|repair|修理|修理|xiū lǐ|repair
宝|寶|bǎo|treasure|宝贝|寶貝|bǎo bèi|baby
趁|趁|chèn|take advantage|趁早|趁早|chèn zǎo|as soon as possible
设|設|shè|set up|建设|建設|jiàn shè|build
兵|兵|bīng|soldier|士兵|士兵|shì bīng|soldier
守|守|shǒu|guard|守护|守護|shǒu hù|protect
朝|朝|cháo|dynasty|朝代|朝代|cháo dài|dynasty
形|形|xíng|form|形成|形成|xíng chéng|form
状|狀|zhuàng|shape|形状|形狀|xíng zhuàng|shape
切|切|qiē|cut|亲切|親切|qīn qiè|cordial
转|轉|zhuǎn|turn|转弯|轉彎|zhuǎn wān|turn
速|速|sù|fast|速度|速度|sù dù|speed
度|度|dù|degree|温度|溫度|wēn dù|temperature
配|配|pèi|match|搭配|搭配|dā pèi|match
达|達|dá|reach|到达|到達|dào dá|arrive
退|退|tuì|retreat|退后|退後|tuì hòu|step back
择|擇|zé|choose|选择|選擇|xuǎn zé|choose
秘|秘|mì|secret|秘密|秘密|mì mì|secret
退|退|tuì|step back|后退|後退|hòu tuì|retreat
际|際|jì|border|国际|國際|guó jì|international
陆|陸|lù|land|大陆|大陸|dà lù|mainland
奋|奮|fèn|strive|奋斗|奮鬥|fèn dòu|struggle
"""

GRADE4_NEW = """
暮|暮|mù|dusk|日暮|日暮|rì mù|sunset
吟|吟|yín|chant|吟诗|吟詩|yín shī|chant poetry
瑟|瑟|sè|zither|萧瑟|蕭瑟|xiāo sè|bleak
题|題|tí|topic|题目|題目|tí mù|title
侧|側|cè|side|侧面|側面|cè miàn|side
峰|峰|fēng|peak|山峰|山峰|shān fēng|peak
庐|廬|lú|hut|庐山|廬山|lú shān|Mount Lu
缘|緣|yuán|fate|缘分|緣分|yuán fèn|fate
降|降|jiàng|descend|下降|下降|xià jiàng|descend
费|費|fèi|cost|费用|費用|fèi yòng|cost
须|須|xū|must|必须|必須|bì xū|must
逊|遜|xùn|modest|谦逊|謙遜|qiān xùn|modest
输|輸|shū|transport|输出|輸出|shū chū|output
茂|茂|mào|lush|茂盛|茂盛|mào shèng|lush
盛|盛|shèng|flourishing|盛开|盛開|shèng kāi|bloom
仿|仿|fǎng|imitate|模仿|模仿|mó fǎng|imitate
佛|佛|fó|Buddha|佛教|佛教|fó jiào|Buddhism
泰|泰|tài|peaceful|泰山|泰山|tài shān|Mount Tai
笨|笨|bèn|clumsy|笨蛋|笨蛋|bèn dàn|fool
枝|枝|zhī|branch|树枝|樹枝|shù zhī|branch
株|株|zhū|trunk|植株|植株|zhí zhū|plant
踏|踏|tà|step|踏步|踏步|tà bù|march
铺|鋪|pù|shop|店铺|店鋪|diàn pù|shop
泛|泛|fàn|float|广泛|廣泛|guǎng fàn|extensive
尽|盡|jìn|exhaust|尽力|盡力|jìn lì|do one's best
绵|綿|mián|continuous|连绵|連綿|lián mián|continuous
梢|梢|shāo|tip|树梢|樹梢|shù shāo|treetop
翁|翁|wēng|old man|老翁|老翁|lǎo wēng|old man
锐|銳|ruì|sharp|尖锐|尖銳|jiān ruì|sharp
录|錄|lù|record|记录|記錄|jì lù|record
漫|漫|màn|overflow|浪漫|浪漫|làng màn|romantic
砖|磚|zhuān|brick|砖头|磚頭|zhuān tou|brick
隔|隔|gé|separate|隔开|隔開|gé kāi|separate
链|鏈|liàn|chain|项链|項鏈|xiàng liàn|necklace
寺|寺|sì|temple|寺庙|寺廟|sì miào|temple
狂|狂|kuáng|crazy|疯狂|瘋狂|fēng kuáng|crazy
吠|吠|fèi|bark|犬吠|犬吠|quǎn fèi|dog bark
篇|篇|piān|chapter|篇章|篇章|piān zhāng|chapter
荐|薦|jiàn|recommend|推荐|推薦|tuī jiàn|recommend
翻|翻|fān|flip|翻转|翻轉|fān zhuǎn|flip
栏|欄|lán|railing|栏杆|欄杆|lán gān|railing
序|序|xù|order|顺序|順序|shùn xù|order
免|免|miǎn|exempt|免费|免費|miǎn fèi|free
恋|戀|liàn|love|恋爱|戀愛|liàn ài|love
陪|陪|péi|accompany|陪伴|陪伴|péi bàn|accompany
趟|趟|tàng|trip (MW)|一趟|一趟|yī tàng|one trip
敢|敢|gǎn|dare|勇敢|勇敢|yǒng gǎn|brave
惨|慘|cǎn|miserable|惨烈|慘烈|cǎn liè|tragic
败|敗|bài|defeat|失败|失敗|shī bài|fail
缺|缺|quē|lack|缺少|缺少|quē shǎo|lack
劣|劣|liè|inferior|恶劣|惡劣|è liè|bad
维|維|wéi|maintain|维护|維護|wéi hù|maintain
财|財|cái|wealth|财富|財富|cái fù|wealth
属|屬|shǔ|belong|属于|屬於|shǔ yú|belong to
余|餘|yú|surplus|剩余|剩餘|shèng yú|surplus
械|械|xiè|tool|机械|機械|jī xiè|machinery
杰|傑|jié|outstanding|杰出|傑出|jié chū|outstanding
摧|摧|cuī|destroy|摧毁|摧毀|cuī huǐ|destroy
谨|謹|jǐn|careful|谨慎|謹慎|jǐn shèn|cautious
慧|慧|huì|intelligent|智慧|智慧|zhì huì|wisdom
贡|貢|gòng|tribute|贡献|貢獻|gòng xiàn|contribute
宪|憲|xiàn|constitution|宪法|憲法|xiàn fǎ|constitution
恼|惱|nǎo|annoyed|烦恼|煩惱|fán nǎo|worry
悲|悲|bēi|sad|悲伤|悲傷|bēi shāng|sad
戚|戚|qī|relative|亲戚|親戚|qīn qi|relative
欺|欺|qī|bully|欺负|欺負|qī fu|bully
负|負|fù|lose|负责|負責|fù zé|responsible
仇|仇|chóu|enemy|仇恨|仇恨|chóu hèn|hatred
赏|賞|shǎng|reward|欣赏|欣賞|xīn shǎng|appreciate
吊|吊|diào|hang|吊灯|吊燈|diào dēng|chandelier
探|探|tàn|explore|探索|探索|tàn suǒ|explore
牌|牌|pái|sign|招牌|招牌|zhāo pái|signboard
末|末|mò|end|末尾|末尾|mò wěi|ending
拥|擁|yōng|embrace|拥抱|擁抱|yōng bào|embrace
唤|喚|huàn|call|呼唤|呼喚|hū huàn|call
饲|飼|sì|feed|饲养|飼養|sì yǎng|raise
猪|豬|zhū|pig|猪肉|豬肉|zhū ròu|pork
据|據|jù|according|根据|根據|gēn jù|according to
某|某|mǒu|certain|某人|某人|mǒu rén|someone
蛇|蛇|shé|snake|毒蛇|毒蛇|dú shé|poisonous snake
猛|猛|měng|fierce|凶猛|兇猛|xiōng měng|ferocious
逃|逃|táo|escape|逃跑|逃跑|táo pǎo|escape
啸|嘯|xiào|roar|呼啸|呼嘯|hū xiào|howl
型|型|xíng|type|类型|類型|lèi xíng|type
任|任|rèn|appoint|任务|任務|rèn wu|task
务|務|wù|affair|任务|任務|rèn wu|task
乎|乎|hū|particle|几乎|幾乎|jī hū|almost
腰|腰|yāo|waist|腰带|腰帶|yāo dài|belt
捡|撿|jiǎn|pick up|捡起|撿起|jiǎn qǐ|pick up
颗|顆|kē|grain (MW)|一颗|一顆|yī kē|one (grain)
纯|純|chún|pure|纯洁|純潔|chún jié|pure
磅|磅|bàng|pound|磅秤|磅秤|bàng chèng|scale
拖|拖|tuō|drag|拖延|拖延|tuō yán|delay
释|釋|shì|explain|解释|解釋|jiě shì|explain
越|越|yuè|surpass|越来越|越來越|yuè lái yuè|more and more
鼓|鼓|gǔ|drum|鼓励|鼓勵|gǔ lì|encourage
励|勵|lì|encourage|鼓励|鼓勵|gǔ lì|encourage
曾|曾|céng|once|曾经|曾經|céng jīng|once
尊|尊|zūn|respect|尊重|尊重|zūn zhòng|respect
改|改|gǎi|change|改变|改變|gǎi biàn|change
粉|粉|fěn|powder|粉色|粉色|fěn sè|pink
握|握|wò|hold|握手|握手|wò shǒu|shake hands
暴|暴|bào|violent|暴风|暴風|bào fēng|storm
即|即|jí|immediately|即使|即使|jí shǐ|even if
柔|柔|róu|soft|柔软|柔軟|róu ruǎn|soft
荒|荒|huāng|waste|荒野|荒野|huāng yě|wilderness
罚|罰|fá|punish|惩罚|懲罰|chéng fá|punish
惩|懲|chéng|punish|惩罚|懲罰|chéng fá|punish
踪|蹤|zōng|trace|踪迹|蹤跡|zōng jì|trace
毕|畢|bì|finish|毕业|畢業|bì yè|graduate
零|零|líng|zero|零食|零食|líng shí|snacks
棍|棍|gùn|stick|木棍|木棍|mù gùn|wooden stick
颠|顛|diān|top|颠倒|顛倒|diān dǎo|upside down
"""

GRADE5_NEW = """
侵|侵|qīn|invade|侵略|侵略|qīn lüè|invade
略|略|lüè|strategy|策略|策略|cè lüè|strategy
筝|箏|zhēng|kite|风筝|風箏|fēng zhēng|kite
瞻|瞻|zhān|look up|瞻仰|瞻仰|zhān yǎng|look up to
姿|姿|zī|posture|姿态|姿態|zī tài|posture
态|態|tài|attitude|态度|態度|tài du|attitude
恩|恩|ēn|grace|恩情|恩情|ēn qíng|grace
惠|惠|huì|favor|恩惠|恩惠|ēn huì|favor
移|移|yí|move|移动|移動|yí dòng|move
谋|謀|móu|scheme|计谋|計謀|jì móu|plot
臣|臣|chén|minister|大臣|大臣|dà chén|minister
妒|妒|dù|jealous|嫉妒|嫉妒|jí dù|jealous
忌|忌|jì|taboo|忌讳|忌諱|jì huì|taboo
曹|曹|cáo|surname Cao|曹操|曹操|cáo cāo|Cao Cao
督|督|dū|supervise|监督|監督|jiān dū|supervise
委|委|wěi|entrust|委屈|委屈|wěi qū|wronged
惩|懲|chéng|punish|惩罚|懲罰|chéng fá|punish
详|詳|xiáng|detailed|详细|詳細|xiáng xì|detailed
审|審|shěn|examine|审查|審查|shěn chá|examine
拟|擬|nǐ|draft|模拟|模擬|mó nǐ|simulate
筹|籌|chóu|plan|筹备|籌備|chóu bèi|prepare
措|措|cuò|arrange|措施|措施|cuò shī|measure
燃|燃|rán|burn|燃烧|燃燒|rán shāo|burn
漆|漆|qī|paint|油漆|油漆|yóu qī|paint
忠|忠|zhōng|loyal|忠诚|忠誠|zhōng chéng|loyal
隶|隸|lì|subordinate|隶书|隸書|lì shū|clerical script
奴|奴|nú|slave|奴隶|奴隸|nú lì|slave
缚|縛|fù|bind|束缚|束縛|shù fù|bind
罢|罷|bà|stop|罢工|罷工|bà gōng|strike
政|政|zhèng|politics|政治|政治|zhèng zhì|politics
克|克|kè|gram; overcome|克服|克服|kè fú|overcome
膊|膊|bó|arm|胳膊|胳膊|gē bo|arm
厉|厲|lì|severe|厉害|厲害|lì hai|amazing
粱|粱|liáng|sorghum|高粱|高粱|gāo liáng|sorghum
辩|辯|biàn|debate|辩论|辯論|biàn lùn|debate
哀|哀|āi|grief|悲哀|悲哀|bēi āi|grief
伦|倫|lún|ethics|伦理|倫理|lún lǐ|ethics
绞|絞|jiǎo|twist|绞痛|絞痛|jiǎo tòng|colic
牺|犧|xī|sacrifice|牺牲|犧牲|xī shēng|sacrifice
牲|牲|shēng|sacrifice|牺牲|犧牲|xī shēng|sacrifice
役|役|yì|service|战役|戰役|zhàn yì|battle
冠|冠|guān|crown|皇冠|皇冠|huáng guān|crown
咆|咆|páo|roar|咆哮|咆哮|páo xiào|roar
哮|哮|xiào|pant|哮喘|哮喘|xiào chuǎn|asthma
狞|獰|níng|ferocious|狰狞|猙獰|zhēng níng|hideous
嗓|嗓|sǎng|throat|嗓子|嗓子|sǎng zi|throat
淌|淌|tǎng|flow|流淌|流淌|liú tǎng|flow
瞪|瞪|dèng|stare|瞪眼|瞪眼|dèng yǎn|stare
膛|膛|táng|chest|胸膛|胸膛|xiōng táng|chest
搏|搏|bó|fight|搏斗|搏鬥|bó dòu|fight
仇|仇|chóu|hatred|仇恨|仇恨|chóu hèn|hatred
葬|葬|zàng|bury|埋葬|埋葬|mái zàng|bury
诞|誕|dàn|birth|诞生|誕生|dàn shēng|birth
寿|壽|shòu|longevity|长寿|長壽|cháng shòu|longevity
辰|辰|chén|time|时辰|時辰|shí chén|time
悔|悔|huǐ|regret|后悔|後悔|hòu huǐ|regret
朽|朽|xiǔ|rotten|腐朽|腐朽|fǔ xiǔ|rotten
挽|挽|wǎn|pull|挽救|挽救|wǎn jiù|rescue
蹄|蹄|tí|hoof|马蹄|馬蹄|mǎ tí|hoof
腮|腮|sāi|cheek|腮红|腮紅|sāi hóng|blush
殖|殖|zhí|breed|繁殖|繁殖|fán zhí|breed
抵|抵|dǐ|resist|抵抗|抵抗|dǐ kàng|resist
御|御|yù|defend|防御|防禦|fáng yù|defend
侮|侮|wǔ|insult|侮辱|侮辱|wǔ rǔ|insult
辱|辱|rǔ|insult|侮辱|侮辱|wǔ rǔ|insult
殴|毆|ōu|beat|殴打|毆打|ōu dǎ|beat
瞅|瞅|chǒu|glance|瞅见|瞅見|chǒu jiàn|catch sight of
膘|膘|biāo|fat|膘肥|膘肥|biāo féi|plump
驹|駒|jū|colt|马驹|馬駒|mǎ jū|colt
钮|鈕|niǔ|button|按钮|按鈕|àn niǔ|button
衫|衫|shān|shirt|衬衫|襯衫|chèn shān|shirt
毙|斃|bì|kill|击毙|擊斃|jī bì|shoot dead
嫌|嫌|xián|suspect|嫌疑|嫌疑|xián yí|suspect
匪|匪|fěi|bandit|土匪|土匪|tǔ fěi|bandit
窑|窯|yáo|kiln|砖窑|磚窯|zhuān yáo|brick kiln
泊|泊|bó|moor|停泊|停泊|tíng bó|anchor
聋|聾|lóng|deaf|聋哑|聾啞|lóng yǎ|deaf-mute
眶|眶|kuàng|eye socket|眼眶|眼眶|yǎn kuàng|eye socket
搁|擱|gē|put|搁置|擱置|gē zhì|shelve
瞧|瞧|qiáo|look|瞧见|瞧見|qiáo jiàn|catch sight of
割|割|gē|cut|割草|割草|gē cǎo|mow grass
慰|慰|wèi|comfort|安慰|安慰|ān wèi|comfort
梁|梁|liáng|beam|桥梁|橋梁|qiáo liáng|bridge
惶|惶|huáng|panic|惊惶|驚惶|jīng huáng|panicked
歉|歉|qiàn|apology|道歉|道歉|dào qiàn|apologize
"""

GRADE6_NEW = """
拘|拘|jū|restrain|拘束|拘束|jū shù|constrained
绽|綻|zhàn|crack|绽放|綻放|zhàn fàng|bloom
雅|雅|yǎ|elegant|优雅|優雅|yōu yǎ|elegant
甚|甚|shèn|very|甚至|甚至|shèn zhì|even
拘|拘|jū|detain|拘留|拘留|jū liú|detain
幸|幸|xìng|fortunate|幸福|幸福|xìng fú|happiness
蒙|蒙|méng|cover|蒙古|蒙古|méng gǔ|Mongolia
宣|宣|xuān|declare|宣布|宣佈|xuān bù|announce
诞|誕|dàn|birth|圣诞|聖誕|shèng dàn|Christmas
哄|哄|hǒng|coax|哄骗|哄騙|hǒng piàn|deceive
骗|騙|piàn|cheat|骗人|騙人|piàn rén|cheat
僻|僻|pì|remote|偏僻|偏僻|piān pì|remote
寞|寞|mò|lonely|寂寞|寂寞|jì mò|lonely
寂|寂|jì|lonely|寂寞|寂寞|jì mò|lonely
衷|衷|zhōng|sincere|由衷|由衷|yóu zhōng|heartfelt
歧|歧|qí|diverge|歧视|歧視|qí shì|discriminate
谓|謂|wèi|say|所谓|所謂|suǒ wèi|so-called
笼|籠|lóng|cage|鸟笼|鳥籠|niǎo lóng|birdcage
罩|罩|zhào|cover|笼罩|籠罩|lǒng zhào|envelop
幻|幻|huàn|illusion|幻想|幻想|huàn xiǎng|fantasy
洋|洋|yáng|ocean|海洋|海洋|hǎi yáng|ocean
绘|繪|huì|draw|绘画|繪畫|huì huà|painting
润|潤|rùn|moist|湿润|濕潤|shī rùn|moist
凝|凝|níng|congeal|凝固|凝固|níng gù|solidify
辣|辣|là|spicy|辣椒|辣椒|là jiāo|chili pepper
仪|儀|yí|instrument|仪器|儀器|yí qì|instrument
棠|棠|táng|crabapple|海棠|海棠|hǎi táng|crabapple
迁|遷|qiān|move|迁移|遷移|qiān yí|migrate
惰|惰|duò|lazy|懒惰|懶惰|lǎn duò|lazy
糊|糊|hú|paste|糊涂|糊塗|hú tu|confused
凄|淒|qī|miserable|凄凉|淒涼|qī liáng|desolate
斥|斥|chì|scold|排斥|排斥|pái chì|reject
绷|繃|bēng|stretch|绷带|繃帶|bēng dài|bandage
搂|摟|lǒu|hug|搂住|摟住|lǒu zhù|hold
瞬|瞬|shùn|instant|瞬间|瞬間|shùn jiān|instant
颤|顫|chàn|tremble|颤抖|顫抖|chàn dǒu|tremble
吻|吻|wěn|kiss|亲吻|親吻|qīn wěn|kiss
泰|泰|tài|peaceful|泰然|泰然|tài rán|calm
嫁|嫁|jià|marry|出嫁|出嫁|chū jià|marry out
搅|攪|jiǎo|stir|搅拌|攪拌|jiǎo bàn|stir
拧|擰|nǐng|twist|拧干|擰乾|nǐng gān|wring dry
甸|甸|diàn|suburb|缅甸|緬甸|miǎn diàn|Myanmar
绢|絹|juàn|silk|手绢|手絹|shǒu juàn|handkerchief
忐|忐|tǎn|uneasy|忐忑|忐忑|tǎn tè|nervous
忑|忑|tè|uneasy|忐忑|忐忑|tǎn tè|nervous
曰|曰|yuē|say (classical)|子曰|子曰|zǐ yuē|the Master said
岳|岳|yuè|high mountain|五岳|五岳|wǔ yuè|Five Sacred Mountains
摩|摩|mó|rub|摩擦|摩擦|mó cā|friction
遮|遮|zhē|cover|遮挡|遮擋|zhē dǎng|block
咏|詠|yǒng|chant|歌咏|歌詠|gē yǒng|chant
侣|侶|lǚ|companion|伴侣|伴侶|bàn lǚ|companion
拨|撥|bō|dial|拨打|撥打|bō dǎ|dial
忧|憂|yōu|worry|忧虑|憂慮|yōu lǜ|worry
焰|焰|yàn|flame|火焰|火焰|huǒ yàn|flame
缰|韁|jiāng|reins|缰绳|韁繩|jiāng shéng|reins
驰|馳|chí|gallop|飞驰|飛馳|fēi chí|gallop
惫|憊|bèi|exhausted|疲惫|疲憊|pí bèi|exhausted
鞍|鞍|ān|saddle|马鞍|馬鞍|mǎ ān|saddle
疆|疆|jiāng|border|新疆|新疆|xīn jiāng|Xinjiang
策|策|cè|plan|策略|策略|cè lüè|strategy
拯|拯|zhěng|save|拯救|拯救|zhěng jiù|save
颁|頒|bān|promulgate|颁发|頒發|bān fā|award
奠|奠|diàn|establish|奠基|奠基|diàn jī|lay foundation
揪|揪|jiū|pull|揪心|揪心|jiū xīn|worried
喧|喧|xuān|noisy|喧闹|喧鬧|xuān nào|noisy
腻|膩|nì|greasy|油腻|油膩|yóu nì|greasy
轰|轟|hōng|boom|轰动|轟動|hōng dòng|sensation
妨|妨|fáng|hinder|妨碍|妨礙|fáng ài|hinder
绞|絞|jiǎo|twist|绞尽|絞盡|jiǎo jìn|rack (brains)
玫|玫|méi|rose|玫瑰|玫瑰|méi gui|rose
瑰|瑰|guī|precious|玫瑰|玫瑰|méi gui|rose
拢|攏|lǒng|gather|聚拢|聚攏|jù lǒng|gather
仆|僕|pú|servant|仆人|僕人|pú rén|servant
旬|旬|xún|ten days|上旬|上旬|shàng xún|first ten days
援|援|yuán|aid|支援|支援|zhī yuán|support
肆|肆|sì|unbridled|放肆|放肆|fàng sì|presumptuous
虐|虐|nüè|cruel|虐待|虐待|nüè dài|mistreat
吏|吏|lì|official|官吏|官吏|guān lì|official
崩|崩|bēng|collapse|崩塌|崩塌|bēng tā|collapse
泽|澤|zé|marsh|沼泽|沼澤|zhǎo zé|swamp
盈|盈|yíng|full|充盈|充盈|chōng yíng|full
裸|裸|luǒ|bare|裸露|裸露|luǒ lù|exposed
寇|寇|kòu|invader|敌寇|敵寇|dí kòu|invader
棺|棺|guān|coffin|棺材|棺材|guān cai|coffin
劫|劫|jié|rob|抢劫|搶劫|qiǎng jié|rob
"""

def parse_data(data_str, grade):
    """Parse pipe-delimited character data into entry dicts."""
    entries = []
    for line in data_str.strip().split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) != 8:
            print(f"  WARNING: skipping malformed line: {line}")
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
    # Load existing characters
    with open(CHARS_PATH, encoding="utf-8") as f:
        existing = json.load(f)

    existing_chars = {c["simplified"] for c in existing}
    print(f"Existing characters: {len(existing_chars)}")

    # Parse new character data
    new_data = [
        (1, GRADE1_NEW),
        (2, GRADE2_NEW),
        (3, GRADE3_NEW),
        (4, GRADE4_NEW),
        (5, GRADE5_NEW),
        (6, GRADE6_NEW),
    ]

    added = 0
    for grade, data_str in new_data:
        entries = parse_data(data_str, grade)
        grade_added = 0
        for entry in entries:
            if entry["simplified"] not in existing_chars:
                existing_chars.add(entry["simplified"])
                # Assign orderInGrade based on current count for this grade
                grade_entries = [c for c in existing if c["gradeLevel"] == grade]
                entry["orderInGrade"] = len(grade_entries) + grade_added
                existing.append(entry)
                grade_added += 1
                added += 1
        print(f"  Grade {grade}: added {grade_added} new characters")

    # Sort by grade, then orderInGrade
    existing.sort(key=lambda c: (c["gradeLevel"], c.get("orderInGrade", 0)))

    # Write output
    with open(CHARS_PATH, "w", encoding="utf-8") as f:
        json.dump(existing, f, ensure_ascii=False, indent=2)

    print(f"\nTotal characters now: {len(existing)}")
    for g in range(1, 7):
        count = sum(1 for c in existing if c["gradeLevel"] == g)
        print(f"  Grade {g}: {count}")


if __name__ == "__main__":
    main()
