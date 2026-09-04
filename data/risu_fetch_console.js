// ═══════════════════════════════════════════════════════════
// RISU Article Fetcher — paste this into Chrome DevTools Console
//
// 1. Open https://risu.ua in Chrome
// 2. Press F12 → Console tab
// 3. Paste this entire script and press Enter
// 4. Wait ~10-12 minutes (268 articles, 2s delay each)
// 5. A file "risu_articles.json" will auto-download when done
// ═══════════════════════════════════════════════════════════

(async function() {
  const urls = [
    "https://risu.ua/prezident-i-cerkvi-ukrajini-oficiyno-prosyat-konstantinopol-nadati-tomos-pro-avtokefaliyu_n90315",
    "https://risu.ua/avtokefaliya-upc-pereosmislennya_n43597",
    "https://risu.ua/avtokefaliya-biloruskoyu_n105180",
    "https://risu.ua/shche-dvi-pravoslavni-cerkvi-mozhut-viznati-pcu-pislya-pandemiyi----poroshenko_n114362",
    "https://risu.ua/prezident-tomos-faktichno-shche-odin-akt-progoloshennya-nezalezhnosti-ukrajini_n93659",
    "https://risu.ua/ne-hodit-do-cerkvi-de-molyatsya-za-kirila-poroshenko-u-lucku_n95784",
    "https://risu.ua/nehay-sogodni-nas-pochuyut-u-konstantinopoli-v-moskvi-ta-vatikani-poroshenko-na-paradi-zayaviv-pro-pravo-upc-na-avtokefaliyu_n92646",
    "https://risu.ua/poroshenko-i-groysman-privitali-vladiku-filareta-z-88-littyam_n83074",
    "https://risu.ua/tomos-stav-strategiyeyu-ap-z-pershih-dniv-poroshenka-na-posadi-prezidenta-rostislav-pavlenko_n94572",
    "https://risu.ua/poroshenko-podyakuvav-yepiskopatu-upc-v-ssha-ta-kanadi-za-pdtrimku-pcu_n96292",
    "https://risu.ua/poroshenko-u-richnicyu-hreshchennya-rusi-ukrayini-ce-buv-ne-lishe-vibir-viri-a-j-vibir-civilizaciyi_n120370",
    "https://risu.ua/poroshenko-pidtrimuye-stvorennya-ukrajinskoji-avtokefalnoji-cerkvi-leonid-kravchuk_n82970",
    "https://risu.ua/poroshenko-pro-zahoplennya-hramiv-upc-mp-ya-pershim-stanu-na-zahist_n94896",
    "https://risu.ua/cerkva-konstantinopolya-ye-materinskoyu-cerkvoyu-ukrajinskoji-naciji-patriarh-varfolomiy-i-poroshenku_n78673",
    "https://risu.ua/petro-poroshenko-privitav-patriarha-svyatoslava-z-richniceyu-intronizaciyi_n117159",
    "https://risu.ua/chi-bude-povnocinnoyu-avtokefaliya-pravoslavnoji-cerkvi-v-ukrajini_n95297",
    "https://risu.ua/prezident-poroshenko-ne-vihodit-z-domu-bez-molitvi_n91158",
    "https://risu.ua/poroshenko-nagadav-yepiskopam-upc-mp-yak-u-1992-roci-voni-odnostayno-pragnuli-kanonichnoji-avtokefaliji_n77989",
    "https://risu.ua/poroshenko-privitav-predstoyatelya-pcu-epifaniya-z-dnem-narodzhennya-ta-pershoyu-richniceyu-intronizaciji_n102506",
    "https://risu.ua/petro-poroshenko-privitav-yudejiv-zi-svyatom-pesah_n73821",
    "https://risu.ua/poroshenko-peredav-ugkc-kompleks-keliy-monastirya-u-ternopoli_n97161",
    "https://risu.ua/predstoyatel-pcu-mi-vdyachni-poroshenkovi-za-tomos-ale-ni-za-kogo-ne-agituyemo_n97442",
    "https://risu.ua/tretya-richnicya-pcu-mitropolit-epifanij-nagorodiv-poroshenka-hrestom-za-zaslugi-pered-cerkvoyu_n124296",
    "https://risu.ua/do-manyavi-na-prikarpatti-privezli-tomos-pro-avtokefaliyu-pcu_n96518",
    "https://risu.ua/poroshenko-nagorodiv-ordenami-troh-mitropolitiv-pcu_n95749",
    "https://risu.ua/prezident-podyakuvav-vr-za-zvernennya-do-varfolomiya-i-shchodo-avtokefaliji-pravoslavnoji-cerkvi-v-ukrajini_n81084",
    "https://risu.ua/poroshenko-privitav-yudejiv-z-hanukoyu_n88196",
    "https://risu.ua/mi-na-pravilnomu-shlyahu-poroshenko-pro-rozriv-stosunkiv-mizh-moskvoyu-ta-konstantinopolem_n93768",
    "https://risu.ua/tomos-stav-geopolitichnoyu-katastrofoyu-rosiyi---poroshenko_n111410",
    "https://risu.ua/lavra-maye-buti-duhovnim-centrom-ukrayinskoyi-cerkvi--poroshenko_n135493",
    "https://risu.ua/poroshenko-papa-i-putin_n77093",
    "https://risu.ua/poroshenko-zaklikav-vru-zaboroniti-upc-mp_n144612",
    "https://risu.ua/lichnaya-mest-poroshenko-kak-u-zelenskogo-pomogayut-upc-mp-dushit-pcu_n109266",
    "https://risu.ua/pidzhak-i-gudzik-v-upc-mp-vidreaguvali-na-zvernennya-do-vselenskogo-patriarha-shchodo-avtokefaliji_n90320",
    "https://risu.ua/tomos-tur-prodovzhuyetsya-petro-poroshenko-i-mitropolit-epifaniy-vezut-tomos-na-prikarpattya_n96442",
    "https://risu.ua/poroshenko-patriarhu-filaretu-vasha-molitva-ves-chas-bula-z-ukrajinskim-narodom_n76623",
    "https://risu.ua/filaret-rozpoviv-pro-quot-tayemnu-ugodu-mizh-patriarhom-varfolomiyem-i-prezidentom-poroshenkom-quot_n98812",
    "https://risu.ua/ukrajinska-vlada-garantuye-povne-dotrimannya-religiynoji-svobodi-dlya-virnih-usih-konfesiy-poroshenko_n93656",
    "https://risu.ua/poroshenko-ta-yacenyuk-privitali-patriarha-filareta-iz-87-richchyam_n77885",
    "https://risu.ua/prezident-poroshenko-pidtrimuye-stvorennya-pomisnoji-cerkvi-v-ukrajini_n86469",
    "https://risu.ua/prezident-poroshenko-vnis-do-vru-zakonoproekt-pro-peredachu-andrijivskoji-cerkvi-vselenskomu-patriarhu_n93812",
    "https://risu.ua/sud-kiyeva-zobovyazav-dbr-vidnoviti-spravu-proti-poroshenka-cherez-tomos_n117017",
    "https://risu.ua/petro-poroshenko-pozhertvuvav-500-tis-grn-lvivskij-cerkvi_n111760",
    "https://risu.ua/neoficyniy-spiker-upc-mp-porivnyav-poroshenka-z-diyavolom_n90541",
    "https://risu.ua/azh-zirki-na-kremlivskih-shpilyah-pochornili-poroshenko-pro-isterichnu-reakciyu-kremlya-i-rpc-na-tomos_n95181",
    "https://risu.ua/zavtra-poroshenko-priveze-tomos-u-volinsku-oblast_n95767",
    "https://risu.ua/poroshenko-z-osobistih-koshtiv-oplativ-reklamu-pro-tomos-upc_n92439",
    "https://risu.ua/sinod-vselenskogo-patriarhatu-virishiv-rozpochati-proceduri-neobhidni-dlya-nadannya-avtokefaliji-poroshenko_n90434",
    "https://risu.ua/vidsidi-za-tomos-petya-moskva-vidkrito-rve-kigti-za-filareta_n109354",
    "https://risu.ua/kanonichna-avtokefaliya-ta-ukrajinska-hristiyanska-identichnist_n12724",
    "https://risu.ua/poroshenko-yak-tilki-pobachite-lyudey-yaki-zaklikatimut-vzyati-siloyu-lavru-znayte-to-moskovska-agentura_n93715",
    "https://risu.ua/hid-istoriji-ne-zupiniti-dali-bude-petro-poroshenko-pro-viznannya-pcu_n100982",
    "https://risu.ua/v-instituti-strategichnih-doslidzhen-poyasnili-znachennya-ugodi-mizh-prezidentom-ukrajini-i-varfolomiyem-i_n94219",
    "https://risu.ua/poroshenko-zaklikav-zelenskogo-sklikati-rnbo-za-pozovom-upc-mp-proti-pcu_n98729",
    "https://risu.ua/pidpisano-ugodu-pro-spivpracyu-mizh-ukrajinoyu-ta-vselenskim-patriarhatom_n94179",
    "https://risu.ua/poroshenko-vse-zh-taki-zustrivsya-z-chastinoyu-yepiskopatu-upc-mp_n94435",
    "https://risu.ua/zustrich-papi-rimskogo-z-poroshenkom-kontrastuvala-iz-zustrichchyu-z-putinim-religiyeznavec_n77066",
    "https://risu.ua/zmi-nazvali-imena-troh-yerarhiv-upc-mp-yaki-vse-zh-zustrilisya-z-poroshenkom_n94445",
    "https://risu.ua/petro-poroshenko-vzhe-pribuv-do-stambula_n95551",
    "https://risu.ua/klimkin-ziznavsya-hto-pershim-pidkinuv-poroshenku-ideyu-pro-tomos_n101558",
    "https://risu.ua/mitropolit-mitrofan-neviznana-avtokefaliya-i-rozkol-rizni-rechi_n71520",
    "https://risu.ua/na-poroshenka-podali-do-sudu-cherez-tomos_n93411",
    "https://risu.ua/poroshenko-zustrivsya-z-glavoyu-upc-v-ssha-konstantinopolskogo-patriarhatu_n85285",
    "https://risu.ua/ugkc-vitatime-stvorennya-yedinoji-pomisnoji-pravoslavnoji-cerkvi-ta-jiji-avtokefaliyu-ale-priyednuvatisya-ne-bude_n91805",
    "https://risu.ua/poroshenko-planuye-razom-iz-novoobranim-predstoyatelem-upc-pojihati-na-fanar_n94891",
    "https://risu.ua/okupanti-planuyut-zachistiti-zahopleni-teritoriyi-vid-nepidkontrolnih-kremlyu-cerkov--cns_n135219",
    "https://risu.ua/v-upc-mp-pyatogo-prezidenta-pririvnyali-do-posldovnika-satani_n123337",
    "https://risu.ua/avtokefaliya-ce-pitannya-nashoji-nezalezhnosti-i-nashoji-nacionalnoji-bezpeki-petro-poroshenko_n91938",
    "https://risu.ua/tomosniy-marafon-dovzhinoyu-u-rik_n97606",
    "https://risu.ua/petro-poroshenko-spodivayetsya-shcho-ukrajinski-yerarhi-dobre-usvidomlyuyut-svoyu-vidpovidalnist-za-ob-yednavchiy-sobor_n94839",
    "https://risu.ua/ekleziologiya-y-avtokefaliya-gostri-kuti_n38360",
    "https://risu.ua/poroshenko-proviv-zustrich-z-patriarhom-serbskoji-pravoslavnoji-cerkvi-irineyem_n91603",
    "https://risu.ua/mi-ne-damo-rosiji-rozigrati-cerkovnu-kartu-poroshenko_n73059",
    "https://risu.ua/prezident-poroshenko-vimagaye-pripiniti-napadi-na-ukrajinsku-cerkvu-v-krimu_n86393",
    "https://risu.ua/patriarh-ugkc-ta-prezident-rozvinchali-rosiyskiy-mif-shcho-avtokefaliya-vede-do-uniji-rechnik-upc-kp_n91830",
    "https://risu.ua/pravoslavna-revolyuciya-chi-vstigne-patriarh-varfolomiy-zminiti-istoriyu_n90494",
    "https://risu.ua/tomos-v-obmin-na-cukerki-patriarh-varfolomiy-vidpoviv-zhartom-na-zvinuvachennya-u-habari_n95369",
    "https://risu.ua/poroshenko-privitav-musulman-ukrajini-z-kurban-bayramom_n81157",
    "https://risu.ua/prezident-na-podyachnomu-molebni-za-otrimannya-tomosu-yednist-ce-te-chogo-zaraz-vkray-potrebuye-ukrajina_n95744",
    "https://risu.ua/rishennya-vselenskogo-patriarha-rozviyalo-imperski-ilyuziji-i-shovinistichni-fantaziji-moskvi-prezident-poroshenko_n93644",
    "https://risu.ua/petro-poroshenko-zaklikav-svit-pidtrimati-nezalezhnist-pravoslavnoji-cerkvi-ukrajini_n101299",
    "https://risu.ua/nashomu-pokolinnyu-vipalo-zavershiti-quot-povne-rozmoskovlennya-quot-cerkvi-petro-poroshenko_n93710",
    "https://risu.ua/marina-poroshenko-vidvidala-gromadu-ugkc-v-genuji_n71202",
    "https://risu.ua/prezident-vruchiv-visoku-derzhavnu-nagorodu-vselenskomu-patriarhu-varfolomiyu_n95572",
    "https://risu.ua/petro-poroshenko-zvernuvsya-do-uchasnikiv-coboru-vid-vas-zalezhit-maybutnye-ukrajini_n95145",
    "https://risu.ua/petro-poroshenko-privitav-yudejiv-iz-hanukoyu_n77229",
    "https://risu.ua/dbr-dali-shche-rik-na-rozsliduvannya-spravi-proti-poroshenka-za-stvorennya-pcu-ta-tomos_n120033",
    "https://risu.ua/poroshenko-yushchenko-ta-kuchma-vidreaguvali-na-smert-patriarha-filareta_n162884",
    "https://risu.ua/avtokefaliya-pitannya-nezalezhnosti-ukrajini-prezident-na-volodimirskiy-girci_n92067",
    "https://risu.ua/ya-garantuyu-shcho-ukrajina-povazhatime-religiyniy-vibir-i-svobodu-virospovidannya-kozhnoji-lyudini-petro-poroshenko-pislya-vruchennya-tomosu_n95595",
    "https://risu.ua/avtokefaliya-i-braterska-lyubov_n108159",
    "https://risu.ua/poroshenko-v-richnicyu-pidpisannya-tomosa-teper-navit-skeptiki-zrozumili-dlya-chogo-ce-bulo_n145249",
    "https://risu.ua/petro-poroshenko-zayaviv-shcho-yogo-komanda-zahishchatime-pcu-vid-revanshu-moskovskogo-patriarhatu_n97646",
    "https://risu.ua/nadannya-avtokefaliji-ukrajinskiy-cerkvi-podiya-spivstavna-referendumu-1-grudnya-pro-nashu-nezalezhnist-prezident_n94838",
    "https://risu.ua/tomos-i-sprava-proti-poroshenka-za-stvorennya-pcu-yakimi-budut-naslidki_n109448",
    "https://risu.ua/mi-ne-pitatimemo-dozvolu-ni-v-putina-ni-v-kirila-yak-nam-molitisya-v-yaki-hrami-hoditi-petro-poroshenko_n92932",
    "https://risu.ua/vidkrittya-pam-yatnika-mitropolitu-lipkivskomu-ta-podyachniy-moleben-za-tomos-proveli-u-cherkasah_n95845",
    "https://risu.ua/avtokefaliya-dlya-ukrajinskoji-cerkvi-sproba_n35911",
    "https://risu.ua/poroshenko-pobazhav-mitropolitu-epifaniyu-shvidkogo-oduzhannya_n125093",
    "https://risu.ua/prezident-poroshenko-zaklikav-pravoslavni-cerkvi-svitu-viznati-pcu_n95626",
    "https://risu.ua/vedushchiy-missioner-upc-rpc-zhdet-skoroy-smerti-poroshenko-i-zhelaet-novyh-pobed-putinu_n77040",
    "https://risu.ua/ugoda-mizh-ukrajinoyu-ta-konstantinopolem-oficiyniy-plan-nadannya-i-otrimannya-tomosu_n94192",
    "https://risu.ua/poroshenko-nazvav-datu-i-misce-provedennya-ob-yednavchogo-soboru-upc_n94909",
    "https://risu.ua/poroshenko-poprosiv-predstoyatelya-upc-mp-onufriya-dopomogti-u-zvilnenni-ukrajinskih-moryakiv_n94980",
    "https://risu.ua/poroshenko-zustrivsya-iz-yerusalimskim-patriarhom_n81406",
    "https://risu.ua/poroshenko-u-2020-roci-shche-dekilka-pomisnih-cerkov-viznayut-pcu-a-rpc-opinitsya-v-izolyaciji_n101667",
    "https://risu.ua/poroshenko-ta-varfolomiy-i-obgovorili-stvorennya-yedinoji-pomisnoji-ukrajinskoji-pravoslavnoji-cerkvi_n78662",
    "https://risu.ua/tomos-ochima-vvs-yak-ukrajinska-cerkva-yshla-do-avtokefaliji_n102002",
    "https://risu.ua/u-zelenskogo-pracyuyut-lyudi-yaki-lobiyuyut-interesi-rosijskoyi-cerkvi---poroshenko_n110689",
    "https://risu.ua/poroshenko-gotuye-zayavu-shchodo-znesennya-ukrajinskogo-hramu-v-rosiji_n81495",
    "https://risu.ua/avtokefaliya-privede-do-yednosti-pravoslavnih-v-ukrajini-varfolomiy-i_n94182",
    "https://risu.ua/prezident-nazvav-zvilnennya-zaruchnikiv-vazhlivoyu-peremogoyu-i-podyakuvav-cerkvam-za-molitvi_n88435",
    "https://risu.ua/glava-ugkc-obgovoriv-z-petrom-poroshenkom-pidsumki-vizitu-derzhsekretarya-vatikanu_n80140",
    "https://risu.ua/poroshenko-ukrajina-bula-matir-yu-dlya-rpc-a-ne-navpaki_n91616",
    "https://risu.ua/poroshenko-ne-vtruchatimetsya-u-skandal-z-yepiskopami-upc-mp-ocinku-dast-narod_n74263",
    "https://risu.ua/p-poroshenko-rosiyski-okupanti-na-donbasi-zakrivayut-baptistski-cerkvi-ta-vbivayut-svyashchenikiv_n77153",
    "https://risu.ua/vselenskiy-patriarh-varfolomiy-kinceva-cil-daruvati-ukrajinskiy-cerkvi-avtokefaliyu_n92057",
    "https://risu.ua/prezident-poroshenko-zaprosiv-vselenskogo-patriarha-varfolomiya-v-ukrajinu_n95564",
    "https://risu.ua/mitropolit-epifaniy-nazvav-brehlivim-gaslo-avtokefaliya-shlyah-do-uniji_n100780",
    "https://risu.ua/mitropolit-epifaniy-ta-marina-poroshenko-obgovorili-maybutnye-ukrajini_n97575",
    "https://risu.ua/u-rozstrilnih-spiskah-okupantiv-buli-poroshenko-i-vsi-prichetni-do-stvorennya-pcu_n128862",
    "https://risu.ua/glava-vzcz-upc-mp-poyasniv-riznicyu-mizh-nekanonichnimi-avtokefaliyami-rpc-i-upc-kp_n71550",
    "https://risu.ua/opalnyy-svyashchennik-igor-savva-o-konflikte-s-moskovskim-patriarhatom-quot-tam-mogut-skazat-pro-dnr-nashi-a-pro-poroshenko-karateli_n89721",
    "https://risu.ua/chto-iisus-hristos-sdelal-by-s-poroshenko-reakciya-rossiyskoy-propagandy-na-tomos_n96076",
    "https://risu.ua/ukrainskaya-avtokefaliya-kak-istoricheskaya-drama_n91518",
    "https://risu.ua/poroshenko-anonsuvav-uhvalennya-zakonoprektu-pro-zaboronu-upc-mp_n149621",
    "https://risu.ua/ukrajinska-avtokefaliya-aktivnist-nashoji-diplomatiji_n91385",
    "https://risu.ua/avtokefaliya-dlya-chaynikiv_n80173",
    "https://risu.ua/avtokefaliya_n40030",
    "https://risu.ua/v-avtokefalnu-cerkvu-nihto-nikogo-ne-quot-zaprosit-quot-silomic-poroshenko_n93916",
    "https://risu.ua/sered-15-zirok-avtokefalnih-pravoslavnih-cerkov-z-yavilasya-ukrajinska-zirochka-petro-poroshenko_n95556",
    "https://risu.ua/poroshenko-podaruvav-vertep-cerkvi-upc-kp_n88598",
    "https://risu.ua/avtokefaliya--pravoslavnoyi-cerkvi-v-ukrayini_n70294",
    "https://risu.ua/zatomosilosya-oglyad-tizhnevikiv-12-14-zhovtnya-2018-roku_n94282",
    "https://risu.ua/petro-poroshenko-pro-avtokefaliyu-lishe-zaraz-rosiya-zlyakalasya_n90461",
    "https://risu.ua/avtokefaliya-kiyeva_n37689",
    "https://risu.ua/tomos-vid-vselenskogo-patriarha-piar-chi-krok-do-pomisnoji-cerkvi_n90419",
    "https://risu.ua/tomosnu-spravu-proti-poroshenkaporusheno-za-zayavoyu-upc-kp---dbr_n109281",
    "https://risu.ua/poroshenko-nagorodiv-ordenami-dvoh-yerarhiv-upc-mp_n94849",
    "https://risu.ua/u-moskvi-vidreaguvali-na-slova-prezidenta-poklasti-kray-zalezhnosti-ukrajinskogo-pravoslav-ya-vid-rosiyskoji-cerkvi_n92653",
    "https://risu.ua/perestali-nadhoditi-groshi-spravu-proti-poroshenka-porushili-za-zayavoyu-filareta-u-2019-roci---zmi_n109288",
    "https://risu.ua/petro-poroshenko-sklav-prisyagu-prezidenta-ukrajini_n69175",
    "https://risu.ua/poroshenko-zaklikav-zhurnalistiv-oprilyudniti-prizvishcha-deputativ-pidtrimuyut-moskovskij-patriarhat-v-ukrayini_n148488",
    "https://risu.ua/avtokefaliya-ta-jiji-ukrajinskiy-vipadok_n91022",
    "https://risu.ua/ne-mozhna-zupiniti-ideyu-chas-yakoji-nastav-prezident-pro-nadannya-avtokefaliji-ukrajinskiy-pravoslavniy-cerkvi_n91802",
    "https://risu.ua/poroshenko-papa-i-putin_n77896",
    "https://risu.ua/ukrajinsku-pomisnu-avtokefalnu-cerkvu-stvoreno-petro-poroshenko_n95147",
    "https://risu.ua/do-yakih-naslidkiv-prizvede-ukrajinska-avtokefaliya_n91468",
    "https://risu.ua/boti-quot-bogoslovi-quot-vs-avtokefaliya_n108257",
    "https://risu.ua/vidterminuvannya-rishennya-pro-zaboronu-moskovskoyi-cerkvi-v-ukrayini-ye-zlochinom--poroshenko_n150122",
    "https://risu.ua/prosto-avtokefaliya_n94984",
    "https://risu.ua/petro-poroshenko-privitav-papu-franciska-z-79-richchyam_n77383",
    "https://risu.ua/poroshenko-proinformuvav-rnbo-pro-hid-peregovoriv-zi-vselenskim-patriarhom-varfolomiyem-pro-tomos_n90624",
    "https://risu.ua/poroshenko-spodivayetsya-shcho-z-ob-yednavchim-soborom-duhovenstvo-ne-zvolikatime_n94340",
    "https://risu.ua/poroshenko-ta-patriah-filaret-vidkrili-pam-yatnik-mazepi-u-poltavi_n79483",
    "https://risu.ua/poroshenko-zdobuv-drugu-nezalezhnist-vid-rosiji_n93935",
    "https://risu.ua/ukrajina-otrimaye-tomos-rishennya-vselenskogo-patriarhatu_n93642",
    "https://risu.ua/vazhlivo-prodovzhiti-proces-perehodiv-gromad-pcu-vid-cerkvi-okupanta---poroshenko_n131181",
    "https://risu.ua/sofiya-razdora-zachem-greko-katoliki-obideli-filareta-i-sdelali-neudobno-poroshenko-ros_n96725",
    "https://risu.ua/finlyandska-pravoslavna-cerkva-pidtrimuye-avtokefaliyu-upc_n94303",
    "https://risu.ua/sud-vidmovivsya-virishuvati-chi-mav-pravo-poroshenko-prositi-pro-tomos_n97179",
    "https://risu.ua/v-rpc-zaklikali-poroshenka-ne-vtruchatisya-u-spravi-cerkvi-i-nagolosili-shcho-v-ukrajini-vzhe-ye-pomisna-cerkva_n86477",
    "https://risu.ua/cogorich-svyatiy-mikolay-podaruvav-ukrajincyam-te-na-shcho-mi-chekali-tisyachu-rokiv-petro-poroshenko_n95241",
    "https://risu.ua/z-18-kvitnya-na-donbasi-ogolosyat-velikodnye-peremir-ya-poroshenko_n97542",
    "https://risu.ua/v-upc-kp-rozsekretili-tih-hto-podav-pozov-v-dbr-na-poroshenka_n109415",
    "https://risu.ua/cerkva-tilo-hristove-u-poslannyah-apostola-pavla-ta-avtokefaliya_n108164",
    "https://risu.ua/petro-poroshenko-vidreaguvav-na-konflikt-u-pcu_n98683",
    "https://risu.ua/rechnik-kijivskogo-patriarhatu-ne-odin-poroshenko-do-uv-yaznennya-i-lucenko-buv-prihilnikom-upc-mp_n90423",
    "https://risu.ua/ukrajinska-avtokefaliya-ye-nadiyeyu-i-dlya-rosiji-sergiy-chapnin_n93565",
    "https://risu.ua/petro-poroshenko-privitav-kijivski-duhovni-shkoli-z-400-litnim-yuvileyem_n76932",
    "https://risu.ua/vselenskomu-patriarhu-nadhodyat-pogrozi-z-moskvi-petro-poroshenko_n94989",
    "https://risu.ua/petro-poroshenko-zustrivsya-z-ekzarhami-vselenskogo-patriarhatu_n93116",
    "https://risu.ua/smelost-ot-ispuga-pochemu-mitropolit-onufriy-poshel-na-konflikt-s-poroshenko_n94478",
    "https://risu.ua/teper-vzhe-nashim-yerarham-nalezhit-provesti-ob-yednavchiy-sobor-i-obranomu-predstoyatelyu-vipade-chest-otrimati-tomos-prezident-poroshenko_n94804",
    "https://risu.ua/poroshenko-anonsuvav-rozglyad-zakonoproektu-pro-zaboronu-upc-mp-na-najblizhchomu-zasidanni-vr_n150237",
    "https://risu.ua/derzhava-i-vselenskiy-patriarh-zrobili-svoyu-spravu-zaraz-vsya-vidpovidalnist-na-uchasnikah-ob-yednavchogo-soboru-poroshenko_n94975",
    "https://risu.ua/arhiyereji-ugkc-ta-upc-kp-osvyatili-noviy-zavod-yakiy-urochisto-vidkriv-poroshenko_n86869",
    "https://risu.ua/obgovorili-mizhkonfesijnij-dialog-poroshenko-zustrivsya-z-patriarhom-ugkc_n120092",
    "https://risu.ua/petro-poroshenko-svitliy-ponedilok-provodit-u-lvovi_n97748",
    "https://risu.ua/poroshenko-zaklikav-konstantinopol-viznati-avtokefaliyu-ukrajinskoji-cerkvi_n85826",
    "https://risu.ua/poroshenko-zustrivsya-z-onufriyem-i-zaklikav-do-ob-yednannya-cerkov_n70298",
    "https://risu.ua/prezident-poroshenko-privitav-ukrajinciv-z-velikodnem_n97785",
    "https://risu.ua/poroshenko-ob-yednavchiy-sobor-mogli-zirvati-yak-minimum-p-yat-raziv_n95178",
    "https://risu.ua/rosiya-mertvo-vchepilasya-v-upc-mp-petro-poroshenko_n95505",
    "https://risu.ua/v-ukrajini-zaraz-virishuyetsya-dolya-svitovogo-pravoslav-ya-prezident-do-deputativ-vr_n93176",
    "https://risu.ua/patriarh-varfolomiy-pidpisav-tomos-pro-avtokefaliyu-pravoslavnoji-cerkvi-ukrajini_n95555",
    "https://risu.ua/ce-z-vashogo-blagoslovennya-rujnuyut-cerkvi-poroshenko-u-zrujnovanomu-hrami-zvernuvsya-do-kirila_n130811",
    "https://risu.ua/yak-poroshenko-konstantinopol-brav-istoriya-tomosu-dlya-ukrajinskogo-pravoslav-ya_n95776",
    "https://risu.ua/petro-poroshenko-privitav-ukrajinciv-z-vodohreshchem_n77801",
    "https://risu.ua/nas-vryatuvalo-odne-kiril-perekonav-putina-shcho-ce-nemozhlivo---poroshenko-pro-otrimannya-tomosu_n113106",
    "https://risu.ua/poroshenko-sogodni-u-stambuli-zustrinetsya-z-varfolomiyem-i_n94175",
    "https://risu.ua/siluvana-avtokefaliya-piti-shchob-zalishitisya_n74725",
    "https://risu.ua/zal-cerkovnyh-soborov-rpc-aplodiroval-natale-vitrenko-za-osuzhdenie-rukovodstva-upc-i-tak-nazyvaemogo-prezidenta-poroshenko_n69187",
    "https://risu.ua/ukrajinska-avtokefaliya-dvadcyat-rokiv-po-tomu_n37922",
    "https://risu.ua/mitropolit-upc-mp-zapidozriv-doktora-komarovskogo-u-spivpraci-z-poroshenkom-cherez-koronavirus-i-hresniy-hid_n103264",
    "https://risu.ua/kiril-govorun-odnostoronno-progoloshena-avtokefaliya-upc-mp-ne-matime-majbutnogo_n126780",
    "https://risu.ua/poroshenko-nagorodiv-arhiyepiskopa-upc-kp-ordenom-za-zaslugi-ii-stupenya_n82390",
    "https://risu.ua/poroshenko-rozpoviv-rumunskomu-patriarhu-pro-pragnennya-v-ukrajini-stvoriti-avtokefalnu-pomisnu-pravoslavnu-cerkvu_n79244",
    "https://risu.ua/hto-i-navishcho-podav-do-sudu-na-poroshenka-cherez-tomos_n93599",
    "https://risu.ua/ukrajina-otrimala-pravo-na-stvorennya-pomisnoji-sobornoji-pravoslavnoji-cerkvi-p-poroshenko_n92838",
    "https://risu.ua/poroshenko-zaklikav-cerkvi-spriyati-zvilnennyu-zaruchnikiv-z-polonu-donbaskih-teroristiv_n69453",
    "https://risu.ua/poroshenko-spodivayetsya-shcho-tomos-pro-avtokefaliyu-nadadut-do-1030-ji-richnici-hreshchennya-ukrajini-rusi_n91085",
    "https://risu.ua/posadit-todi-knyazya-volodimira-za-hreshchennya-rusi---ukrayinci-vidreaguvali-na-spravu-proti-poroshenka_n109327",
    "https://risu.ua/vlada-vistupaye-proti-stovpiv-duhovnoyi-nezalezhnosti-ukrayinskoyi-derzhavi---pavlenko_n109317",
    "https://risu.ua/poroshenko-i-avtokefaliya-posledniy-boy-on-vazhnyy-samyy_n90561",
    "https://risu.ua/poroshenko-pomolivsya-bilya-stini-plachu-za-blagopoluchchya-ukrajini_n95917",
    "https://risu.ua/poroshenko-bude-velikim-prezidentom-abo-bude-naybilshim-rozcharuvannyam-za-istoriyu-ukrajini-vladika-gudzyak_n69176",
    "https://risu.ua/moskovska-cerkva--ce-kdbistskij-priton-yakij-blagoslovlyaye-vbivstva-ukrayinciv---petro-poroshenko_n135282",
    "https://risu.ua/patriarh-varfolomij-avtokefaliya-ukrayinskoyi-cerkvi---nezminnij-fakt_n153904",
    "https://risu.ua/poroshenko-poprosiv-posla-polshchi-pidtrimati-proces-viznannya-pcu-z-boku-polskoyi-pravoslavnoyi-cerkvi_n110420",
    "https://risu.ua/ukrajini-ne-potribni-chotiri-rizni-pravoslavni-cerkvi-prezident-poroshenko_n90823",
    "https://risu.ua/poroshenko-poprosiv-bundestag-viznati-golodomor-genocidom_n83200",
    "https://risu.ua/cogo-roku-rizdvo-bude-duzhe-osoblivim-poroshenko_n95472",
    "https://risu.ua/trimati-shturval_n95517",
    "https://risu.ua/smozhet-li-poroshenko-pobedit-v-sebe-russkoe-pravoslavie_n69321",
    "https://risu.ua/poroshenko-zaklikav-vklyuchiti-v-poryadok-dennij-radi-zakoni-pro-zaboronu-rosijskoyi-cerkvi_n146024",
    "https://risu.ua/prezident-poroshenko-provede-zustrich-z-yepiskopatom-upc-mp_n94345",
    "https://risu.ua/petro-poroshenko-privitav-glavu-upc-kp-z-89-littyam_n88834",
    "https://risu.ua/poroshenko-deportaciya-krimskih-tatar-ce-spilniy-bil_n79634",
    "https://risu.ua/poroshenko-z-druzhinoyu-u-velikodnyu-nich-vzyali-uchast-u-bogosluzhinni-ta-pomolilisya-za-ukrajinu_n84364",
    "https://risu.ua/onlayn-konferenciya-quot-ds-quot-chi-zruynuye-ukrajinska-avtokefaliya-svitove-pravoslav-ya-video_n92000",
    "https://risu.ua/petro-poroshenko-privitav-predstoyatelya-pcu-iz-podvijnim-svyatom_n125729",
    "https://risu.ua/u-rpc-spodivayutsya-chto-tomos-postavit-krapku-na-politichniy-kar-yeri-poroshenka_n94668",
    "https://risu.ua/tomos-u-mishku-shcho-konstantinopol-virishiv-shchodo-ukrajini_n94837",
    "https://risu.ua/patriarh-filaret-privitav-prezidenta-z-rishennyam-sinodu-vselenskogo-patriarhatu-pro-avtokefaliyu_n93662",
    "https://risu.ua/cogo-roku-rizdvo-bude-duzhe-osoblivim-poroshenko_n95473",
    "https://risu.ua/mitropolit-onufriy-vshanuvav-chornobilciv-razom-iz-poroshenkom_n79329",
    "https://risu.ua/dobkin-kazhe-shcho-ce-vin-iniciyuvav-spravu-proti-poroshenka-za-tomos-ta-pcu_n109284",
    "https://risu.ua/emisari-z-susidnoji-krajini-namagalisya-pidkupiti-yerarhiv-shchobi-zirvati-proces-avtokefaliji-poroshenko_n90868",
    "https://risu.ua/pcu-vidznachaye-tretyu-richnicyu-otrimannya-tomosu_n124857",
    "https://risu.ua/poroshenko-zustrivsya-z-patriarhom-varfolomiyem_n124393",
    "https://risu.ua/poroshenko-vsechesni-otci-pidtrimali-konstituciynu-reformu_n79837",
    "https://risu.ua/filaret-nazvav-punkti-tomosu-z-yakimi-vin-ne-zgodniy_n98250",
    "https://risu.ua/petro-poroshenko-vidpoviv-na-zayavi-pro-te-shcho-filaret-iniciyuvav-proti-nogo--tomosnu-spravu_n109563",
    "https://risu.ua/poroshenko-pro-viryan-upc-mp-yakshcho-zmozhut-sobi-poyasniti-chomu-hodyat-u-moskovsku-cerkvu-nema-problem_n95729",
    "https://risu.ua/rada-povinna-zaboroniti-upc-mp---butaforiyu-rf-yaka-ne-maye-nichogo-spilnogo-z-cerkvoyu---poroshenko_n144775",
    "https://risu.ua/poroshenko-privitav-ukrajinskih-yudejiv-z-rosh-ga-shana_n92952",
    "https://risu.ua/ekzarhi-vselenskogo-patriarha-vid-imeni-varfolomiya-i-podyakuvali-poroshenku-za-zusillya-u-ob-yednanni-pravoslavnih-hristiyan-v-ukrajini_n93765",
    "https://risu.ua/ultimatum-filareta-i-ugovory-poroshenko-kak-izbirali-epifaniya_n95288",
    "https://risu.ua/dolya-svitovogo-pravoslav-ya-virishuyetsya-v-ukrajini-poroshenko_n93104",
    "https://risu.ua/gumor-ta-avtokefaliya_n108243",
    "https://risu.ua/dbr-rozsliduye-ne-tomos-a-pozov-filareta-do-poroshenka--tkachenko_n109349",
    "https://risu.ua/poroshenko-zaklikav-zaprovaditi-sankciyi-proti-rpc-ta-yiyi-ochilnika-kirila_n128713",
    "https://risu.ua/poroshenko-pidpisav-zakon-pro-peredachu-andrijivskoji-cerkvi-konstantinopolyu_n94286",
    "https://risu.ua/zahishchatimu-svobodu-religiynogo-viboru-tih-hto-priyme-rishennya-pereyti-do-pcu-prezident_n95805",
    "https://risu.ua/yak-narodzhuvalas-avtokefaliya-u-hersoni_n51422",
    "https://risu.ua/tomos-ili-termos-kak-filaret-pomogaet-vlasti-posadit-poroshenko_n109444",
    "https://risu.ua/petro-poroshenko-yanukovich-vichno-goritime-v-pekli_n73137",
    "https://risu.ua/ob-yednavchiy-sobor-ukrajinskoji-cerkvi-yak-vse-vidbuvalosya_n95245",
    "https://risu.ua/viprobuvannya-viri-chi-vplinula-religiya-na-golosuvannya-za-poroshenka_n102625",
    "https://risu.ua/poroshenko-kozhna-krajina-povinna-mati-svoyu-nezalezhnu-cerkvu_n90657",
    "https://risu.ua/poroshenko-oponentam-yakshcho-vi-cerkvu-movu-y-armiyu-vinosite-quot-za-duzhki-quot-to-vinesit-todi-y-ukrajinu_n97418",
    "https://risu.ua/quot-avtokefaliya-dovershit-utverdzhennya-nezalezhnosti-quot_n92498",
    "https://risu.ua/poroshenko-zvernuvsya-do-ukrayinciv-z-nagodi-drugoyi-richnici-pidpisannya-tomosu_n114876",
    "https://risu.ua/baptisti-z-yevropeyskoji-federaciji-pislya-pojizdki-na-donbas-zustrilisya-z-poroshenkom_n93497",
    "https://risu.ua/poroshenko-podyakuvav-varfolomiyu-i-za-pidtrimku-ukrajini_n93271",
    "https://risu.ua/proti-poroshenka-hochut-porushiti-kriminalnu-spravu-za-tomos-ta-stvorennya-pcu_n109275",
    "https://risu.ua/poroshenko-nazvav-zapiznilim-ale-pravilnim-rishennya-viznati-upc-mp-afilijovanoyu-z-rpc_n158448",
    "https://risu.ua/poroshenko-proponuye-peredati-andrijivsku-cerkvu-u-postiyne-koristuvannya-vselenskomu-patriarhu_n93762",
    "https://risu.ua/stalo-vidomo-yak-poroshenko-vitatime-ukrajinciv-z-velikodnem_n90155",
    "https://risu.ua/patriarh-varfolomiy-privitav-ukrajinciv-z-dnem-nezalezhnosti_n92652",
    "https://risu.ua/ce-bude-nayprimitnishe-rizdvo-prezident-pro-vruchennya-6-sichnya-tomosu_n95177",
    "https://risu.ua/poroshenko-proviv-telefonnu-rozmovu-iz-vselenskim-patriarhom_n124304",
    "https://risu.ua/avtokefaliya-pcu-dratuye-rosiyu-forbes_n103071",
    "https://risu.ua/pochesniy-patriarh-filaret-na-z-jizdi-batkivshchini-pohvaliv-poroshenka-za-tomos_n95926",
    "https://risu.ua/fundament-nashogo-domu-yedina-nezalezhna-soborna-ukrajina-z-nerozdilenoyu-cerkvoyu-petro-poroshenko-u-den-sobornosti_n95929",
    "https://risu.ua/polska-avtokefaliya-poglyad-kriz-desyatilittya_n39992",
    "https://risu.ua/predstavnik-ap-poviz-do-stambula-zvernennya-pro-nadannya-tomosu-poroshenko_n90405"
  ];

  const results = [];
  const failed = [];

  console.log(`Starting RISU article fetch: ${urls.length} URLs`);
  console.log("This will take ~10 minutes. Do not close this tab.");

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    const slug = url.split("/").pop();
    console.log(`[${i+1}/${urls.length}] ${slug}`);

    try {
      const resp = await fetch(url);
      if (!resp.ok) {
        console.warn(`  HTTP ${resp.status} — skipping`);
        failed.push({url, error: `HTTP ${resp.status}`});
        await new Promise(r => setTimeout(r, 1000));
        continue;
      }

      const html = await resp.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // Title: <h1> first, then <title>
      let title = "";
      const h1 = doc.querySelector("h1");
      if (h1) {
        title = h1.textContent.trim();
      } else {
        const t = doc.querySelector("title");
        if (t) title = t.textContent.trim();
      }

      // Date: try multiple strategies
      let date = "";
      // 1. Meta property article:published_time
      const metaDate = doc.querySelector('meta[property="article:published_time"]');
      if (metaDate) {
        date = metaDate.getAttribute("content").substring(0, 10);
      }
      // 2. Meta property article:modified_time as fallback
      if (!date) {
        const metaMod = doc.querySelector('meta[property="article:modified_time"]');
        if (metaMod) {
          date = metaMod.getAttribute("content").substring(0, 10);
        }
      }
      // 3. Common date selectors used by RISU
      if (!date) {
        const dateEl = doc.querySelector(".date, .news-date, .article-date, .post-date, time[datetime], [datetime]");
        if (dateEl) {
          const dt = dateEl.getAttribute("datetime") || dateEl.textContent.trim();
          if (/^\d{4}-\d{2}-\d{2}/.test(dt)) {
            date = dt.substring(0, 10);
          } else if (/^\d{2}\.\d{2}\.\d{4}/.test(dt)) {
            const p = dt.split(".");
            date = `${p[2]}-${p[1]}-${p[0]}`;
          }
        }
      }
      // 4. Ukrainian date pattern in page text
      if (!date) {
        const bodyText = doc.body ? doc.body.textContent : "";
        const ukDateRe = /(\d{1,2})\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\s+(20[0-2]\d)/;
        const m = bodyText.match(ukDateRe);
        if (m) {
          const months = {
            "січня":"01","лютого":"02","березня":"03","квітня":"04",
            "травня":"05","червня":"06","липня":"07","серпня":"08",
            "вересня":"09","жовтня":"10","листопада":"11","грудня":"12"
          };
          date = `${m[3]}-${months[m[2]]}-${m[1].padStart(2,"0")}`;
        }
      }

      // Body text: try RISU-specific selectors, then generic ones
      let body = "";
      const contentSelectors = [
        ".article-body", ".post-body", ".news-text", ".article-text",
        ".field-item", ".article-content", ".news-content",
        ".content-block", ".text-content", ".entry-content",
        "article .content", "article", "main .content", "main",
        ".page-content"
      ];
      for (const sel of contentSelectors) {
        const el = doc.querySelector(sel);
        if (el && el.textContent.trim().length > 100) {
          body = el.textContent.trim();
          break;
        }
      }
      // Fallback: concatenate all <p> tags with meaningful text
      if (!body || body.length < 100) {
        const paragraphs = doc.querySelectorAll("p");
        const texts = [];
        paragraphs.forEach(p => {
          const t = p.textContent.trim();
          if (t.length > 20) texts.push(t);
        });
        body = texts.join("\n\n");
      }

      if (body.length < 50) {
        console.warn(`  Very short body (${body.length} chars) — may need manual check`);
      }

      results.push({ url, title, date, body });
      console.log(`  OK: ${title.substring(0, 60)}... (${body.length} chars)`);
    } catch (e) {
      console.error(`  Error: ${e.message}`);
      failed.push({url, error: e.message});
    }

    // 2-second delay between requests
    await new Promise(r => setTimeout(r, 2000));
  }

  console.log(`\nDone! Fetched: ${results.length}, Failed: ${failed.length}`);
  if (failed.length > 0) {
    console.log("Failed URLs:", failed);
  }

  // Summary of short articles
  const shortOnes = results.filter(r => r.body.length < 100);
  if (shortOnes.length > 0) {
    console.log(`\nWarning: ${shortOnes.length} articles with very short body (<100 chars):`);
    shortOnes.forEach(r => console.log(`  ${r.url} (${r.body.length} chars)`));
  }

  // Download as JSON
  const blob = new Blob(
    [JSON.stringify({articles: results, failed: failed}, null, 2)],
    {type: "application/json"}
  );
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "risu_articles.json";
  document.body.appendChild(a);
  a.click();
  a.remove();
  console.log("File risu_articles.json downloaded!");
})();
