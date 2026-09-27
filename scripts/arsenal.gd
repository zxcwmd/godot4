class_name Arsenal
extends RefCounted

const LIME = Color("c3ff62")
const CYAN = Color("64e8ff")
const ORANGE = Color("ff704d")
const VIOLET = Color("bc8aff")
const CLASSES = [
	{"name": "МЕЧНИК", "tag": "01 / BLADE", "desc": "Ближе к врагу. Ближе к краю.\nУбийства вблизи восстанавливают здоровье.", "color": LIME, "weapons": ["katana", "sickles", "rapier", "saws", "scythe"]},
	{"name": "СТРЕЛОК", "tag": "02 / BALLISTIC", "desc": "Скорость, точность, рикошет.\nБесконечный боезапас. Никаких перезарядок.", "color": ORANGE, "weapons": ["revolver", "discs", "rail", "scatter"]},
	{"name": "АРКАНИСТ", "tag": "03 / INVOKE", "desc": "Огонь. Лёд. Молния.\nСобери три стихии — создай заклинание.", "color": VIOLET, "weapons": ["ember", "frost", "storm"]}
]
const WEAPONS = {
	"katana": {"name": "КАТАНА", "desc": "Широкий разрез / рывок сквозь толпу", "damage": 38.0, "rate": 0.36, "reach": 5.0, "cone": 0.25, "kind": "melee"},
	"sickles": {"name": "ПАРНЫЕ СЕРПЫ", "desc": "Быстрые удары / усиленный вампиризм", "damage": 23.0, "rate": 0.23, "reach": 4.2, "cone": 0.0, "kind": "melee"},
	"rapier": {"name": "РАПИРА", "desc": "Длинный выпад / двойной урон одной цели", "damage": 76.0, "rate": 0.46, "reach": 7.0, "cone": 0.88, "kind": "melee"},
	"saws": {"name": "РУКИ-БЕНЗОПИЛЫ", "desc": "Удерживай огонь / непрерывный разрыв", "damage": 13.0, "rate": 0.085, "reach": 3.7, "cone": 0.2, "kind": "melee"},
	"scythe": {"name": "КОСА", "desc": "Круговая жатва / огромный радиус", "damage": 55.0, "rate": 0.72, "reach": 6.3, "cone": -1.0, "kind": "melee"},
	"revolver": {"name": "РЕВОЛЬВЕР", "desc": "Шесть причин не останавливаться / точный выстрел", "damage": 52.0, "rate": 0.3, "reach": 70.0, "kind": "gun"},
	"discs": {"name": "МЕТАТЕЛЬНЫЕ ДИСКИ", "desc": "Пробивают толпу / возвращаются обратно", "damage": 34.0, "rate": 0.43, "reach": 28.0, "kind": "disc"},
	"rail": {"name": "РЕЛЬСОТРОН", "desc": "Луч насквозь / медленно и разрушительно", "damage": 105.0, "rate": 0.95, "reach": 85.0, "kind": "rail"},
	"scatter": {"name": "ИМПУЛЬСНЫЙ ДРОБОВИК", "desc": "Семь осколков / контроль ближней дистанции", "damage": 18.0, "rate": 0.62, "reach": 30.0, "kind": "shotgun"},
	"ember": {"name": "ЯДРО ОГНЯ", "desc": "Стартовое заклинание: Метеор / Q Q Q → F", "damage": 65.0, "rate": 0.65, "kind": "magic", "combo": "QQQ"},
	"frost": {"name": "ЯДРО ЛЬДА", "desc": "Стартовое заклинание: Абсолютный ноль / E E E → F", "damage": 45.0, "rate": 0.6, "kind": "magic", "combo": "EEE"},
	"storm": {"name": "ЯДРО МОЛНИИ", "desc": "Стартовое заклинание: Цепная молния / R R R → F", "damage": 42.0, "rate": 0.4, "kind": "magic", "combo": "RRR"}
}
# Keys are sorted: order of the three elements does not matter.
const SPELLS = {
	"QQQ": {"name": "МЕТЕОР", "damage": 85.0, "radius": 5.5, "rate": 0.85, "color": ORANGE},
	"EEE": {"name": "АБСОЛЮТНЫЙ НОЛЬ", "damage": 40.0, "radius": 7.0, "rate": 0.8, "color": CYAN},
	"RRR": {"name": "ЦЕПНАЯ МОЛНИЯ", "damage": 52.0, "radius": 8.0, "rate": 0.5, "color": VIOLET},
	"EQQ": {"name": "ПАРОВОЙ ВЗРЫВ", "damage": 75.0, "radius": 7.0, "rate": 0.85, "color": Color("ffb6a0")},
	"QQR": {"name": "ПЛАЗМА", "damage": 110.0, "radius": 3.0, "rate": 0.7, "color": ORANGE},
	"EEQ": {"name": "ЛЕДЯНЫЕ ОСКОЛКИ", "damage": 62.0, "radius": 5.0, "rate": 0.5, "color": CYAN},
	"EER": {"name": "МАГНИТНАЯ БУРЯ", "damage": 38.0, "radius": 9.0, "rate": 0.65, "color": CYAN},
	"QRR": {"name": "СОЛНЕЧНЫЙ ПРОБОЙ", "damage": 145.0, "radius": 2.0, "rate": 1.0, "color": Color("fff09a")},
	"ERR": {"name": "ПОЛЯРНЫЙ РАЗРЯД", "damage": 60.0, "radius": 6.0, "rate": 0.55, "color": VIOLET},
	"EQR": {"name": "СИНГУЛЯРНОСТЬ", "damage": 90.0, "radius": 9.0, "rate": 1.2, "color": Color("f191ff")}
}

static func spell_key(elements: String) -> String:
	var letters = elements.split("")
	letters.sort()
	return "".join(letters)
