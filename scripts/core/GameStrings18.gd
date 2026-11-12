extends RefCounted
class_name GameStrings18
## UI strings added in 1.8 (pond, weather, new species rules): key -> [English, Hebrew].

const S := {
	"tank_type_pond": ["Pond", "בריכה"],
	"alert_not_for_pond": ["%s is a tropical fish and would not survive a winter outdoors. Keep it in an aquarium.", "%s הוא דג טרופי ולא ישרוד חורף בחוץ. החזק אותו באקווריום."],
	"alert_pond_only": ["%s needs the space and cold water of a garden pond. Buy a pond first.", "%s זקוק למקום ולמים הקרים של בריכת גן. קנה קודם בריכה."],
	"alert_pond_no_heater": ["You can't heat a garden pond: the weather decides its temperature.", "אי אפשר לחמם בריכת גן: מזג האוויר קובע את הטמפרטורה שלה."],
	"alert_net_pond_only": ["A net is only for the garden pond.", "רשת מיועדת רק לבריכת הגן."],
	"alert_pond_frozen": ["The pond is iced over and the fish are resting. Don't feed them until the ice melts.", "הבריכה קפואה והדגים נחים. אל תאכיל אותם עד שהקרח יימס."],
	"toast_heron": ["A heron took %s the %s!", "אנפה לקחה את %s ה%s!"],
	"weather_sunny": ["Sunny", "שמשי"],
	"weather_cloudy": ["Cloudy", "מעונן"],
	"weather_rain": ["Rain", "גשם"],
	"weather_storm": ["Storm", "סערה"],
	"weather_heat": ["Heatwave", "גל חום"],
	"weather_snow": ["Snow", "שלג"],
	"slot_8": ["Pond protection", "הגנה לבריכה"],
	"pond_weather": ["Weather outside", "מזג אוויר בחוץ"],
	"pond_ice": ["Ice", "קרח"],
	"pond_iced_over": ["Iced over", "הבריכה קפואה"],
	"pond_net": ["Heron net", "רשת נגד אנפות"],
	"pond_net_on": ["Covered", "מכוסה"],
	"pond_net_off": ["None", "אין"],
	"tip_pond_net": ["A heron may visit the pond. A net over the water keeps the fish safe.", "אנפה עלולה לבקר בבריכה. רשת מעל המים שומרת על הדגים."],
	"tip_pond_frozen": ["The pond is frozen. The fish are resting: no feeding until the ice melts.", "הבריכה קפואה. הדגים נחים: בלי האכלה עד שהקרח יימס."],
}


static func build() -> Dictionary:
	var out := {}
	for key in S.keys():
		out[key] = {"en": S[key][0], "he": S[key][1]}
	return out
