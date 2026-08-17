"""
Configuration for the Ukrainian presidential speech scraper.
All search terms, URL patterns, and analysis parameters.
"""

# ─────────────────────────────────────────────────────────
# Site structure for president.gov.ua
# ─────────────────────────────────────────────────────────
# The site changed structure between Poroshenko and Zelenskyy.
# These are the known URL patterns as of 2025.

BASE_URL = "https://www.president.gov.ua"

# Content categories to scrape
CATEGORIES = {
    "speeches": {
        "label_uk": "Виступи та звернення",
        "label_en": "Speeches and addresses",
        "listing_paths": [
            "/news/speeches",
        ],
        "content_type": "speech",
    },
    "press_releases": {
        "label_uk": "Новини",
        "label_en": "News / Press releases",
        "listing_paths": [
            "/news/all",
        ],
        "content_type": "press_release",
    },
}

# Date range
DATE_START = "2018-01-01"
DATE_END = "2025-12-31"

# ─────────────────────────────────────────────────────────
# Seed terms for corpus-assisted discourse analysis
# Organised by coding dimension, with Ukrainian and Russian
# lemma forms. pymorphy3 will expand these to all inflected
# surface forms automatically.
# ─────────────────────────────────────────────────────────

SEED_TERMS = {
    # ── Church / religious actors ──────────────────────
    "church_actors": {
        "description": "Terms identifying the churches and religious actors",
        "terms_uk": [
            "церква",           # church
            "УПЦ",              # UOC (abbreviation)
            "ПЦУ",              # OCU (abbreviation)
            "МП",               # Moscow Patriarchate (abbrev.)
            "автокефалія",      # autocephaly
            "томос",            # tomos
            "православний",     # Orthodox (adj.)
            "православ'я",     # Orthodoxy
            "патріарх",         # patriarch
            "митрополит",       # metropolitan
            "єпархія",          # eparchy/diocese
            "парафія",          # parish
            "Онуфрій",          # Onufriy
            "Епіфаній",         # Epiphaniy
            "Московський патріархат",  # Moscow Patriarchate
            "Константинопольський",    # Constantinopolitan
            "релігійний",       # religious (adj.)
            "конфесія",         # confession/denomination
            "священник",        # priest
            "монастир",         # monastery
            "лавра",            # lavra
            "Києво-Печерська",  # Kyiv-Pechersk (Lavra)
        ],
        "terms_ru": [
            "церковь",
            "УПЦ",
            "ПЦУ",
            "МП",
            "автокефалия",
            "томос",
            "православный",
            "православие",
            "патриарх",
            "митрополит",
            "епархия",
            "приход",
            "Онуфрий",
            "Епифаний",
            "Московский патриархат",
            "Константинопольский",
            "религиозный",
            "конфессия",
            "священник",
            "монастырь",
            "лавра",
            "Киево-Печерская",
        ],
    },

    # ── Material securitisation ────────────────────────
    "material_security": {
        "description": "Material security / threat to the physical state",
        "terms_uk": [
            "національна безпека",   # national security
            "загроза",               # threat
            "п'ята колона",          # fifth column
            "держава-агресор",       # aggressor state
            "колабораціонізм",       # collaborationism
            "колаборант",            # collaborator
            "диверсія",              # sabotage/subversion
            "шпигунство",            # espionage
            "агент",                 # agent (of influence)
            "агентура",              # agent network
            "зрада",                 # treason/betrayal
            "державна зрада",        # state treason
            "ворог",                 # enemy
            "суверенітет",           # sovereignty
            "територіальна цілісність",  # territorial integrity
            "оборона",              # defence
            "СБУ",                  # SBU (Security Service)
            "безпека",              # security
            "спецслужба",           # special/security service
            "контррозвідка",        # counterintelligence
            "санкція",              # sanction
            "підрив",               # undermining
        ],
        "terms_ru": [
            "национальная безопасность",
            "угроза",
            "пятая колонна",
            "государство-агрессор",
            "коллаборационизм",
            "коллаборант",
            "диверсия",
            "шпионаж",
            "агент",
            "агентура",
            "предательство",
            "государственная измена",
            "враг",
            "суверенитет",
            "территориальная целостность",
            "оборона",
            "СБУ",
            "безопасность",
            "спецслужба",
            "контрразведка",
            "санкция",
            "подрыв",
        ],
    },

    # ── Ontological securitisation ─────────────────────
    "ontological_security": {
        "description": "Ontological security / threat to the national self",
        "terms_uk": [
            "духовна незалежність",  # spiritual independence
            "духовна безпека",       # spiritual security
            "духовний",              # spiritual (adj.)
            "ідентичність",          # identity
            "Київська Русь",         # Kyivan Rus'
            "самобутність",          # distinctiveness / uniqueness
            "духовний суверенітет",   # spiritual sovereignty
            "національна ідентичність",  # national identity
            "національна самосвідомість", # national self-consciousness
            "цивілізаційний вибір",   # civilisational choice
            "європейський вибір",     # European choice
            "духовна єдність",        # spiritual unity
            "національна єдність",    # national unity
        ],
        "terms_ru": [
            "духовная независимость",
            "духовная безопасность",
            "духовный",
            "идентичность",
            "Киевская Русь",
            "самобытность",
            "духовный суверенитет",
            "национальная идентичность",
            "национальное самосознание",
            "цивилизационный выбор",
            "европейский выбор",
            "духовное единство",
            "национальное единство",
        ],
    },

    # ── Decolonisation / restorative register ──────────
    "decolonisation": {
        "description": "Decolonisation and identity-restorative language",
        "terms_uk": [
            "деколонізація",        # decolonisation
            "дерусифікація",        # de-Russification
            "визволення",           # liberation / casting off
            "звільнення",           # freeing / liberation
            "кайдани",              # shackles / fetters
            "московські пута",      # Moscow's bonds
            "російські пута",       # Russian bonds
            "деокупація",           # de-occupation
            "окупант",              # occupier
            "імперський",           # imperial (adj.)
            "колоніальний",         # colonial (adj.)
            "незалежність",         # independence
            "воля",                 # freedom / will
        ],
        "terms_ru": [
            "деколонизация",
            "дерусификация",
            "освобождение",
            "избавление",
            "оковы",
            "московские путы",
            "российские путы",
            "деоккупация",
            "оккупант",
            "имперский",
            "колониальный",
            "независимость",
            "воля",
        ],
    },

    # ── Urgency / existential intensity ────────────────
    "urgency": {
        "description": "Urgency, existential intensity, exceptional measures",
        "terms_uk": [
            "заборона",             # ban / prohibition
            "ліквідація",           # liquidation / dissolution
            "позбавлення громадянства",  # revocation of citizenship
            "надзвичайний",         # extraordinary
            "негайний",             # urgent / immediate
            "рішучий",              # decisive
            "невідкладний",         # pressing / urgent
            "ворог зсередини",      # enemy from within
            "внутрішній ворог",     # internal enemy
            "заборонити",           # to ban
            "ліквідувати",          # to liquidate / dissolve
            "припинити",            # to cease / terminate
            "розірвати",            # to sever / break
        ],
        "terms_ru": [
            "запрет",
            "ликвидация",
            "лишение гражданства",
            "чрезвычайный",
            "немедленный",
            "решительный",
            "неотложный",
            "враг изнутри",
            "внутренний враг",
            "запретить",
            "ликвидировать",
            "прекратить",
            "разорвать",
        ],
    },
}

# ─────────────────────────────────────────────────────────
# Scraper settings
# ─────────────────────────────────────────────────────────

REQUEST_DELAY = (1.5, 3.0)   # random delay range between requests (seconds)
REQUEST_TIMEOUT = 30          # HTTP timeout per request
MAX_RETRIES = 3               # retries on transient failures
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)

# Output paths (relative to project root)
OUTPUT_DIR = "output"
CORPUS_DIR = "output/corpus"           # full text of each document
RESULTS_FILE = "output/results.json"   # structured analysis results
SUMMARY_FILE = "output/summary.json"   # aggregate statistics
CLAIMS_FILE = "output/claims.json"     # individual claim extractions
