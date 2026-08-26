# ──────────────────────────────────────────────────────────
# 01_config.R — Seed terms, URL patterns, analysis settings
#
# All search terms are stored as LEMMAS (dictionary forms).
# udpipe will lemmatise the corpus text, so we match lemma
# against lemma — no need to enumerate declensions manually.
# ──────────────────────────────────────────────────────────

# ── Site structure ────────────────────────────────────────
BASE_URL <- "https://www.president.gov.ua"

CATEGORIES <- list(
  speeches = list(
    label    = "Speeches and addresses",
    path     = "/news/speeches",
    type     = "speech",
    source   = "president.gov.ua"
  ),
  press_releases = list(
    label    = "News / Press releases",
    path     = "/news/all",
    type     = "press_release",
    source   = "president.gov.ua"
  ),
  rada_stenograms = list(
    label    = "Rada plenary stenograms",
    path     = "/meeting/stenogr/",
    type     = "rada_stenogram",
    source   = "rada.gov.ua"
  ),
  sbu_releases = list(
    label    = "SBU press releases",
    path     = "/news",
    type     = "sbu_press_release",
    source   = "sbu.gov.ua"
  )
)

DATE_START <- "2018-01-01"
DATE_END   <- "2025-12-31"

# ── Scraper settings ─────────────────────────────────────
REQUEST_DELAY  <- c(1.5, 3.0)   # runif range between requests (seconds)
REQUEST_TIMEOUT <- 30
MAX_RETRIES     <- 3
USER_AGENT <- paste0(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ",
  "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)

# ── Output paths ─────────────────────────────────────────
OUTPUT_DIR  <- "output"
CORPUS_DIR  <- file.path(OUTPUT_DIR, "corpus")

# ── Seed terms by coding dimension ───────────────────────
# Each term is a lemma. For multi-word terms, each word is
# a lemma. udpipe lemmatises the corpus, then we search the
# lemma stream for these.
#
# Ukrainian lemmas are primary; Russian counterparts are
# included for bilingual coverage (pre-2019 Rada records,
# some presidential statements).

SEED_TERMS <- list(

  # ── Church / religious actors ────────────────────────
  church_actors = list(
    description = "Terms identifying the churches and religious actors",
    terms_uk = c(
      "церква",               # church
      "упц",                  # UOC (abbreviation)
      "пцу",                  # OCU (abbreviation)
      "мп",                   # Moscow Patriarchate (abbrev.)
      "автокефалія",          # autocephaly
      "томос",                # tomos
      "православний",         # Orthodox (adj.)
      "православ'я",         # Orthodoxy
      "патріарх",             # patriarch
      "митрополит",           # metropolitan
      "єпархія",              # eparchy/diocese
      "парафія",              # parish
      "онуфрій",              # Onufriy
      "епіфаній",             # Epiphaniy
      "релігійний",           # religious (adj.)
      "конфесія",             # confession/denomination
      "священник",            # priest
      "монастир",             # monastery
      "лавра",                # lavra
      "києво-печерський"      # Kyiv-Pechersk
    ),
    terms_ru = c(
      "церковь", "упц", "пцу", "мп",
      "автокефалия", "томос", "православный",
      "православие", "патриарх", "митрополит",
      "епархия", "приход", "онуфрий", "епифаний",
      "религиозный", "конфессия", "священник",
      "монастырь", "лавра", "киево-печерский"
    ),
    # Multi-word terms (matched as consecutive lemma sequences)
    multiword_uk = c(
      "московський патріархат",
      "константинопольський патріарх"
    ),
    multiword_ru = c(
      "московский патриархат",
      "константинопольский патриарх"
    )
  ),

  # ── Material securitisation ─────────────────────────
  material_security = list(
    description = "Material security / threat to the physical state",
    terms_uk = c(
      "загроза",              # threat
      "колабораціонізм",      # collaborationism
      "колаборант",           # collaborator
      "диверсія",             # sabotage/subversion
      "шпигунство",           # espionage
      "агент",                # agent (of influence)
      "агентура",             # agent network
      "зрада",                # treason/betrayal
      "ворог",                # enemy
      "суверенітет",          # sovereignty
      "оборона",              # defence
      "сбу",                  # SBU (Security Service)
      "безпека",              # security
      "спецслужба",           # special/security service
      "контррозвідка",        # counterintelligence
      "санкція",              # sanction
      "підрив"                # undermining
    ),
    terms_ru = c(
      "угроза", "коллаборационизм", "коллаборант",
      "диверсия", "шпионаж", "агент", "агентура",
      "предательство", "враг", "суверенитет",
      "оборона", "сбу", "безопасность", "спецслужба",
      "контрразведка", "санкция", "подрыв"
    ),
    multiword_uk = c(
      "національний безпека",     # national security (lemma form)
      "п'ятий колона",            # fifth column
      "держава агресор",          # aggressor state
      "державний зрада",          # state treason
      "територіальний цілісність" # territorial integrity
    ),
    multiword_ru = c(
      "национальный безопасность",
      "пятый колонна",
      "государство агрессор",
      "государственный измена",
      "территориальный целостность"
    )
  ),

  # ── Ontological securitisation ──────────────────────
  ontological_security = list(
    description = "Ontological security / threat to the national self",
    terms_uk = c(
      "духовний",              # spiritual (adj.)
      "ідентичність",          # identity
      "самобутність",          # distinctiveness / uniqueness
      "самосвідомість"         # self-consciousness
    ),
    terms_ru = c(
      "духовный", "идентичность",
      "самобытность", "самосознание"
    ),
    multiword_uk = c(
      "духовний незалежність",     # spiritual independence
      "духовний безпека",          # spiritual security
      "київський русь",            # Kyivan Rus'
      "духовний суверенітет",      # spiritual sovereignty
      "національний ідентичність", # national identity
      "національний самосвідомість", # national self-consciousness
      "цивілізаційний вибір",      # civilisational choice
      "європейський вибір",        # European choice
      "духовний єдність",          # spiritual unity
      "національний єдність"       # national unity
    ),
    multiword_ru = c(
      "духовный независимость",
      "духовный безопасность",
      "киевский русь",
      "духовный суверенитет",
      "национальный идентичность",
      "национальный самосознание",
      "цивилизационный выбор",
      "европейский выбор",
      "духовный единство",
      "национальный единство"
    )
  ),

  # ── Decolonisation / restorative register ───────────
  decolonisation = list(
    description = "Decolonisation and identity-restorative language",
    terms_uk = c(
      "деколонізація",        # decolonisation
      "дерусифікація",        # de-Russification
      "визволення",           # liberation / casting off
      "звільнення",           # freeing / liberation
      "кайдани",              # shackles / fetters
      "деокупація",           # de-occupation
      "окупант",              # occupier
      "імперський",           # imperial (adj.)
      "колоніальний",         # colonial (adj.)
      "незалежність",         # independence
      "воля"                  # freedom / will
    ),
    terms_ru = c(
      "деколонизация", "дерусификация",
      "освобождение", "избавление", "оковы",
      "деоккупация", "оккупант", "имперский",
      "колониальный", "независимость", "воля"
    ),
    multiword_uk = c(
      "московський пута",     # Moscow's bonds
      "російський пута"       # Russian bonds
    ),
    multiword_ru = c(
      "московский путы",
      "российский путы"
    )
  ),

  # ── Urgency / existential intensity ─────────────────
  urgency = list(
    description = "Urgency, existential intensity, exceptional measures",
    terms_uk = c(
      "заборона",              # ban / prohibition
      "ліквідація",            # liquidation / dissolution
      "надзвичайний",          # extraordinary
      "негайний",              # urgent / immediate
      "рішучий",               # decisive
      "невідкладний",          # pressing / urgent
      "заборонити",            # to ban
      "ліквідувати",           # to liquidate / dissolve
      "припинити",             # to cease / terminate
      "розірвати"              # to sever / break
    ),
    terms_ru = c(
      "запрет", "ликвидация",
      "чрезвычайный", "немедленный", "решительный",
      "неотложный", "запретить", "ликвидировать",
      "прекратить", "разорвать"
    ),
    multiword_uk = c(
      "позбавлення громадянство",  # revocation of citizenship
      "ворог зсередини",           # enemy from within
      "внутрішній ворог"           # internal enemy
    ),
    multiword_ru = c(
      "лишение гражданство",
      "враг изнутри",
      "внутренний враг"
    )
  )
)

# ── Thesis junctures ─────────────────────────────────────
JUNCTURES <- list(
  "J1_autocephaly_2018-19"  = c("2018-01-01", "2019-05-19"),
  "J2_invasion_2022"        = c("2022-02-24", "2023-12-31"),
  "J3_law_2024"             = c("2024-01-01", "2024-12-31"),
  "J4_enforcement_2025"     = c("2025-01-01", "2025-12-31"),
  "interstitial_2019-2022"  = c("2019-05-20", "2022-02-23")
)
