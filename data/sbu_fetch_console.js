// ═══════════════════════════════════════════════════════════
// SBU Article Fetcher — paste this into Chrome DevTools Console
//
// 1. Open https://ssu.gov.ua in Chrome
// 2. Press F12 → Console tab
// 3. Paste this entire script and press Enter
// 4. Wait ~5-7 minutes (142 articles, 2s delay each)
// 5. A file "sbu_articles.json" will auto-download when done
// ═══════════════════════════════════════════════════════════

(async function() {
  const urls = ["https://ssu.gov.ua/novyny/komentar-pressluzhby-sbu-shchodo-zapobizhnoho-zakhodu-mytropolytu-pavlu-lebidiu","https://ssu.gov.ua/novyny/na-zaporizhzhi-do-7-rokiv-uviaznennia-zasudzheno-ahenta-terorystiv-dnr-yakyi-khotiv-pidpalyty-khram-upts","https://ssu.gov.ua/novyny/odne-z-pershocherhovykh-zavdan-sbu-vykryttia-derzhzradnykiv-ta-samoochyshchennia-sluzhby-vasyl-maliuk","https://ssu.gov.ua/novyny/sbu-likviduvala-shche-4-skhemy-dlia-ukhyliantiv-odniieiu-z-nykh-skorystavsia-kliryk-upts-mp","https://ssu.gov.ua/novyny/sbu-opublikuvala-perelik-osib-yaki-potrapyly-u-tserkovnyi-spysok-sanktsii-rnbo","https://ssu.gov.ua/novyny/sbu-pereviryla-monastyr-upts-mp-na-zakarpatti-de-chernytsi-zaklykaly-do-probuzhdenyia-matushkyrusy","https://ssu.gov.ua/novyny/sbu-pereviryla-prymishchennia-upts-mp-na-bukovyni-znaishly-metodychky-z-moskvy-rosiiske-hromadianstvo-ta-posvidchennia-okupantiv","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-novi-pidozry-mytropolytu-na-vinnychchyni-yakyi-vypravdovuvav-rosiisku-ahresiiu","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-arkhimandrytu-upts-mp-yakyi-blahoslovyv-saldo-na-feikovyi-referendum-rf","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-arkhimandrytu-upts-mp-z-melitopolia-yakyi-zaklykav-liudei-holosuvaty-na-psevdoreferendumi","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kerivnyku-cherkaskoi-yeparkhii-upts-mp","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-kyivskoho-monastyria-upts-mp-yakyi-vypravdovuvav-viinu-rf-proty-ukrainy","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-iz-kharkivshchyny-yakyi-proslavliav-rashystiv-na-telehramkanali-partii-iedyna-rosiia","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-na-cherkashchyni-yakyi-heroizuvav-rashystiv","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-na-zhytomyrshchyni-yakyi-vypravdovuvav-viinu-rf-proty-ukrainy","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-yakyi-ahituvav-za-pryiednannia-khersonshchyny-do-rf-i-rozfarbuvav-viznu-stelu-v-trykolor","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-yakyi-orhanizovuvav-provokatsii-u-kyievopecherskii-lavri","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-yakyi-razom-iz-saldo-zaklykav-do-pryiednannia-khersonshchyny-do-rf","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kliryku-upts-mp-z-cherkashchyny-yakyi-zaklykav-rf-zakhopyty-vsiu-ukrainu","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-kolaborantu-yakyi-buv-osobystym-radnykom-terorysta-strielkova","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-cherkaskoi-yeparkhii-upts-mp-video","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-i-sekretariu-upts-mp-z-zhytomyrshchyny-yaki-provokuvaly-relihiinu-vorozhnechu","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-kirovohradskoi-yeparkhii-upts-mp-yakyi-vypravdovuvav-zakhoplennia-krymu","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-odniiei-z-yeparkhii-upts-mp","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-sviatohirskoi-lavry-yakyi-pidkazav-rashystam-pozytsii-zsu-na-donechchyni","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-upts-mp-na-donechchyni-yakyi-poshyriuvav-feiky-pro-oborontsiv-ukrainy","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytu-upts-mp-pavlu-video","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-mytropolytuvtikachu-upts-mp-na-sumshchyni-yakyi-blahoslovliav-rosiiskykh-okupantiv","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-nastoiateliu-khramu-upts-mp-na-vinnychchyni-yakyi-vykhvaliav-terorystiv-zakharchenka-hivi-ta-motorolu","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-odnomu-iz-ochilnykiv-upts-mp-yakyi-zaklykav-pomolytysia-za-rashystiv-u-viini-proty-ukrainy","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-patriarkhu-rpts-kyrylu-yakyi-blahoslovyv-rashystiv-na-vbyvstva-ukraintsiv","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-pidsanktsiinomu-mytropolytu-upts-mp-iz-zaporizhzhia-yakyi-provokuvav-relihiinu-nenavyst","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-poslushnyku-upts-mp-yakyi-vypravdovuvav-rosiisku-ahresiiu","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-protoiiereiu-rpts-iz-krymu-yakyi-zaimaietsia-postachanniam-udarnykh-droniv-okupantam","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-rektoru-pochaivskoi-dukhovnoi-seminarii-upts-mp-yakyi-zdiisniuvav-antyukrainsku-diialnist","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-rosiiskomu-sviashchennykubloheru-rpts-yakyi-zaklykav-rosiiskykh-viiskovykh-vbyvaty-ukraintsiv","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-pidozru-shche-3m-prorosiiskym-ahitatoram-sered-yakykh-bloher-rpts-ta-shkilna-vchytelka-z-kyieva","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-zaochnu-pidozru-klirykuiuveliru-upts-mp-iz-luhanshchyny-yakyi-prodaie-zoloti-vyroby-do-rosii","https://ssu.gov.ua/novyny/sbu-povidomyla-pro-zaochnu-pidozru-mytropolytu-upts-mp-yakyi-blahoslovyv-pryiednannia-luhanska-do-rf","https://ssu.gov.ua/novyny/sbu-provela-obshuky-u-kerivnytstva-upts-mp-u-kirovohradskii-oblasti","https://ssu.gov.ua/novyny/sbu-provodyt-bezpekovi-zakhody-na-obiektakh-upts-mp-u-deviaty-oblastiakh-ukrainy","https://ssu.gov.ua/novyny/sbu-provodyt-bezpekovi-zakhody-na-obiektakh-upts-mp-u-poltavskii-oblasti","https://ssu.gov.ua/novyny/sbu-provodyt-bezpekovi-zakhody-na-obiektakh-upts-mp-u-trokh-oblastiakh-ukrainy","https://ssu.gov.ua/novyny/sbu-provodyt-bezpekovi-zakhody-na-obiektakh-upts-mp-u-trokh-oblastiakh-ukrainy-2","https://ssu.gov.ua/novyny/sbu-provodyt-bezpekovi-zakhody-u-kyievopecherskii-lavri","https://ssu.gov.ua/novyny/sbu-provodyt-bezpekovi-zakhody-v-mukachivskii-yeparkhii-upts-mp","https://ssu.gov.ua/novyny/sbu-provodyt-obshuky-u-pochaivskii-lavri-upts-mp","https://ssu.gov.ua/novyny/sbu-ta-natspolitsiia-likviduvaly-shche-4-skhemy-dlia-ukhyliantiv-na-kyivshchyni-ta-bukovyni","https://ssu.gov.ua/novyny/sbu-ta-natspolitsiia-vykryly-nastoiatelia-khramu-upts-mp-yakyi-pryvatyzuvav-tserkvu-na-kyivshchyni","https://ssu.gov.ua/novyny/sbu-ta-natspolitsiia-zablokuvaly-9-novykh-skhem-ukhylennia-vid-mobilizatsii-u-riznykh-rehionakh-ukrainy","https://ssu.gov.ua/novyny/sbu-ta-natspolitsiia-zatrymaly-shche-5-ahitatoriv-rashyzmu-v-riznykh-rehionakh-nashoi-derzhavy","https://ssu.gov.ua/novyny/sbu-ta-pravookhorontsi-ispanii-zatrymaly-kontrabandystiv-yaki-u-madrydi-khotily-prodaty-skifske-zoloto-z-ukrainy-na-ponad-60-mln-yevro-video","https://ssu.gov.ua/novyny/sbu-vidkryla-kryminalne-provadzhennia-shchodo-nastoiatelia-khramu-upts-mp-yakyi-dopomahav-rashystam-pid-chas-okupatsii-kyivshchyny","https://ssu.gov.ua/novyny/sbu-vyiavyla-antyukrainsku-literaturu-v-merezhi-tserkovnykh-lavok-upts-mp","https://ssu.gov.ua/novyny/sbu-vyiavyla-na-terytorii-kharkivskoi-yeparkhii-upts-mp-sotni-tysiach-hotivky-prokremlivsku-literaturu-ta-sukhpaiky-okupantiv","https://ssu.gov.ua/novyny/sbu-vyiavyla-pidozrilykh-osib-nezareiestrovanu-zbroiu-i-rosiiski-ahitky-na-obiektakh-upts-mp","https://ssu.gov.ua/novyny/sbu-vyiavyla-v-yeparkhiiakh-upts-mp-ahitatsiini-lystivky-obiednannia-medvedchuka-rosiiski-trykolory-ta-kolyshni-sklady-okupantiv","https://ssu.gov.ua/novyny/sbu-vyiavyla-v-yeparkhiiakh-upts-mp-propahandystski-metodychky-kremlia-vchennia-pro-satanizm-i-natsystsku-symvoliku","https://ssu.gov.ua/novyny/sbu-vyiavyla-v-yeparkhiiakh-upts-mp-rosiiski-pasporty-perepustky-federalnykh-radnykiv-rf-ta-prapor-novorosii","https://ssu.gov.ua/novyny/sbu-vyiavyla-v-yeparkhiiakh-upts-mp-rosiiski-pasporty-sklady-propahandystskoi-literatury-ta-perepustky-okupantiv","https://ssu.gov.ua/novyny/sbu-vykryla-dvokh-nastoiateliv-khramiv-upts-mp-yaki-vykhvalialy-putina-ta-poshyriuvaly-antysemitski-zaklyky","https://ssu.gov.ua/novyny/sbu-vykryla-dyiakona-upts-mp-yakyi-ahituvav-za-pryiednannia-zaporizhzhia-do-rf","https://ssu.gov.ua/novyny/sbu-vykryla-kliryka-upts-mp-yakyi-osviachuvav-rosiiskykh-viiskovykh-pid-chas-okupatsii-iziuma","https://ssu.gov.ua/novyny/sbu-vykryla-kolyshnoho-nastoiatelia-khramu-upts-mp-yakyi-blahoslovliav-rosiiskykh-viiskovykh-pid-chas-okupatsii-kharkivshchyny","https://ssu.gov.ua/novyny/sbu-vykryla-mytropolyta-odniiei-z-yeparkhii-upts-mp-na-roboti-v-interesakh-rf","https://ssu.gov.ua/novyny/sbu-vykryla-mytropolyta-upts-mp-pavla-na-novykh-faktakh-pidryvnoi-diialnosti-proty-ukrainy-video","https://ssu.gov.ua/novyny/sbu-vykryla-na-cherkashchyni-nastoiatelia-khramu-upts-mp-yakyi-vypravdovuvav-voienni-zlochyny-rashystiv","https://ssu.gov.ua/novyny/sbu-vykryla-na-khmelnychchyni-nastoiatelia-khramu-upts-mp-yakyi-vykhvaliav-putina-pered-virianamy","https://ssu.gov.ua/novyny/sbu-vykryla-na-zakarpatti-klirykaantysemita-upts-mp-yakyi-poshyriuvav-feiky-pro-viinu-v-ukraini","https://ssu.gov.ua/novyny/sbu-vykryla-na-zemelnykh-oborudkakh-nastoiatelku-khramu-upts-mp-na-cherkashchyni","https://ssu.gov.ua/novyny/sbu-vykryla-nastoiatelia-khramu-upts-mp-yakyi-vykhvaliav-okupantiv-i-ochikuvav-yikh-prykhodu-na-vinnychchynu","https://ssu.gov.ua/novyny/sbu-vykryla-nastoiatelia-odnoho-iz-khramiv-upts-mp-v-odesi-yakyi-vykhvaliav-putina-ta-heroizuvav-rosiiskykh-okupantiv","https://ssu.gov.ua/novyny/sbu-vykryla-prysluzhnyka-monastyria-upts-mp-na-zaklykakh-do-zakhoplennia-kyieva","https://ssu.gov.ua/novyny/sbu-vykryla-rpts-na-stvorenni-pravoslavnykh-pvk-dlia-viiny-v-ukraini","https://ssu.gov.ua/novyny/sbu-vykryla-shche-11-internetahitatoriv-yaki-poshyriuvaly-kremlivsku-propahandu-v-ukraini","https://ssu.gov.ua/novyny/sbu-vykryla-shche-3kh-vorozhykh-ahitatoriv-sered-nykh-provokator-upts-mp-yakyi-spodivavsia-otrymaty-vid-putina-rosiiskyi-pasport","https://ssu.gov.ua/novyny/sbu-vykryla-shche-4kh-prorosiiskykh-ahitatoriv-odyn-iz-nykh-zaklykav-katuvaty-ukrainskykh-polonenykh-a-inshyi-vdaryty-orieshnikom-po-kyievu","https://ssu.gov.ua/novyny/sbu-vykryla-shche-trokh-prorosiiskykh-internetahitatoriv-odyn-z-nykh-zaklykav-udaryty-orieshnikom-po-kyievu","https://ssu.gov.ua/novyny/sbu-vykryla-shche-trokh-prorosiiskykh-internetahitatoriv-yaki-vykhvalialy-zbroinu-ahresiiu-rf-ta-zaklykaly-ukraintsiv-sklasty-zbroiu","https://ssu.gov.ua/novyny/sbu-vykryla-shche-trokh-vorozhykh-ahitatoriv-odyn-iz-nykh-zaklykav-pidniaty-rosiiskyi-prapor-nad-khortytseiu","https://ssu.gov.ua/novyny/sbu-vykryla-trokh-klirykiv-upts-mp-yaki-heroizuvaly-rashystiv-i-chekaly-na-zakhoplennia-kyivskoi-ta-cherkaskoi-oblastei","https://ssu.gov.ua/novyny/sbu-vykryla-u-kharkovi-ta-na-cherkashchyni-shche-2-internetahitatoriv-rashyzmu","https://ssu.gov.ua/novyny/sbu-vykryla-u-zaporizhzhi-ahenturnu-merezhu-voiennoi-rozvidky-rf-yaku-koordynuvav-sviashchennyk-upts-mp","https://ssu.gov.ua/novyny/sbu-vykryla-v-odesi-klirykiv-upts-mp-yaki-vykhvalialy-rashyzm-i-vypravdovuvaly-voienni-zlochyny-rf","https://ssu.gov.ua/novyny/sbu-vykryla-vorozhoho-poplichnyka-v-riasi-yakyi-pratsiuvav-na-hauliaitera-kharkivshchyny","https://ssu.gov.ua/novyny/sbu-zaochno-povidomyla-pro-pidozru-holovnomu-viiskovomu-kapelanu-rf-yakyi-blahoslovyv-rashystiv-na-viinu-proty-ukrainy","https://ssu.gov.ua/novyny/sbu-zatrymala-6-internetahentiv-rf-odyn-z-nykh-zaklykav-do-henotsydu-ukraintsiv-ta-udariv-raketamy-satana-po-zakhidnykh-krainakh","https://ssu.gov.ua/novyny/sbu-zatrymala-dyiakona-upts-mp-ta-psykhoterapevta-yaki-na-zamovlennia-fsb-shpyhuvaly-za-oborontsiamy-kharkova","https://ssu.gov.ua/novyny/sbu-zatrymala-eksdyiakona-upts-mp-yakyi-vidpravliav-ukhyliantiv-za-kordon-pid-vyhliadom-tserkovnykh-misioneriv","https://ssu.gov.ua/novyny/sbu-zatrymala-informatorok-rosiiskoi-voiennoi-rozvidky-yaki-koryhuvaly-vorozhyi-vohon-po-pokrovsku","https://ssu.gov.ua/novyny/sbu-zatrymala-internetprovokatora-z-cherkas-yakyi-vykhvaliav-rashystiv-i-25-roku-perekhovuvavsia-v-monastyriakh-upts-mp","https://ssu.gov.ua/novyny/sbu-zatrymala-kliryka-upts-mp-yakyi-buv-informatorom-rf-i-shpyhuvav-za-oborontsiamy-kharkova","https://ssu.gov.ua/novyny/sbu-zatrymala-kliryka-upts-mp-yakyi-naviv-iskandery-po-odesi-u-berezni-2024-roku","https://ssu.gov.ua/novyny/sbu-zatrymala-kliryka-upts-mp-yakyi-pohodyvsia-shpyhuvaty-dlia-fsb-na-donechchyni-v-obmin-na-evakuatsiiu-yoho-simi-do-rosii","https://ssu.gov.ua/novyny/sbu-zatrymala-na-donechchyni-ahentku-fsb-yaka-pratsiuvala-na-rashystiv-cherez-zviazkovoho-z-upts-mp","https://ssu.gov.ua/novyny/sbu-zatrymala-nastoiatelia-khramu-upts-mp-yakyi-zbyrav-dlia-fsb-rozviddani-pro-oboronu-sumshchyny","https://ssu.gov.ua/novyny/sbu-zatrymala-okhorontsia-dytsadka-na-zaporizhzhi-yakyi-navodyv-rosiiski-rakety-na-budynky-myrnykh-ukraintsiv-video","https://ssu.gov.ua/novyny/sbu-zatrymala-protoiiereia-upts-mp-yakyi-na-zamovlennia-voiennoi-rozvidky-rf-koryhuvav-udary-rashystiv-po-sumshchyni","https://ssu.gov.ua/novyny/sbu-zatrymala-shche-5-prorosiiskykh-ahitatoriv-yaki-vypravdovuvaly-ahresiiu-rf-ta-zaklykaly-do-zakhoplennia-kyieva","https://ssu.gov.ua/novyny/sbu-zatrymala-sviashchennyka-upts-mp-yakyi-buv-ahentom-rosiiskoho-hru-i-hotuvav-udar-po-eshelonakh-zsu-na-kharkivshchyni-video","https://ssu.gov.ua/novyny/sbu-zatrymala-tserkovnu-khorystku-upts-mp-yaka-navodyla-vorozhi-rakety-na-pozytsii-zsu-poblyzu-zaporizhzhia","https://ssu.gov.ua/novyny/sbu-zatrymala-u-khersoni-sviashchennyka-upts-mp-yakyi-torhuvav-rosiiskoiu-zbroieiu-ta-boieprypasamy-video","https://ssu.gov.ua/novyny/sbu-zatrymala-u-kyievi-prokremlivskoho-blohera-yakyi-perekhovuvavsia-vid-pravosuddia-v-monastyri-upts-mp","https://ssu.gov.ua/novyny/sbu-zavershyla-rozsliduvannia-i-peredala-do-sudu-spravu-mytropolyta-upts-mp-pavla","https://ssu.gov.ua/novyny/sbu-znaishla-prorosiisku-literaturu-miliony-hotivky-u-riznii-valiuti-ta-sumnivnykh-hromadian-rf-pid-chas-bezpekovykh-zakhodiv-u-prymishchenniakh-upts-mp-video","https://ssu.gov.ua/novyny/sbu-znaishla-v-obiektakh-upts-mp-na-ternopilshchyni-ta-prykarpatti-propahandystski-materialy-shcho-zaperechuiut-isnuvannia-ukrainy","https://ssu.gov.ua/novyny/sbu-zneshkodyla-masshtabnu-ahenturnu-merezhu-fsb-yaka-pid-prykryttiam-upts-mp-namahalasia-destabilizuvaty-sytuatsiiu-v-ukraini-video","https://ssu.gov.ua/novyny/z-pochatku-povnomasshtabnoho-vtorhnennia-sbu-provela-ponad-36-tys-spetsoperatsii-zi-znyshchennia-rosiiskykh-okupantiv","https://ssu.gov.ua/novyny/z-pochatku-povnomasshtabnoho-vtorhnennia-viiskova-kontrrozvidka-sbu-vykryla-68-ahentiv-rf-u-sylakh-oborony","https://ssu.gov.ua/novyny/z-pochatku-povnomasshtabnoho-vtorhnennia-za-materialamy-sbu-rozpochato-ponad-200-kryminalnykh-provadzhen-shchodo-klirykiv-upts-mp","https://ssu.gov.ua/novyny/z-pochatku-povnomasshtabnoi-viiny-sbu-vykryla-52-viiskovosluzhbovtsiv-syl-oborony-yaki-buly-rosiiskymy-ahentamy","https://ssu.gov.ua/novyny/z-pochatku-povnomasshtabnoi-viiny-sbu-vykryla-ponad-60-klirykiv-upts-mp-yaki-pratsiuvaly-na-rf-prodavaly-zbroiu-i-dytiachu-pornohrafiiu","https://ssu.gov.ua/novyny/za-initsiatyvy-sbu-lytovskomu-dyplomatu-povernuly-kolektsiiu-ikon-yaki-rashysty-vykraly-z-yoho-rezydentsii-u-khersoni","https://ssu.gov.ua/novyny/za-materialamy-sbu-11-rokiv-tiurmy-zaochno-otrymav-mytropolyt-upts-mp-yakyi-blahoslovyv-viinu-rf-proty-ukrainy","https://ssu.gov.ua/novyny/za-materialamy-sbu-15-rokiv-tiurmy-otrymav-ahent-hru-rf-yakyi-shpyhuvav-dlia-voroha-na-zaporizhzhi","https://ssu.gov.ua/novyny/za-materialamy-sbu-15-rokiv-tiurmy-otrymav-ahent-rosiiskoi-voiennoi-rozvidky-yakyi-koryhuvav-udary-po-zaporizhzhiu","https://ssu.gov.ua/novyny/za-materialamy-sbu-15-rokiv-tiurmy-otrymav-kliryk-upts-mp-yakyi-koryhuvav-obstrily-donechchyny","https://ssu.gov.ua/novyny/za-materialamy-sbu-15-rokiv-tiurmy-otrymav-kliryk-upts-mp-yakyi-zlyvav-do-fsb-informatsiiu-pro-oboronu-sumshchyny","https://ssu.gov.ua/novyny/za-materialamy-sbu-5-rokiv-tiurmy-otrymav-nastoiatel-khramu-upts-mp-yakyi-vykhvaliav-putina-ta-ochikuvav-na-zakhoplennia-vinnychchyny","https://ssu.gov.ua/novyny/za-materialamy-sbu-7-rokiv-za-gratamy-provede-sviashchenyk-upts-mp-yakyi-zaklykav-meshkantsiv-donechchyny-pidtrymaty-rf-na-psevdoreferendumi","https://ssu.gov.ua/novyny/za-materialamy-sbu-do-12-rokiv-uviaznennia-zasudzheno-sviashchennyka-upts-mp-yakyi-zlyvav-pozytsii-zsu-v-sievierodonetsku","https://ssu.gov.ua/novyny/za-materialamy-sbu-do-5-rokiv-tiurmy-zasudzheno-mytropolyta-odniiei-z-vinnytskykh-yeparkhii-upts-mp-yakyi-vypravdovuvav-povnomasshtabne-vtorhnennia-rf","https://ssu.gov.ua/novyny/za-materialamy-sbu-mytropolyt-cherkaskoi-yeparkhii-upts-mp-otrymav-uzhe-chetvertu-pidozru","https://ssu.gov.ua/novyny/za-materialamy-sbu-pered-sudom-postane-mytropolyt-vinnytskoi-yeparkhii-upts-mp","https://ssu.gov.ua/novyny/za-materialamy-sbu-pered-sudom-postanut-ahenty-fsb-yaki-pid-prykryttiam-upts-mp-provodyly-informdyversii-proty-ukrainy","https://ssu.gov.ua/novyny/za-materialamy-sbu-pid-novi-tserkovni-sanktsii-rnbo-potrapyly-shche-7-klirykiv-upts-mp","https://ssu.gov.ua/novyny/za-materialamy-sbu-pidozru-otrymaly-dva-klirykykomunisty-upts-mp-na-zakarpatti","https://ssu.gov.ua/novyny/za-materialamy-sbu-pidozru-otrymav-eksposlushnyk-upts-mp-yakyi-vypravdovuvav-tymchasovu-okupatsiiu-donetska-ta-luhanska","https://ssu.gov.ua/novyny/za-materialamy-sbu-pidozru-otrymav-kerivnyk-sumskoi-yeparkhii-upts-mp-yakyi-zaklykav-virian-do-relihiinoi-nenavysti","https://ssu.gov.ua/novyny/za-materialamy-sbu-pidozru-otrymav-mytropolyt-upts-mp-z-bukovyny","https://ssu.gov.ua/novyny/za-materialamy-sbu-pidozru-otrymav-nastoiatel-khramu-upts-mp-na-zakarpatti","https://ssu.gov.ua/novyny/za-materialamy-sbu-pidozru-otrymav-sviashchennosluzhytel-upts-mp-na-bukovyni-yakyi-dopomahav-ukhyliantam-utikaty-vid-mobilizatsii","https://ssu.gov.ua/novyny/za-materialamy-sbu-po-15-rokiv-tiurmy-otrymaly-troie-ahentiv-fsb-yaki-dopomahaly-rashystam-proryvatysia-do-pokrovska","https://ssu.gov.ua/novyny/za-materialamy-sbu-poslushnyk-upts-mp-yakyi-vykhvaliav-rashystiv-provede-5-rokiv-za-gratamy","https://ssu.gov.ua/novyny/za-materialamy-sbu-povidomleno-pro-novu-pidozru-mytropolytu-cherkaskoi-yeparkhii-upts-mp-yakyi-pid-chas-domashnoho-areshtu-rozpaliuvav-relihiinu-vorozhnechu","https://ssu.gov.ua/novyny/za-materialamy-sbu-povidomleno-pro-pidozru-kliryku-upts-mp-na-zhytomyrshchyni-yakyi-rozdavav-virianam-kremlivski-ahitky","https://ssu.gov.ua/novyny/za-materialamy-sbu-prypyneno-hromadianstvo-ukrainy-oresta-berezovskoho-tak-zvanoho-mytropolyta-upts-mp-onufriia","https://ssu.gov.ua/novyny/za-materialamy-sbu-ta-natspolitsii-zaochnu-pidozru-otrymav-mytropolyt-upts-mp-yakyi-blahoslovyv-okupantiv-na-zakhoplennia-iziuma","https://ssu.gov.ua/novyny/za-materialamy-sbu-tiuremnyi-strok-otrymav-kliryk-upts-mp-na-dnipropetrovshchyni-yakyi-zaklykav-virian-dopomahaty-rashystam","https://ssu.gov.ua/novyny/za-materialamy-sbu-tiuremnyi-strok-otrymav-nastoiatel-khramu-upts-mp-yakyi-vykhvaliav-terorystiv-zakharchenka-hivi-ta-motorolu","https://ssu.gov.ua/novyny/za-materialamy-sbu-v-ukraini-vpershe-vynesly-vyrok-mytropolytu-upts-mp-vin-vyznav-shcho-vynen-u-zlochynakh","https://ssu.gov.ua/novyny/za-materialamy-sbu-zaochno-zasudzheno-arkhimandryta-upts-mp-yakyi-blahoslovyv-pryiednannia-khersona-do-skladu-rf"];

  const results = [];
  const failed = [];

  console.log(`Starting SBU article fetch: ${urls.length} URLs`);
  console.log("This will take ~5 minutes. Do not close this tab.");

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

      // Title: <h1> or <title>
      let title = "";
      const h1 = doc.querySelector("h1");
      if (h1) {
        title = h1.textContent.trim();
      } else {
        const t = doc.querySelector("title");
        if (t) title = t.textContent.trim();
      }

      // Date: look for date in meta tags or visible date elements
      let date = "";
      // Try meta property article:published_time
      const metaDate = doc.querySelector('meta[property="article:published_time"]');
      if (metaDate) {
        date = metaDate.getAttribute("content").substring(0, 10);
      }
      if (!date) {
        // Try common date selectors
        const dateEl = doc.querySelector(".date, .news-date, .article-date, time, [datetime]");
        if (dateEl) {
          date = dateEl.getAttribute("datetime") || dateEl.textContent.trim();
          if (date.length > 10) date = date.substring(0, 10);
        }
      }
      if (!date) {
        // Search body text for Ukrainian date pattern
        const bodyText = doc.body ? doc.body.textContent : "";
        const ukDateRe = /(\d{1,2})\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\s+(20[1-2]\d)/;
        const m = bodyText.match(ukDateRe);
        if (m) {
          const months = {січня:"01",лютого:"02",березня:"03",квітня:"04",травня:"05",червня:"06",липня:"07",серпня:"08",вересня:"09",жовтня:"10",листопада:"11",грудня:"12"};
          date = `${m[3]}-${months[m[2]]}-${m[1].padStart(2,"0")}`;
        }
      }

      // Body text: main content area
      let body = "";
      const contentSelectors = [
        ".article-content", ".news-content", ".content-block",
        ".field-item", ".text-content", "article", ".post-content",
        "main", ".page-content"
      ];
      for (const sel of contentSelectors) {
        const el = doc.querySelector(sel);
        if (el && el.textContent.trim().length > 100) {
          body = el.textContent.trim();
          break;
        }
      }
      if (!body) {
        // Fallback: all <p> inside body
        const paragraphs = doc.querySelectorAll("p");
        const texts = [];
        paragraphs.forEach(p => {
          const t = p.textContent.trim();
          if (t.length > 20) texts.push(t);
        });
        body = texts.join("\n\n");
      }

      if (body.length < 50) {
        console.warn(`  Very short body (${body.length} chars) — may be empty`);
      }

      results.push({ url, title, date, body });
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

  // Download as JSON
  const blob = new Blob([JSON.stringify({articles: results, failed: failed}, null, 2)],
                        {type: "application/json"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "sbu_articles.json";
  document.body.appendChild(a);
  a.click();
  a.remove();
  console.log("File sbu_articles.json downloaded!");
})();
