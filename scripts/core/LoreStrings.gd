extends RefCounted
class_name LoreStrings
## Encyclopedia text for every species and equipment item, in English and Hebrew. Kept apart
## from autoload/Localization.gd (UI strings) because it is by far the bulk of the game's
## writing. Localization folds these into its table at startup as the keys:
##   sp_<id> (name), desc_sp_<id> (one-line shop blurb), origin_sp_<id> (where in the world),
##   lore_sp_<id> (the encyclopedia overview);  eq_<id>, desc_eq_<id>, lore_eq_<id>.
## Every entry is [english, hebrew].

const SPECIES := {
	# ------------------------------------------------------------------ freshwater
	"guppy": {
		"name": ["Guppy", "גופי"],
		"short": ["Tiny, colourful and famously easy to breed. The classic first fish.", "קטן, צבעוני ומתרבה בקלות מפורסמת. הדג הראשון הקלאסי."],
		"origin": ["North-eastern South America: Venezuela, Guyana, Trinidad and Tobago", "צפון-מזרח דרום אמריקה: ונצואלה, גיאנה, טרינידד וטובגו"],
		"lore": [
			"The guppy is named after Robert Guppy, a naturalist who sent specimens from Trinidad to the British Museum in 1866. It is a livebearer: instead of laying eggs the female gives birth to fully formed, swimming fry, and she can store sperm and deliver several broods from a single mating. That is why it earned the nickname \"millionfish\". Guppies have been released all over the world to eat mosquito larvae, and no two males carry exactly the same tail pattern.",
			"הגופי קרוי על שם רוברט גופי, חוקר טבע ששלח פרטים מטרינידד למוזיאון הבריטי ב-1866. זהו דג משריץ: במקום להטיל ביצים הנקבה ממליטה דגיגים שלמים ששוחים מיד, והיא יכולה לאגור זרע ולהמליט כמה פעמים מהזדווגות אחת. בזכות זה הוא זכה לכינוי \"דג המיליונים\". גופים שוחררו בכל העולם כדי לאכול זחלי יתושים, ואין שני זכרים עם דוגמת זנב זהה לגמרי.",
		],
	},
	"platy": {
		"name": ["Platy", "פלאטי"],
		"short": ["A cheerful, chunky livebearer in many colours. One step up from the guppy.", "דג משריץ עגלגל ועליז במגוון צבעים. צעד אחד מעל הגופי."],
		"origin": ["Central America: the Atlantic slope of Mexico, Belize and Guatemala", "מרכז אמריקה: החוף האטלנטי של מקסיקו, בליז וגואטמלה"],
		"lore": [
			"In the wild the platy is a modest olive-coloured fish of warm ditches, springs and slow streams. Almost every colour you see in shops — sunset red, blue, the \"Mickey Mouse\" mark on the tail — was created by breeders over the last century. It is a close cousin of the swordtail and the two can interbreed. Platies have also served medicine: hybrids of the two species helped researchers study how skin cancer develops.",
			"בטבע הפלאטי הוא דג צנוע בגוון זית, שחי בתעלות חמות, מעיינות ונחלים איטיים. כמעט כל צבע שרואים בחנויות — אדום שקיעה, כחול, סימן ה\"מיקי מאוס\" שעל הזנב — נוצר בידי מגדלים במאה השנים האחרונות. הוא קרוב משפחה של הסייפן והשניים יכולים להתרבות זה עם זה. הפלאטי תרם גם לרפואה: בני כלאיים של שני המינים עזרו לחוקרים להבין איך מתפתח סרטן העור.",
		],
	},
	"molly": {
		"name": ["Molly", "מולי"],
		"short": ["A bigger, tougher livebearer that wants more room than a guppy.", "דג משריץ גדול וחסון יותר, שצריך יותר מקום מגופי."],
		"origin": ["Mexico to Colombia, in rivers, lagoons and coastal swamps", "ממקסיקו ועד קולומביה, בנהרות, לגונות וביצות חוף"],
		"lore": [
			"Mollies are among the most adaptable aquarium fish: in nature they live in fresh water, in brackish river mouths and even in the sea. The velvety jet-black molly does not exist in the wild — it is a variety that breeders perfected in the 1930s. Like guppies they give birth to live young, sometimes dozens at a time. They spend much of the day grazing algae off rocks and leaves.",
			"המולי הוא מדגי האקווריום הסתגלנים ביותר: בטבע הוא חי במים מתוקים, בשפכי נהרות מליחים ואפילו בים. המולי השחור הקטיפתי אינו קיים בטבע — זהו זן שמגדלים שכללו בשנות ה-30. כמו הגופי הוא ממליט דגיגים חיים, לפעמים עשרות בבת אחת. חלק גדול מהיום הוא מבלה בליחוך אצות מסלעים ומעלים.",
		],
	},
	"neon_tetra": {
		"name": ["Neon Tetra", "טטרה ניאון"],
		"short": ["A small schooling fish with a glowing blue stripe. Keep six or more.", "דג להקה קטן עם פס כחול זוהר. להחזיק שישה ומעלה."],
		"origin": ["The western Amazon basin: Peru, Colombia and Brazil", "מערב אגן האמזונס: פרו, קולומביה וברזיל"],
		"lore": [
			"The neon tetra comes from shaded forest streams whose water is stained dark like tea by fallen leaves. Its blue stripe is not pigment but tiny reflective crystals, which helps the school keep sight of each other in the gloom; at night the stripe fades and the fish \"switches off\". When the first neons reached Europe in 1936 they caused a sensation and sold for a fortune. Today almost all of them are bred on fish farms in Asia.",
			"הטטרה ניאון מגיע מנחלי יער מוצלים, שעלים נושרים צובעים את מימיהם בגוון כהה כמו תה. הפס הכחול שלו אינו צבען אלא גבישים זעירים מחזירי אור, שעוזרים ללהקה לשמור על קשר עין באפלולית; בלילה הפס דוהה והדג \"נכבה\". כשהניאונים הראשונים הגיעו לאירופה ב-1936 הם עוררו סנסציה ונמכרו בהון. היום כמעט כולם מגודלים בחוות דגים באסיה.",
		],
	},
	"zebra_danio": {
		"name": ["Zebra Danio", "דניו זברה"],
		"short": ["A hardy, tireless striped schooling fish. Keep six or more.", "דג להקה מפוספס, עמיד ובלתי נלאה. להחזיק שישה ומעלה."],
		"origin": ["South Asia: India, Bangladesh and Nepal, in streams and rice paddies", "דרום אסיה: הודו, בנגלדש ונפאל, בנחלים ובשדות אורז"],
		"lore": [
			"This little striped fish is one of the most important animals in modern science. Its embryos are transparent, so researchers can watch a heart or a brain form in real time, and it can regrow damaged heart muscle, fins and even parts of its spinal cord. Thousands of laboratories around the world keep zebra danios. In the aquarium it is nearly indestructible and never seems to stop swimming.",
			"הדג המפוספס הקטן הזה הוא אחד מבעלי החיים החשובים ביותר במדע המודרני. העוברים שלו שקופים, כך שחוקרים יכולים לצפות בלב או במוח נוצרים בזמן אמת, והוא מסוגל לחדש שריר לב פגוע, סנפירים ואפילו חלקים מחוט השדרה. אלפי מעבדות בעולם מחזיקות דגי זברה. באקווריום הוא כמעט בלתי ניתן להריסה ונראה שהוא אף פעם לא מפסיק לשחות.",
		],
	},
	"harlequin_rasbora": {
		"name": ["Harlequin Rasbora", "רסבורה הרלקין"],
		"short": ["A copper schooling fish with a black wedge. Keep six or more.", "דג להקה נחושתי עם משולש שחור. להחזיק שישה ומעלה."],
		"origin": ["South-east Asia: Malaysia, Singapore, Sumatra and southern Thailand", "דרום-מזרח אסיה: מלזיה, סינגפור, סומטרה ודרום תאילנד"],
		"lore": [
			"The harlequin lives in peat-swamp forests, where the water is soft, dark and so acidic that few other fish thrive. The black triangle on its side gives it its name, after the patched costume of the Harlequin clown. Unlike its relatives, which scatter eggs anywhere, a harlequin pair turns upside down and glues its eggs to the underside of a broad leaf. A school moves so tightly that it looks like a single animal.",
			"ההרלקין חי ביערות ביצות כבול, שבהם המים רכים, כהים וחומציים עד כדי כך שמעט דגים אחרים משגשגים בהם. המשולש השחור שעל צדו העניק לו את שמו, על שם תלבושת הטלאים של הליצן הרלקין. בשונה מקרוביו, שמפזרים ביצים בכל מקום, זוג הרלקינים מתהפך ומדביק את הביצים לצד התחתון של עלה רחב. הלהקה נעה צפופה כל כך שהיא נראית כמו בעל חיים אחד.",
		],
	},
	"betta": {
		"name": ["Betta (Siamese Fighting Fish)", "בטא (דג קרב)"],
		"short": ["Spectacular fins and a fierce temper. Males must be kept apart.", "סנפירים מרהיבים ומזג לוהט. זכרים חייבים לחיות בנפרד."],
		"origin": ["Thailand, in rice paddies, canals and shallow marshes", "תאילנד, בשדות אורז, תעלות וביצות רדודות"],
		"lore": [
			"In Thailand the betta was bred for centuries for fighting matches, on which people bet money and even their houses; in 1840 the King of Siam began licensing the fights. Wild bettas are small and dull — the huge flowing fins are the work of breeders. A special \"labyrinth\" organ lets the fish gulp air from the surface, so it survives in puddles with almost no oxygen. The male is a devoted father: he builds a nest of bubbles and guards the eggs alone. It is Thailand's national aquatic animal.",
			"בתאילנד גידלו את הבטא במשך מאות שנים לקרבות, שעליהם הימרו בכסף ואפילו בבתים; ב-1840 מלך סיאם החל להעניק רישיונות לקרבות. דגי הבטא בטבע קטנים ואפרוריים — הסנפירים הענקיים המתנופפים הם פרי עבודתם של מגדלים. איבר מיוחד, ה\"מבוך\", מאפשר לדג לבלוע אוויר מפני המים, ולכן הוא שורד בשלוליות כמעט בלי חמצן. הזכר הוא אב מסור: הוא בונה קן מבועות ושומר לבדו על הביצים. הבטא הוא חיית המים הלאומית של תאילנד.",
		],
	},
	"honey_gourami": {
		"name": ["Honey Gourami", "גוראמי דבש"],
		"short": ["A calm, shy labyrinth fish that glows honey-gold.", "דג מבוך רגוע וביישן, בצבע זהב-דבש."],
		"origin": ["North-eastern India and Bangladesh, in the Ganges and Brahmaputra basins", "צפון-מזרח הודו ובנגלדש, באגני הגנגס והברהמפוטרה"],
		"lore": [
			"The honey gourami lives in overgrown ponds and flooded fields that almost dry up between monsoons. Like the betta it breathes air with a labyrinth organ, and you will see it rise to the surface for a gulp. Its two thread-like belly fins work as feelers, loaded with touch and taste cells, and it gently \"pats\" everything around it. In breeding season the male turns deep honey-orange with a dark blue-black throat.",
			"גוראמי הדבש חי בבריכות עמוסות צמחייה ובשדות מוצפים, שכמעט מתייבשים בין מונסון למונסון. כמו הבטא הוא נושם אוויר בעזרת איבר המבוך, ותראו אותו עולה אל פני המים ללגימה. שני סנפירי הגחון הדקים שלו פועלים כמחושים, עמוסים בתאי מישוש וטעם, והוא \"מלטף\" בעדינות כל דבר סביבו. בעונת הרבייה הזכר נצבע בכתום-דבש עמוק עם גרון כחול-שחור.",
		],
	},
	"cory_catfish": {
		"name": ["Peppered Cory", "קורידורס מנומר"],
		"short": ["A peaceful armoured bottom-dweller. Happiest in a group of three or more.", "דג קרקעית משוריין ושליו. הכי מאושר בקבוצה של שלושה ומעלה."],
		"origin": ["South-eastern South America: Brazil, Uruguay and Argentina", "דרום-מזרח דרום אמריקה: ברזיל, אורוגוואי וארגנטינה"],
		"lore": [
			"The first peppered corys known to science were collected by Charles Darwin himself, during the voyage of the Beagle in the 1830s. Instead of scales the cory wears two rows of bony plates, like a suit of armour. It rummages in the sand with its sensitive whiskers, and every so often dashes to the surface for a gulp of air, which it absorbs through its gut. Corys are among the few fish that seem to \"wink\" — they can roll their eyes downward.",
			"דגי הקורידורס המנומרים הראשונים שהכיר המדע נאספו בידי צ'רלס דרווין בכבודו ובעצמו, במסע הביגל בשנות ה-30 של המאה ה-19. במקום קשקשים לובש הקורידורס שתי שורות של לוחות עצם, כמו שריון. הוא מחטט בחול בעזרת שפמים רגישים, ומדי פעם מזנק אל פני המים ללגימת אוויר, שאותה הוא סופג דרך המעי. הקורידורס הוא מהדגים הבודדים שנראים כאילו הם \"קורצים\" — הם יכולים לגלגל את העיניים כלפי מטה.",
		],
	},
	"cherry_shrimp": {
		"name": ["Cherry Shrimp", "שרימפס דובדבן"],
		"short": ["A tiny red algae-eater that breeds readily. A nice side income.", "אוכל אצות אדום וזעיר שמתרבה בקלות. הכנסה צדדית נחמדה."],
		"origin": ["Taiwan", "טייוואן"],
		"lore": [
			"In the streams of Taiwan this shrimp is a transparent brownish-green, almost invisible among the plants. The cherry-red colour appeared in captivity and was strengthened by breeders, generation after generation. The female carries her eggs under her tail for about a month, fanning them constantly with her legs, and the babies hatch as miniature copies of the adults. All day long the shrimp picks at surfaces with tiny pincers, cleaning algae and leftovers.",
			"בנחלי טייוואן השרימפס הזה שקוף בגוון חום-ירקרק, כמעט בלתי נראה בין הצמחים. הצבע האדום-דובדבן הופיע בשבי וחוזק בידי מגדלים, דור אחר דור. הנקבה נושאת את הביצים מתחת לזנבה במשך כחודש ומאווררת אותן ברגליה ללא הפסקה, והצאצאים בוקעים כהעתקים מיניאטוריים של הבוגרים. כל היום השרימפס מלקט בצבתות זעירות מכל משטח, ומנקה אצות ושאריות.",
		],
	},
	"mystery_snail": {
		"name": ["Mystery Snail", "חילזון תפוח"],
		"short": ["A slow, friendly glass-cleaner with a golden shell.", "מנקה זכוכית איטי וחביב עם קונכייה זהובה."],
		"origin": ["South America: the Amazon basin of Brazil, Peru and Bolivia", "דרום אמריקה: אגן האמזונס בברזיל, פרו ובוליביה"],
		"lore": [
			"The mystery snail has both a gill and a lung, so it can breathe under water and from the air. When it wants air it stretches a long tube, the siphon, up to the surface like a snorkel. It can seal itself inside its shell with a hard \"door\" called an operculum. The female climbs out of the water at night and lays a cluster of pink eggs above the waterline, where fish cannot reach them.",
			"לחילזון התפוח יש גם זים וגם ריאה, ולכן הוא נושם גם מתחת למים וגם מהאוויר. כשהוא רוצה אוויר הוא מותח צינור ארוך, סיפון, אל פני המים כמו שנורקל. הוא יכול לנעול את עצמו בתוך הקונכייה בעזרת \"דלת\" קשה שנקראת מכסה. הנקבה מטפסת בלילה אל מחוץ למים ומטילה אשכול ביצים ורודות מעל קו המים, במקום שהדגים לא מגיעים אליו.",
		],
	},
	"cardinal_tetra": {
		"name": ["Cardinal Tetra", "טטרה קרדינל"],
		"short": ["The neon's bigger, redder cousin. Keep six or more.", "בן הדוד הגדול והאדום יותר של הניאון. להחזיק שישה ומעלה."],
		"origin": ["The Rio Negro and upper Orinoco: Brazil, Colombia and Venezuela", "הריו נגרו והאורינוקו העליון: ברזיל, קולומביה וונצואלה"],
		"lore": [
			"The cardinal is named after the scarlet robes of Catholic cardinals. Unlike most aquarium fish it is still caught in the wild: around the Brazilian town of Barcelos, thousands of families make their living collecting cardinals by canoe. Because the fishery only works while the forest is standing, conservationists there use the slogan \"buy a fish, save a tree\". In the wild most cardinals live barely a year, but in an aquarium they can reach five.",
			"הקרדינל קרוי על שם גלימות השני של החשמנים הקתולים. בשונה מרוב דגי האקווריום הוא עדיין נתפס בטבע: סביב העיירה הברזילאית ברסלוס, אלפי משפחות מתפרנסות מאיסוף קרדינלים בסירות קאנו. מאחר שהדיג הזה אפשרי רק כל עוד היער עומד, שומרי הטבע שם משתמשים בסיסמה \"קנה דג, הצל עץ\". בטבע רוב הקרדינלים חיים בקושי שנה, אבל באקווריום הם יכולים להגיע לחמש.",
		],
	},
	"tiger_barb": {
		"name": ["Tiger Barb", "ברבוס טיגריסי"],
		"short": ["A lively, cheeky striped schooler that nips fins. Keep six or more.", "דג להקה מפוספס, נמרץ וחצוף שנוגס בסנפירים. להחזיק שישה ומעלה."],
		"origin": ["Indonesia: the islands of Sumatra and Borneo", "אינדונזיה: האיים סומטרה ובורנאו"],
		"lore": [
			"The tiger barb is the troublemaker of the community tank, famous for nipping the long fins of slower fish. The trick is to keep a large group: then the barbs are busy all day chasing and sparring with each other and leave everyone else alone. When resting, the whole school hangs motionless with heads tilted down, as if sulking. Males show off with a bright red nose.",
			"הברבוס הטיגריסי הוא עושה הצרות של האקווריום, ומפורסם בכך שהוא נוגס בסנפירים הארוכים של דגים איטיים. הסוד הוא להחזיק קבוצה גדולה: אז הברבוסים עסוקים כל היום במרדפים ובהתגוששות זה עם זה, ומניחים לכל השאר. במנוחה כל הלהקה תלויה ללא תנועה כשהראשים נוטים מטה, כאילו נעלבה. הזכרים מתגנדרים באף אדום בוהק.",
		],
	},
	"swordtail": {
		"name": ["Swordtail", "סייפן"],
		"short": ["A sleek livebearer; males carry a long \"sword\" on the tail.", "דג משריץ חטוב; הזכרים נושאים \"חרב\" ארוכה בזנב."],
		"origin": ["Central America: from Veracruz in Mexico to Honduras", "מרכז אמריקה: מוורקרוס שבמקסיקו ועד הונדורס"],
		"lore": [
			"The male's sword is not a weapon at all — it is an ornament. Experiments showed that females prefer males with longer swords, and the sword is one of the classic examples scientists use to study how such decorations evolve. Swordtails are fast, strong swimmers from flowing streams, and excellent jumpers. Like their cousin the platy they bear live young, and the two species cross easily.",
			"החרב של הזכר איננה נשק כלל — היא קישוט. ניסויים הראו שהנקבות מעדיפות זכרים עם חרב ארוכה יותר, והחרב היא אחת הדוגמאות הקלאסיות שבעזרתן מדענים חוקרים איך קישוטים כאלה מתפתחים באבולוציה. הסייפנים הם שחיינים מהירים וחזקים שמגיעים מנחלים זורמים, וגם קופצים מצוינים. כמו בן דודם הפלאטי הם ממליטים דגיגים חיים, ושני המינים מזדווגים בקלות זה עם זה.",
		],
	},
	"kuhli_loach": {
		"name": ["Kuhli Loach", "קולי לואץ׳"],
		"short": ["A striped, eel-like night owl that burrows in the sand. Keep three or more.", "ינשוף לילה מפוספס דמוי צלופח שמתחפר בחול. להחזיק שלושה ומעלה."],
		"origin": ["South-east Asia: Java, Sumatra, Borneo and the Malay Peninsula", "דרום-מזרח אסיה: ג'אווה, סומטרה, בורנאו וחצי האי המלאי"],
		"lore": [
			"The kuhli loach spends the day buried in sand or wedged under a root, with only its whiskered face showing, and comes out at dusk to wriggle across the bottom like a tiny snake. Under each eye it hides a sharp spine that pops out if a predator grabs it. Kuhlis love company and will pile up together in one hiding place. Keepers often report that they become restless and swim up and down the glass when the weather is about to change.",
			"הקולי מבלה את היום קבור בחול או דחוק מתחת לשורש, כשרק פניו המשופמות מציצות, ויוצא עם רדת החשכה להתפתל על הקרקעית כמו נחש זעיר. מתחת לכל עין הוא מסתיר קוץ חד, שנשלף אם טורף תופס אותו. הקולים אוהבים חברה ונערמים יחד במחבוא אחד. מגדלים מספרים לא פעם שהם נעשים חסרי מנוחה ושוחים מעלה ומטה לאורך הזכוכית כשמזג האוויר עומד להשתנות.",
		],
	},
	"amano_shrimp": {
		"name": ["Amano Shrimp", "שרימפס אמאנו"],
		"short": ["The hardest-working algae eater there is. Does not breed in fresh water.", "אוכל האצות החרוץ ביותר שיש. לא מתרבה במים מתוקים."],
		"origin": ["Japan and Taiwan, in streams that run to the sea", "יפן וטייוואן, בנחלים שנשפכים לים"],
		"lore": [
			"This shrimp is named after Takashi Amano, the Japanese photographer and designer who turned planted aquariums into an art form. In the 1980s he discovered that it devours algae like no other animal, and ordered thousands for his underwater gardens. In nature the larvae are washed down to the sea and grow up in salt water before climbing back upstream — which is why the shrimp will not multiply in a home aquarium.",
			"השרימפס הזה קרוי על שם טקאשי אמאנו, הצלם והמעצב היפני שהפך אקווריומים מוצמחים לאמנות. בשנות ה-80 הוא גילה שהשרימפס הזה מחסל אצות כמו שום בעל חיים אחר, והזמין אלפים לגנים התת-מימיים שלו. בטבע הזחלים נסחפים אל הים וגדלים במים מלוחים לפני שהם מטפסים בחזרה במעלה הנחל — ולכן השרימפס לא יתרבה באקווריום ביתי.",
		],
	},
	"goldfish": {
		"name": ["Goldfish", "דג זהב"],
		"short": ["The oldest pet fish in the world. Big, hungry and messy.", "דג המחמד הוותיק בעולם. גדול, רעב ומלכלך."],
		"origin": ["China, where it was domesticated more than a thousand years ago", "סין, שם בוית לפני יותר מאלף שנה"],
		"lore": [
			"The goldfish began as a plain grey-green carp raised for food in China. About a thousand years ago, during the Song dynasty, people started keeping the rare golden ones in garden ponds, and for a time only the imperial family was allowed the yellow variety. The \"three-second memory\" is a myth: goldfish remember things for months, recognise the person who feeds them and can be taught tricks. A well-kept goldfish can live for decades — the record is over forty years.",
			"דג הזהב התחיל את דרכו כקרפיון אפור-ירקרק פשוט שגודל למאכל בסין. לפני כאלף שנה, בתקופת שושלת סונג, התחילו להחזיק את הפרטים הזהובים הנדירים בבריכות גן, ובמשך תקופה רק למשפחת הקיסר הותר להחזיק את הזן הצהוב. \"זיכרון של שלוש שניות\" הוא מיתוס: דגי זהב זוכרים במשך חודשים, מזהים את מי שמאכיל אותם ואפשר ללמד אותם תרגילים. דג זהב שמטופל היטב יכול לחיות עשרות שנים — השיא הוא יותר מארבעים.",
		],
	},
	"dwarf_gourami": {
		"name": ["Dwarf Gourami", "גוראמי ננסי"],
		"short": ["A small labyrinth fish striped in neon blue and orange.", "דג מבוך קטן בפסי כחול ניאון וכתום."],
		"origin": ["India, Pakistan and Bangladesh, in slow, weedy waters", "הודו, פקיסטן ובנגלדש, במים איטיים ועשירי צמחייה"],
		"lore": [
			"The male dwarf gourami is one of the most colourful freshwater fish, while the female is plain silver. He is also an architect: his bubble nest is reinforced with bits of plants and can be several centimetres thick. After spawning he chases the female away and guards the nest by himself. In its homeland the fish is so common that it is dried and eaten.",
			"זכר הגוראמי הננסי הוא מהצבעוניים שבדגי המים המתוקים, ואילו הנקבה כסופה ופשוטה. הוא גם אדריכל: קן הבועות שלו מחוזק בפיסות צמחים ויכול להגיע לעובי של כמה סנטימטרים. אחרי ההטלה הוא מגרש את הנקבה ושומר על הקן לבדו. בארץ מוצאו הדג נפוץ כל כך שמייבשים ואוכלים אותו.",
		],
	},
	"angelfish": {
		"name": ["Angelfish", "סקלר (דג מלאך)"],
		"short": ["A tall, graceful cichlid that glides like a sail.", "ציקליד גבוה ואצילי שגולש כמו מפרש."],
		"origin": ["The Amazon basin: Brazil, Peru and Colombia", "אגן האמזונס: ברזיל, פרו וקולומביה"],
		"lore": [
			"The angelfish's flat, disc-shaped body and dark vertical bars are camouflage: it lives among reeds and submerged roots, and when it holds still it simply vanishes between the stems. Its Latin name means \"winged leaf\". Angelfish are devoted parents — a pair cleans a leaf, lays hundreds of eggs on it, and both take turns fanning them with their fins and guarding the fry. Behind the elegant looks hides a hunter that will happily swallow a small neon.",
			"הגוף השטוח דמוי הדיסק והפסים האנכיים הכהים של הסקלר הם הסוואה: הוא חי בין קני סוף ושורשים שקועים, וכשהוא עומד במקום הוא פשוט נעלם בין הגבעולים. פירוש שמו הלטיני הוא \"עלה מכונף\". הסקלרים הם הורים מסורים — הזוג מנקה עלה, מטיל עליו מאות ביצים, ושניהם מתחלפים באוורור הביצים בסנפירים ובשמירה על הדגיגים. מאחורי המראה האלגנטי מסתתר צייד, שיבלע בשמחה ניאון קטן.",
		],
	},
	"bristlenose_pleco": {
		"name": ["Bristlenose Pleco", "אנציסטרוס"],
		"short": ["An armoured algae-scraper with a sucker mouth and a whiskery nose.", "מגרד אצות משוריין עם פה מוצץ ואף מזוקן."],
		"origin": ["South America: the Paraná river basin", "דרום אמריקה: אגן נהר הפרנה"],
		"lore": [
			"The bristlenose clings to rocks and glass with its sucker mouth and rasps off algae with rows of tiny teeth. Adult males grow a bush of soft tentacles on the snout; one idea is that they look like baby fish, signalling to females that he is a good father. And he is: the male guards the eggs in a cave and fans them for days without leaving. It also needs a piece of wood to chew on, which helps its digestion.",
			"האנציסטרוס נצמד לסלעים ולזכוכית בפה המוצץ שלו ומגרד אצות בשורות של שיניים זעירות. הזכרים הבוגרים מצמיחים על החוטם סבך של בליטות רכות; אחת ההשערות היא שהן נראות כמו דגיגים, ומאותתות לנקבות שהוא אב טוב. והוא אכן כזה: הזכר שומר על הביצים במערה ומאוורר אותן ימים שלמים בלי לעזוב. הוא גם זקוק לחתיכת עץ לכרסם, שעוזרת לו בעיכול.",
		],
	},
	"pearl_gourami": {
		"name": ["Pearl Gourami", "גוראמי פנינה"],
		"short": ["A gentle labyrinth fish covered in pearly dots.", "דג מבוך עדין מכוסה נקודות פנינה."],
		"origin": ["South-east Asia: Thailand, Malaysia, Sumatra and Borneo", "דרום-מזרח אסיה: תאילנד, מלזיה, סומטרה ובורנאו"],
		"lore": [
			"Many keepers consider the pearl gourami the most beautiful of all gouramis: its body looks as if it were sprinkled with mother-of-pearl. It comes from quiet lowland swamps with dark, acidic water. In breeding season the male's throat and chest flush deep orange-red. In the wild its swamps are being drained, and the species is now listed as near threatened.",
			"מגדלים רבים רואים בגוראמי הפנינה את היפה שבגוראמים: גופו נראה כאילו פוזרה עליו אם הפנינה. הוא מגיע מביצות שקטות בשפלה, שמימיהן כהים וחומציים. בעונת הרבייה הגרון והחזה של הזכר מתלהטים בכתום-אדום עמוק. בטבע מייבשים את הביצות שלו, והמין מוגדר היום כקרוב לסיכון.",
		],
	},
	"yellow_lab_cichlid": {
		"name": ["Yellow Lab Cichlid", "ציקליד צהוב ממלאווי"],
		"short": ["A lemon-yellow cichlid from an African great lake. Carries its young in its mouth.", "ציקליד בצהוב-לימון מאגם אפריקאי ענק. נושא את צאצאיו בפה."],
		"origin": ["East Africa: Lake Malawi", "מזרח אפריקה: אגם מלאווי"],
		"lore": [
			"Lake Malawi holds more species of fish than any other lake on Earth — many hundreds of cichlids that evolved there and live nowhere else. The yellow lab belongs to the \"mbuna\", the rock-dwellers that live among the boulders of the shore. The mother is a mouthbrooder: she scoops up her eggs and carries them, and then the hatched fry, in her mouth for about three weeks, eating nothing the whole time. In the lake most populations are actually white or pale blue; the bright yellow form comes from one small stretch of coast.",
			"באגם מלאווי חיים יותר מיני דגים מבכל אגם אחר על פני כדור הארץ — מאות רבות של ציקלידים שהתפתחו בו ואינם חיים בשום מקום אחר. הציקליד הצהוב שייך ל\"מבונה\", שוכני הסלעים שחיים בין הבולדרים של החוף. האם היא דוגרת-פה: היא אוספת את הביצים ונושאת אותן, ואחר כך את הדגיגים שבקעו, בתוך פיה במשך כשלושה שבועות, בלי לאכול דבר כל אותו הזמן. באגם רוב האוכלוסיות דווקא לבנות או תכלכלות; הצורה הצהובה הבוהקת מגיעה מקטע חוף קטן אחד.",
		],
	},
	"ram_cichlid": {
		"name": ["German Blue Ram", "רמירזי"],
		"short": ["A jewel-coloured dwarf cichlid that loves warm water. Needs a heater.", "ציקליד ננסי בצבעי תכשיט שאוהב מים חמים. דורש חימום."],
		"origin": ["The Orinoco plains of Venezuela and Colombia", "מישורי האורינוקו בוונצואלה ובקולומביה"],
		"lore": [
			"The ram lives in the llanos, the vast grasslands that flood every rainy season, in shallow water that the sun heats to nearly thirty degrees. A pair bonds for a long time and raises its young together, leading the cloud of fry around like a pair of shepherds. It is called \"German\" because breeders in Germany developed the intensely blue variety. It is a delicate fish that reacts quickly to dirty water.",
			"הרמירזי חי ביאנוס, מישורי העשב העצומים שמוצפים בכל עונת גשמים, במים רדודים שהשמש מחממת עד קרוב לשלושים מעלות. הזוג נקשר לזמן רב ומגדל את הצאצאים יחד, ומוביל את ענן הדגיגים כמו זוג רועים. באנגלית הוא נקרא \"גרמני\" משום שמגדלים בגרמניה פיתחו את הזן הכחול העז. זהו דג עדין, שמגיב מהר למים מלוכלכים.",
		],
	},
	"boesemani_rainbowfish": {
		"name": ["Boeseman's Rainbowfish", "דג קשת בוזמני"],
		"short": ["Half steel-blue, half blazing orange. Keep six or more.", "חציו כחול-פלדה וחציו כתום בוער. להחזיק שישה ומעלה."],
		"origin": ["West Papua, Indonesia: the Ayamaru lakes on the island of New Guinea", "פפואה המערבית, אינדונזיה: אגמי איאמרו באי גינאה החדשה"],
		"lore": [
			"This fish lives in the wild in just a handful of small lakes in a remote corner of New Guinea. It only became known to aquarists in the 1980s, and demand was so high that the wild population collapsed; today it is endangered in nature, and almost every fish in the trade is bred in captivity. Young fish are plain silver — the two-tone colouring develops slowly, and males are at their most brilliant early in the morning, when they display to the females.",
			"הדג הזה חי בטבע רק בקומץ אגמים קטנים בפינה נידחת של גינאה החדשה. חובבי האקווריום הכירו אותו רק בשנות ה-80, והביקוש היה גדול כל כך שאוכלוסיית הבר קרסה; היום הוא בסכנת הכחדה בטבע, וכמעט כל דג בחנויות מגודל בשבי. הדגים הצעירים כסופים ופשוטים — הצביעה הדו-גונית מתפתחת לאט, והזכרים במיטב זוהרם השכם בבוקר, כשהם מציגים את עצמם בפני הנקבות.",
		],
	},
	"discus": {
		"name": ["Discus", "דיסקוס"],
		"short": ["The \"king of the aquarium\": stunning, expensive and demanding.", "\"מלך האקווריום\": מרהיב, יקר ותובעני."],
		"origin": ["The Amazon basin: flooded forests of Brazil, Peru and Colombia", "אגן האמזונס: יערות מוצפים בברזיל, פרו וקולומביה"],
		"lore": [
			"The discus is named after its shape, like the disc thrown by athletes. It lives in calm groups among the roots of the flooded Amazon forest, in very warm, soft water. Its most remarkable trick is how it feeds its babies: both parents secrete a nourishing mucus from their skin, and for the first weeks the fry graze on their bodies, almost like mammals nursing. Keeping discus well is considered the peak of the freshwater hobby.",
			"הדיסקוס קרוי על שם צורתו, כמו הדיסקוס שאתלטים מטילים. הוא חי בקבוצות שלוות בין שורשי יער האמזונס המוצף, במים חמים ורכים מאוד. התכסיס המופלא ביותר שלו הוא הדרך שבה הוא מאכיל את צאצאיו: שני ההורים מפרישים מעורם ריר מזין, ובשבועות הראשונים הדגיגים רועים על גופם, כמעט כמו יונקים שיונקים. גידול מוצלח של דיסקוסים נחשב לפסגת תחביב המים המתוקים.",
		],
	},
	"oscar": {
		"name": ["Oscar", "אוסקר"],
		"short": ["A huge, clever cichlid with the personality of a pet dog.", "ציקליד ענק ונבון עם אישיות של כלב מחמד."],
		"origin": ["The Amazon basin: Brazil, Peru, Colombia and French Guiana", "אגן האמזונס: ברזיל, פרו, קולומביה וגיאנה הצרפתית"],
		"lore": [
			"Owners call the oscar a \"water dog\": it recognises its keeper, comes to the glass to greet them, takes food from the hand and sulks when ignored. It also likes to redecorate, shoving rocks and uprooting plants until the tank suits it. The orange-ringed black spot at the base of its tail is a false eye, thought to confuse piranhas that bite at the fins of other fish. A baby oscar the size of a coin grows to thirty centimetres within a couple of years.",
			"הבעלים מכנים את האוסקר \"כלב מים\": הוא מזהה את מי שמטפל בו, בא אל הזכוכית לקבל את פניו, לוקח אוכל מהיד ונעלב כשמתעלמים ממנו. הוא גם אוהב לעצב מחדש, לדחוף סלעים ולעקור צמחים עד שהאקווריום מתאים לטעמו. הכתם השחור המוקף טבעת כתומה בבסיס זנבו הוא עין מדומה, שכנראה מבלבלת פיראנות שנוגסות בסנפירי דגים אחרים. אוסקר צעיר בגודל מטבע מגיע לשלושים סנטימטרים בתוך שנתיים בערך.",
		],
	},
	# ------------------------------------------------------------------ saltwater
	"clownfish": {
		"name": ["Clownfish", "דג ליצן (שושנון)"],
		"short": ["The hardy, famous orange-and-white fish. The easiest saltwater fish to start with.", "הדג הכתום-לבן המפורסם והעמיד. דג המים המלוחים הקל ביותר להתחלה."],
		"origin": ["Eastern Indian Ocean and western Pacific: South-east Asia and northern Australia", "מזרח האוקיינוס ההודי ומערב האוקיינוס השקט: דרום-מזרח אסיה וצפון אוסטרליה"],
		"lore": [
			"The clownfish lives among the stinging tentacles of a sea anemone, protected by a special coat of mucus on its skin; in return it chases away fish that nibble the anemone and feeds it scraps. Every clownfish is born male. A group is ruled by one large female, and if she dies the biggest male changes sex and takes her place. The Hebrew name, shoshanon, comes from shoshanat-yam, the sea anemone.",
			"דג הליצן חי בין הזרועות הצורבות של שושנת ים, מוגן בשכבת ריר מיוחדת שעל עורו; בתמורה הוא מגרש דגים שמכרסמים את השושנה ומאכיל אותה בשאריות. כל דג ליצן נולד זכר. בראש הקבוצה עומדת נקבה גדולה אחת, ואם היא מתה, הזכר הגדול ביותר משנה את מינו ותופס את מקומה. השם העברי, שושנון, נגזר משושנת הים.",
		],
	},
	"blue_green_chromis": {
		"name": ["Blue-Green Chromis", "כרומיס ירקרק"],
		"short": ["A shimmering, peaceful schooling fish. Keep six or more.", "דג להקה מנצנץ ושליו. להחזיק שישה ומעלה."],
		"origin": ["The Indo-Pacific, from the Red Sea to Polynesia", "האוקיינוס ההודי והשקט, מים סוף ועד פולינזיה"],
		"lore": [
			"On the reef, clouds of hundreds of chromis hover above branching corals, picking plankton out of the current. At the slightest shadow the whole cloud drops into the coral in a split second, each fish into its own gap between the branches. Its colour shifts from pale green to light blue depending on the angle of the light. Snorkellers can meet these very fish on the coral reefs of Eilat.",
			"בשונית, עננים של מאות כרומיסים מרחפים מעל אלמוגים מסועפים ומלקטים פלנקטון מהזרם. למראה הצל הקל ביותר כל הענן צונח אל תוך האלמוג בשבריר שנייה, כל דג אל המרווח שלו בין הענפים. צבעו משתנה מירוק בהיר לתכלת לפי זווית האור. את הדגים האלה בדיוק אפשר לפגוש בשנורקל בשוניות האלמוגים של אילת.",
		],
	},
	"cleaner_shrimp": {
		"name": ["Skunk Cleaner Shrimp", "שרימפס מנקה"],
		"short": ["Runs a cleaning station: picks parasites off the fish.", "מפעיל תחנת ניקוי: מסיר טפילים מהדגים."],
		"origin": ["The Indo-Pacific and the Red Sea", "האוקיינוס ההודי והשקט וים סוף"],
		"lore": [
			"This shrimp runs a real business. It waits at a fixed spot on the reef and waves its long white antennae to advertise; fish come, hold still and even open their mouths and gills, and the shrimp climbs in to eat parasites and dead skin. Predators that would normally eat a shrimp leave their cleaner unharmed. In an aquarium it will happily climb onto your hand and clean it too.",
			"השרימפס הזה מנהל עסק של ממש. הוא ממתין בנקודה קבועה בשונית ומנופף במחושיו הלבנים הארוכים כפרסומת; דגים באים, עומדים במקום ואפילו פותחים את הפה והזימים, והשרימפס מטפס פנימה לאכול טפילים ועור מת. טורפים שבדרך כלל היו אוכלים שרימפס מניחים למנקה שלהם. באקווריום הוא יטפס בשמחה גם על היד שלכם וינקה אותה.",
		],
	},
	"hermit_crab": {
		"name": ["Blue-Legged Hermit Crab", "סרטן נזיר כחול-רגליים"],
		"short": ["A tiny janitor in a borrowed shell. Eats algae and leftovers.", "שרת זעיר בקונכייה שאולה. אוכל אצות ושאריות."],
		"origin": ["The Caribbean Sea and the tropical western Atlantic", "הים הקריבי ומערב האוקיינוס האטלנטי הטרופי"],
		"lore": [
			"A hermit crab's abdomen is soft and unprotected, so it lives inside an empty snail shell and carries its house on its back. As it grows it must find a bigger shell, and hermit crabs are known to line up by size and swap shells one after another when a good one becomes available. This species is barely the size of a fingernail, with electric-blue legs banded in red. It works day and night scraping algae off the rocks.",
			"הבטן של סרטן הנזיר רכה וחשופה, ולכן הוא חי בתוך קונכיית חילזון ריקה ונושא את ביתו על גבו. כשהוא גדל עליו למצוא קונכייה גדולה יותר, וסרטני נזיר ידועים בכך שהם מסתדרים בשורה לפי גודל ומחליפים קונכיות זה אחר זה כשמתפנה אחת טובה. המין הזה בקושי בגודל ציפורן, עם רגליים בכחול חשמלי ופסים אדומים. הוא עובד יומם ולילה ומגרד אצות מהסלעים.",
		],
	},
	"firefish_goby": {
		"name": ["Firefish", "גובי אש"],
		"short": ["A slim fish that fades from white to flame red and hovers in place.", "דג דק שמשתנה מלבן לאדום-להבה ומרחף במקום."],
		"origin": ["The Indo-Pacific, from East Africa to Hawaii", "האוקיינוס ההודי והשקט, ממזרח אפריקה ועד הוואי"],
		"lore": [
			"The firefish hangs in the current just above its burrow, facing the flow and snapping up drifting plankton. It constantly flicks its tall, needle-like dorsal fin, which is thought to be a signal to other firefish nearby. At any hint of danger it shoots into its hole head first. It is also a notorious jumper — aquarium keepers learn quickly to keep a lid on the tank.",
			"גובי האש תלוי בזרם ממש מעל המחילה שלו, פונה אל מול הזרימה וחוטף פלנקטון נסחף. הוא מנער ללא הרף את סנפיר הגב הגבוה דמוי המחט, ככל הנראה כאות לדגי אש אחרים בסביבה. בכל רמז לסכנה הוא נורה אל תוך החור עם הראש קדימה. הוא גם קופץ ידוע לשמצה — מגדלים לומדים מהר להחזיק מכסה על האקווריום.",
		],
	},
	"yellow_watchman_goby": {
		"name": ["Yellow Watchman Goby", "גובי שומר צהוב"],
		"short": ["A grumpy-faced bottom dweller that stands guard at its burrow.", "דג קרקעית עם פרצוף זועף שעומד על המשמר ליד המחילה."],
		"origin": ["The western Pacific, from southern Japan to the Great Barrier Reef", "מערב האוקיינוס השקט, מדרום יפן ועד שונית המחסום הגדולה"],
		"lore": [
			"This goby is one half of a famous partnership. It shares a burrow with a pistol shrimp that is almost blind: the shrimp digs and maintains the tunnel like a little bulldozer, and the goby stands guard at the entrance. The shrimp keeps one antenna resting on the fish at all times, and a flick of the goby's tail means \"danger\" — both vanish underground together. Neither does as well alone.",
			"הגובי הזה הוא חצי משותפות מפורסמת. הוא חולק מחילה עם שרימפס אקדח כמעט עיוור: השרימפס חופר ומתחזק את המנהרה כמו דחפור קטן, והגובי עומד על המשמר בפתח. השרימפס מניח תמיד מחוש אחד על הדג, וניעור של זנב הגובי פירושו \"סכנה\" — ושניהם נעלמים יחד מתחת לאדמה. אף אחד מהם לא מסתדר טוב לבדו.",
		],
	},
	"royal_gramma": {
		"name": ["Royal Gramma", "גראמה מלכותית"],
		"short": ["Half royal purple, half golden yellow. Small, hardy and peaceful.", "חציה סגול מלכותי וחציה צהוב זהוב. קטנה, עמידה ושלווה."],
		"origin": ["The Caribbean Sea and the Bahamas", "הים הקריבי ואיי בהאמה"],
		"lore": [
			"The royal gramma lives under ledges and in caves on Caribbean reefs, and it has an odd habit: it keeps its belly turned toward the nearest surface. Under an overhang that means it swims upside down, perfectly at ease. The male builds a nest from scraps of algae in a crevice and guards the eggs. When threatened it opens its mouth wide in a silent, rather comical threat.",
			"הגראמה המלכותית חיה מתחת למדפי סלע ובמערות בשוניות הקריביים, ויש לה הרגל משונה: היא מפנה תמיד את הבטן אל המשטח הקרוב ביותר. מתחת למדף סלע פירוש הדבר שהיא שוחה הפוכה, בנינוחות גמורה. הזכר בונה קן מפיסות אצות בסדק ושומר על הביצים. כשמאיימים עליה היא פוערת את הפה לרווחה באיום שקט ודי מצחיק.",
		],
	},
	"banggai_cardinalfish": {
		"name": ["Banggai Cardinalfish", "קרדינל בנגאי"],
		"short": ["An elegant black-and-silver fish that breeds in the aquarium.", "דג אלגנטי בשחור-כסף שמתרבה באקווריום."],
		"origin": ["Indonesia: only the Banggai Islands, off Sulawesi", "אינדונזיה: רק באיי בנגאי, מול סולאווסי"],
		"lore": [
			"The entire wild population of this fish lives around one small group of islands, an area smaller than many cities. After it became an aquarium star in the 1990s, collectors took so many that it is now endangered. The good news: it breeds readily in captivity. The father takes the eggs into his mouth and carries them, and then the babies, for about a month without eating. In the sea the young hide among the long spines of sea urchins.",
			"כל אוכלוסיית הבר של הדג הזה חיה סביב קבוצת איים קטנה אחת, שטח קטן מערים רבות. אחרי שהפך לכוכב אקווריומים בשנות ה-90, אספו ממנו כל כך הרבה שהיום הוא בסכנת הכחדה. החדשות הטובות: הוא מתרבה בקלות בשבי. האב לוקח את הביצים אל פיו ונושא אותן, ואחר כך את הצאצאים, כחודש שלם בלי לאכול. בים הצעירים מסתתרים בין הקוצים הארוכים של קיפודי ים.",
		],
	},
	"fire_shrimp": {
		"name": ["Blood Red Fire Shrimp", "שרימפס אש"],
		"short": ["Deep red with white dots. A shy cleaner that loves caves.", "אדום עמוק עם נקודות לבנות. מנקה ביישן שאוהב מערות."],
		"origin": ["The Indo-Pacific: the Maldives, Indonesia and the Philippines", "האוקיינוס ההודי והשקט: האיים המלדיביים, אינדונזיה והפיליפינים"],
		"lore": [
			"The fire shrimp is one of the most striking invertebrates on the reef: blood-red with white spots and white \"socks\". It is a cleaner like its striped cousin, but far more timid — it sets up its station deep inside a cave and waits for fish to come to it. Like all shrimp it grows by moulting: it slips out of its old shell and hides for a day or two until the new one hardens.",
			"שרימפס האש הוא מחסרי החוליות המרשימים ביותר בשונית: אדום כדם עם נקודות לבנות ו\"גרביים\" לבנים. הוא מנקה כמו בן דודו המפוספס, אבל ביישן בהרבה — הוא מקים את התחנה שלו עמוק בתוך מערה ומחכה שהדגים יבואו אליו. כמו כל שרימפס הוא גדל בהתנשלות: הוא מחליק החוצה מהשריון הישן ומסתתר יום או יומיים עד שהחדש מתקשה.",
		],
	},
	"seahorse": {
		"name": ["Lined Seahorse", "סוסון ים"],
		"short": ["The fish where the father gives birth. Slow, delicate and unforgettable.", "הדג שבו האב הוא שיולד. איטי, עדין ובלתי נשכח."],
		"origin": ["The western Atlantic, from Canada to Brazil, and the Caribbean", "מערב האוקיינוס האטלנטי, מקנדה ועד ברזיל, והים הקריבי"],
		"lore": [
			"The seahorse is a true fish, although it swims upright and has a horse's head, a monkey's gripping tail and eyes that move separately like a chameleon's. Most famously, it is the male who becomes pregnant: the female places her eggs in a pouch on his belly, and weeks later he goes into labour and releases hundreds of tiny seahorses. A pair greets each other every morning with a slow dance, changing colour as they turn. It has no stomach, so it must eat almost constantly.",
			"סוסון הים הוא דג לכל דבר, אף שהוא שוחה זקוף ויש לו ראש של סוס, זנב אחיזה של קוף ועיניים שנעות בנפרד כמו של זיקית. המפורסם מכול: הזכר הוא זה שנכנס להיריון. הנקבה מניחה את הביצים בכיס שעל בטנו, וכעבור שבועות הוא כורע ללדת ומשחרר מאות סוסונים זעירים. בני הזוג מברכים זה את זה מדי בוקר בריקוד איטי, ומחליפים צבעים תוך כדי סיבוב. אין לו קיבה, ולכן הוא חייב לאכול כמעט בלי הפסקה.",
		],
	},
	"flame_angelfish": {
		"name": ["Flame Angelfish", "דג מלאך להבה"],
		"short": ["A dwarf angelfish that looks like a swimming flame.", "דג מלאך ננסי שנראה כמו להבה שוחה."],
		"origin": ["The tropical Pacific: the Marshall, Line and Cook Islands, and Hawaii", "האוקיינוס השקט הטרופי: איי מרשל, ליין וקוק, והוואי"],
		"lore": [
			"Few reef fish match the flame angel's colour — glowing red-orange with black bars and fins trimmed in electric blue. It lives in small harems: one male with several females. All are born female, and when the male disappears the largest female turns into a male within a couple of weeks. It spends its day darting between rocks, nibbling algae and never straying far from cover.",
			"מעטים מדגי השונית משתווים בצבעם לדג מלאך הלהבה — כתום-אדום זוהר עם פסים שחורים וסנפירים בעיטור כחול חשמלי. הוא חי בהרמונות קטנים: זכר אחד עם כמה נקבות. כולם נולדים נקבות, וכשהזכר נעלם, הנקבה הגדולה ביותר הופכת לזכר בתוך כשבועיים. את יומו הוא מבלה בזינוקים בין הסלעים, מכרסם אצות ואינו מתרחק לעולם ממחסה.",
		],
	},
	"yellow_tang": {
		"name": ["Yellow Tang", "דג מנתח צהוב"],
		"short": ["A brilliant yellow grazer that needs a big tank and lots of swimming room.", "רועה אצות בצהוב בוהק שצריך אקווריום גדול והרבה מקום לשחות."],
		"origin": ["The Pacific Ocean, above all the islands of Hawaii", "האוקיינוס השקט, ובעיקר איי הוואי"],
		"lore": [
			"Tangs are called surgeonfish because of the blade, sharp as a scalpel, hidden on each side of the tail base; a flick of the tail can slash a rival. The yellow tang is a peaceful grazer that mows algae all day long, and in Hawaii it even cleans the algae off the shells of green sea turtles. At night its yellow fades and a pale stripe appears along its side. It was first bred in captivity only in 2015.",
			"דגי המנתח קיבלו את שמם בזכות הלהב, חד כאזמל, שמוסתר בכל צד של בסיס הזנב; הנפת זנב יכולה לחתוך יריב. המנתח הצהוב הוא רועה שליו שמכסח אצות כל היום, ובהוואי הוא אפילו מנקה אצות משריוניהם של צבי ים ירוקים. בלילה הצהוב שלו דוהה ופס חיוור מופיע לאורך צדו. לראשונה הצליחו להרבות אותו בשבי רק ב-2015.",
		],
	},
	"blue_tang": {
		"name": ["Regal Blue Tang", "דג מנתח כחול"],
		"short": ["\"Dory\": royal blue with a yellow tail. Grows large and needs a big tank.", "\"דורי\": כחול מלכותי עם זנב צהוב. גדל מאוד וצריך אקווריום גדול."],
		"origin": ["The Indo-Pacific, from East Africa to Japan and Samoa", "האוקיינוס ההודי והשקט, ממזרח אפריקה ועד יפן וסמואה"],
		"lore": [
			"The whole world knows this fish as Dory from the films. Young blue tangs live in groups above branching corals and wedge themselves between the branches when frightened; a scared tang may even lie flat on its side and \"play dead\". Like every surgeonfish it carries a sharp blade at the base of its tail. It grows to thirty centimetres and swims long distances every day, which is why it needs a very large aquarium.",
			"כל העולם מכיר את הדג הזה בתור דורי מהסרטים. מנתחים כחולים צעירים חיים בקבוצות מעל אלמוגים מסועפים ונדחקים בין הענפים כשהם נבהלים; מנתח מבוהל עשוי אפילו לשכב על הצד ו\"להעמיד פני מת\". כמו כל דג מנתח הוא נושא להב חד בבסיס הזנב. הוא מגיע לשלושים סנטימטרים ושוחה מרחקים ארוכים מדי יום, ולכן הוא זקוק לאקווריום גדול מאוד.",
		],
	},
	"mandarin_dragonet": {
		"name": ["Mandarin Dragonet", "דג מנדרין"],
		"short": ["Possibly the most beautiful fish in the sea. For experts with a big, mature tank.", "אולי הדג היפה ביותר בים. למומחים עם אקווריום גדול ובשל."],
		"origin": ["The western Pacific: the Philippines, Indonesia and northern Australia", "מערב האוקיינוס השקט: הפיליפינים, אינדונזיה וצפון אוסטרליה"],
		"lore": [
			"The mandarin is named after the embroidered robes of imperial Chinese officials. Its blue is unique: in almost every other blue animal the colour is a trick of light, but the mandarin is one of only two vertebrates known to make a true blue pigment. It has no scales; instead it is coated in a thick, bitter, smelly slime that puts predators off. At dusk a pair rises slowly from the reef side by side to spawn. It hunts tiny crustaceans all day, one by one.",
			"המנדרין קרוי על שם הגלימות הרקומות של פקידי הקיסרות הסינית. הכחול שלו ייחודי: כמעט בכל בעל חיים כחול אחר הצבע הוא תעתוע של אור, אבל המנדרין הוא אחד משני בעלי החוליות היחידים הידועים שמייצרים צבען כחול אמיתי. אין לו קשקשים; במקומם הוא מצופה בריר סמיך, מר ומסריח שמרתיע טורפים. עם רדת הערב הזוג עולה לאט מהשונית, זה לצד זה, כדי להטיל. כל היום הוא צד סרטנים זעירים, אחד אחד.",
		],
	},
	"lionfish": {
		"name": ["Red Lionfish", "זהרון"],
		"short": ["A majestic, venomous predator. Look, don't touch.", "טורף מלכותי וארסי. להסתכל, לא לגעת."],
		"origin": ["The Indo-Pacific; its close relative lives in the Red Sea", "האוקיינוס ההודי והשקט; קרוב משפחתו חי בים סוף"],
		"lore": [
			"The lionfish drifts slowly with its fins spread like a fan — a warning sign, because eighteen of its spines carry venom that causes intense pain. It hunts by herding small fish into a corner with its wide fins and swallowing them in a lightning gulp. Released from aquariums into the Atlantic in the 1980s, it multiplied without natural enemies and became one of the most damaging invasive fish in the world. Its Red Sea relative, familiar to divers in Eilat, has in recent years spread through the Suez Canal into the Mediterranean, including the coast of Israel.",
			"הזהרון מרחף לאט כשסנפיריו פרושים כמניפה — שלט אזהרה, כי שמונה-עשר מקוציו נושאים ארס שגורם לכאב עז. הוא צד בכך שהוא דוחק דגים קטנים לפינה בסנפיריו הרחבים ובולע אותם בלגימת בזק. אחרי ששוחרר מאקווריומים אל האוקיינוס האטלנטי בשנות ה-80, הוא התרבה בלי אויבים טבעיים והפך לאחד הדגים הפולשים המזיקים בעולם. קרוב משפחתו מים סוף, המוכר לצוללנים באילת, התפשט בשנים האחרונות דרך תעלת סואץ אל הים התיכון, כולל חופי ישראל.",
		],
	},
}

const EQUIPMENT := {
	"basic_filter": {
		"name": ["Sponge Filter", "מסנן ספוג"],
		"short": ["Keeps the water clean and houses the bacteria that neutralise fish waste.", "שומר על מים נקיים ומארח את החיידקים שמנטרלים את פסולת הדגים."],
		"lore": [
			"The filter is the heart of the aquarium and the first thing to buy. Fish waste turns into ammonia, which is poisonous. Helpful bacteria settle inside the filter and turn the ammonia into far less harmful substances — but a new filter starts out empty, and it takes several days for the colony to grow (this is the \"filter maturity\" reading in Tank Status). Until it matures, change the water often and do not buy many fish at once.",
			"המסנן הוא לב האקווריום והדבר הראשון שכדאי לקנות. פסולת הדגים הופכת לאמוניה, שהיא רעילה. חיידקים מועילים מתיישבים בתוך המסנן והופכים את האמוניה לחומרים מזיקים הרבה פחות — אבל מסנן חדש מתחיל ריק, ולוקח כמה ימים עד שהמושבה גדלה (זה המדד \"בשלות המסנן\" במסך מצב האקווריום). עד שהוא מבשיל, החליפו מים לעיתים קרובות ואל תקנו הרבה דגים בבת אחת.",
		],
	},
	"canister_filter": {
		"name": ["Canister Filter", "מסנן קניסטר"],
		"short": ["A powerful external filter for big or crowded tanks.", "מסנן חיצוני עוצמתי לאקווריומים גדולים או צפופים."],
		"lore": [
			"A canister is a sealed bucket of filter media that sits outside the tank and pumps water through it. It moves several times more water than a sponge filter and holds a much larger colony of bacteria, so it matures faster and copes with many more fish. Worth buying when the water turns bad even though you change it regularly, or when you move up to a large tank with big, messy fish.",
			"הקניסטר הוא מכל אטום מלא בחומרי סינון, שיושב מחוץ לאקווריום ושואב את המים דרכו. הוא מזרים פי כמה יותר מים ממסנן ספוג ומחזיק מושבת חיידקים גדולה בהרבה, ולכן הוא מבשיל מהר יותר ומתמודד עם הרבה יותר דגים. כדאי לקנות אותו כשהמים מתקלקלים למרות החלפות סדירות, או כשעוברים לאקווריום גדול עם דגים גדולים ומלכלכים.",
		],
	},
	"protein_skimmer": {
		"name": ["Protein Skimmer", "מפריד חלבונים (סקימר)"],
		"short": ["The saltwater filter: pulls waste out of the water before it rots.", "המסנן של המים המלוחים: מוציא פסולת מהמים לפני שהיא נרקבת."],
		"lore": [
			"A skimmer whips sea water into a column of very fine bubbles. Dissolved waste sticks to the bubbles, rises as a dirty foam and collects in a cup — the same thing that makes foam on a beach after a storm. Because it removes the waste before it breaks down at all, it is the strongest filtration in the game and the standard choice for a saltwater tank.",
			"הסקימר מקציף את מי הים לעמוד של בועות דקיקות מאוד. הפסולת המומסת נדבקת לבועות, עולה כקצף מלוכלך ונאספת בכוס — אותה תופעה שיוצרת קצף על החוף אחרי סערה. מאחר שהוא מסלק את הפסולת עוד לפני שהיא מתפרקת, זהו הסינון החזק ביותר במשחק והבחירה המקובלת לאקווריום מים מלוחים.",
		],
	},
	"basic_heater": {
		"name": ["Heater", "גוף חימום"],
		"short": ["Holds the water at a steady 25°C. Essential for tropical fish in winter.", "שומר על המים ב-25 מעלות קבועות. חיוני לדגים טרופיים בחורף."],
		"lore": [
			"Most aquarium fish come from the tropics and are comfortable at around 24-27°C. Without a heater the tank follows the room: pleasant in spring and summer, but in autumn and especially winter it drops well below what tropical fish can take, and they become stressed, stop breeding and fall ill. Some species need a heater from day one — the shop will tell you. A basic heater can also break down in a cold winter; if the coach line says so, buy a new one.",
			"רוב דגי האקווריום מגיעים מהאזורים הטרופיים ונוח להם בסביבות 24 עד 27 מעלות. בלי גוף חימום האקווריום עוקב אחרי טמפרטורת החדר: נעים באביב ובקיץ, אבל בסתיו ובמיוחד בחורף הוא יורד הרבה מתחת למה שדגים טרופיים מסוגלים לשאת, והם נלחצים, מפסיקים להתרבות וחולים. יש מינים שדורשים חימום מהיום הראשון — החנות תאמר לכם. גוף חימום בסיסי גם עלול להתקלקל בחורף קר; אם שורת העצות אומרת זאת, קנו חדש.",
		],
	},
	"pro_heater": {
		"name": ["Pro Heater", "גוף חימום מקצועי"],
		"short": ["Stronger and more reliable: recovers faster and rarely fails.", "חזק ואמין יותר: מתאושש מהר וכמעט לא מתקלקל."],
		"lore": [
			"A stronger heating element with a better thermostat. It brings the water back to 25°C almost twice as fast after a cold snap or a water change, and it is far less likely to burn out in winter. Recommended for large tanks, where a small heater struggles, and for delicate, expensive fish such as discus that react badly to temperature swings.",
			"גוף חימום חזק יותר עם תרמוסטט טוב יותר. הוא מחזיר את המים ל-25 מעלות כמעט פי שניים מהר יותר אחרי גל קור או החלפת מים, והסיכוי שיישרף בחורף קטן בהרבה. מומלץ לאקווריומים גדולים, שבהם גוף חימום קטן מתקשה, ולדגים עדינים ויקרים כמו דיסקוס, שמגיבים רע לתנודות טמפרטורה.",
		],
	},
	"basic_light": {
		"name": ["Tank Light", "תאורה בסיסית"],
		"short": ["Lights up the tank so you can actually see your fish.", "מאירה את האקווריום כדי שבאמת תראו את הדגים."],
		"lore": [
			"Without a lamp the tank stays dim and the colours of the fish look washed out. A light also gives the tank a day-and-night rhythm, which fish rely on. A word of caution from real fishkeeping: a lot of light plus dirty water is exactly what algae love, so in summer a neglected, brightly lit tank can suffer an algae bloom.",
			"בלי מנורה האקווריום נשאר אפלולי וצבעי הדגים נראים דהויים. התאורה גם מעניקה לאקווריום מחזור של יום ולילה, שהדגים נשענים עליו. מילת אזהרה מעולם האקווריומים האמיתי: הרבה אור יחד עם מים מלוכלכים הם בדיוק מה שאצות אוהבות, ולכן בקיץ אקווריום מוזנח ומואר היטב עלול לסבול מפריחת אצות.",
		],
	},
	"led_light": {
		"name": ["LED Light", "תאורת LED"],
		"short": ["Brighter, crisper light that makes colours pop.", "אור חזק וחד יותר שמבליט את הצבעים."],
		"lore": [
			"LED fixtures give much more light for the same electricity, stay cool and last for years. The stronger, whiter light brings out the reds and blues of the fish. In real reef keeping this is the kind of lighting corals depend on, since they live off the light much like plants do.",
			"גופי תאורת LED נותנים הרבה יותר אור באותה צריכת חשמל, נשארים קרירים ומחזיקים שנים. האור החזק והלבן יותר מבליט את האדומים והכחולים של הדגים. באקווריומים ימיים אמיתיים זו התאורה שאלמוגים תלויים בה, כי הם חיים מהאור בדומה לצמחים.",
		],
	},
	"air_stone": {
		"name": ["Air Stone", "אבן אוויר"],
		"short": ["A stream of bubbles that adds oxygen to the water.", "זרם בועות שמוסיף חמצן למים."],
		"lore": [
			"A small pump pushes air through a porous stone, which breaks it into a curtain of fine bubbles. The bubbles themselves add little oxygen — the real work is done at the surface, which they keep stirring so that oxygen from the air dissolves into the water. Warm water holds less oxygen and many fish use more of it, so an air stone matters most in summer and in a crowded tank.",
			"משאבה קטנה דוחפת אוויר דרך אבן נקבובית, שמפרקת אותו למסך של בועות דקות. הבועות עצמן מוסיפות מעט חמצן — העבודה האמיתית נעשית בפני המים, שהבועות מערבלות ללא הרף וכך חמצן מהאוויר מתמוסס במים. מים חמים מחזיקים פחות חמצן והרבה דגים צורכים יותר ממנו, ולכן אבן אוויר חשובה במיוחד בקיץ ובאקווריום צפוף.",
		],
	},
	"powerhead": {
		"name": ["Powerhead", "משאבת זרימה"],
		"short": ["A strong pump that creates current and lots of oxygen.", "משאבה חזקה שיוצרת זרם והרבה חמצן."],
		"lore": [
			"On a coral reef the water never stands still: waves and tides wash over the fish all the time. A powerhead recreates that current inside the tank. The moving water carries waste toward the filter and brings in far more oxygen than an air stone, which large, active fish such as tangs need.",
			"בשונית אלמוגים המים אף פעם לא עומדים: גלים וגאות שוטפים את הדגים כל הזמן. משאבת זרימה משחזרת את הזרם הזה בתוך האקווריום. המים הנעים נושאים פסולת אל המסנן ומכניסים הרבה יותר חמצן מאבן אוויר, דבר שדגים גדולים ופעילים כמו דגי מנתח זקוקים לו.",
		],
	},
	"digital_test_kit": {
		"name": ["Water Test Kit", "ערכת בדיקת מים"],
		"short": ["Shows the exact water readings instead of a rough guess.", "מציגה את מדדי המים המדויקים במקום הערכה גסה."],
		"lore": [
			"Clear water is not necessarily healthy water: ammonia and nitrite are invisible and have no smell. With a test kit, Tank Status shows the real numbers. Ammonia and nitrite should stay close to zero — if they climb, change the water at once. Nitrate rises slowly on its own and is brought down by a regular water change. The kit turns guessing into knowing, and lets you act before the fish show distress.",
			"מים צלולים אינם בהכרח מים בריאים: אמוניה וניטריט אינם נראים ואין להם ריח. עם ערכת בדיקה, מסך מצב האקווריום מציג את המספרים האמיתיים. אמוניה וניטריט צריכים להישאר קרוב לאפס — אם הם מטפסים, החליפו מים מיד. הניטרט עולה לאט מעצמו ויורד בהחלפת מים סדירה. הערכה הופכת ניחוש לידיעה, ומאפשרת לפעול לפני שהדגים מראים מצוקה.",
		],
	},
}


## Flattens the tables above into Localization-style entries: key -> {"en": ..., "he": ...}.
static func build() -> Dictionary:
	var out: Dictionary = {}
	var all_species: Dictionary = SPECIES.duplicate()
	all_species.merge(LoreStrings18.SPECIES)
	for species_id in all_species.keys():
		var entry: Dictionary = all_species[species_id]
		out["sp_%s" % species_id] = _pair(entry["name"])
		out["desc_sp_%s" % species_id] = _pair(entry["short"])
		out["origin_sp_%s" % species_id] = _pair(entry["origin"])
		out["lore_sp_%s" % species_id] = _pair(entry["lore"])
	var all_equipment: Dictionary = EQUIPMENT.duplicate()
	all_equipment.merge(LoreStrings18.EQUIPMENT)
	for equipment_id in all_equipment.keys():
		var entry: Dictionary = all_equipment[equipment_id]
		out["eq_%s" % equipment_id] = _pair(entry["name"])
		out["desc_eq_%s" % equipment_id] = _pair(entry["short"])
		out["lore_eq_%s" % equipment_id] = _pair(entry["lore"])
	return out


static func _pair(texts: Array) -> Dictionary:
	return {"en": texts[0], "he": texts[1]}
