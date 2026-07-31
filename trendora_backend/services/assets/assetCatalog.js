'use strict';

const BIST_EQUITY_ROWS = Object.freeze([
  [
    "A1CAP",
    "A1 CAPİTAL YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "A1YEN",
    "A1 YENİLENEBİLİR ENERJİ ÜRETİM A.Ş."
  ],
  [
    "AAGYO",
    "AĞAOĞLU AVRASYA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ACSEL",
    "ACISELSAN ACIPAYAM SELÜLOZ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ADBNK",
    "ANADOLUBANK A.Ş."
  ],
  [
    "ADEL",
    "ADEL KALEMCİLİK TİCARET VE SANAYİ A.Ş."
  ],
  [
    "ADESE",
    "ADESE GAYRİMENKUL YATIRIM A.Ş."
  ],
  [
    "ADGYO",
    "ADRA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ADLVY",
    "ADİL VARLIK YÖNETİM A.Ş."
  ],
  [
    "AEFES",
    "ANADOLU EFES BİRACILIK VE MALT SANAYİİ A.Ş."
  ],
  [
    "AFYON",
    "AFYON ÇİMENTO SANAYİ T.A.Ş."
  ],
  [
    "AGESA",
    "AGESA HAYAT VE EMEKLİLİK A.Ş."
  ],
  [
    "AGHOL",
    "AG ANADOLU GRUBU HOLDİNG A.Ş."
  ],
  [
    "AGROT",
    "AGROTECH YÜKSEK TEKNOLOJİ VE YATIRIM A.Ş."
  ],
  [
    "AGYO",
    "ATAKULE GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AHGAZ",
    "AHLATCI DOĞAL GAZ DAĞITIM ENERJİ VE YATIRIM A.Ş."
  ],
  [
    "AHSGY",
    "AHES GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AKBNK",
    "AKBANK T.A.Ş."
  ],
  [
    "AKCNS",
    "AKÇANSA ÇİMENTO SANAYİ VE TİCARET A.Ş."
  ],
  [
    "AKCVR",
    "AKADEMİ ÇEVRE ENTEGRE ATIK YÖNETİMİ ENDÜSTRİ A.Ş."
  ],
  [
    "AKDFA",
    "AKDENİZ FAKTORİNG A.Ş."
  ],
  [
    "AKENR",
    "AKENERJİ ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "AKFGY",
    "AKFEN GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AKFIS",
    "AKFEN İNŞAAT TURİZM VE TİCARET A.Ş."
  ],
  [
    "AKFK",
    "AK FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "AKFYE",
    "AKFEN YENİLENEBİLİR ENERJİ A.Ş."
  ],
  [
    "AKGRT",
    "AKSİGORTA A.Ş."
  ],
  [
    "AKHAN",
    "AKHAN UN FABRİKASI VE TARIM ÜRÜNLERİ GIDA SANAYİ TİCARET A.Ş."
  ],
  [
    "AKMEN",
    "AK YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "AKMGY",
    "AKMERKEZ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AKSA",
    "AKSA AKRİLİK KİMYA SANAYİİ A.Ş."
  ],
  [
    "AKSEN",
    "AKSA ENERJİ ÜRETİM A.Ş."
  ],
  [
    "AKSFA",
    "AK FAKTORİNG A.Ş."
  ],
  [
    "AKSGY",
    "AKİŞ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AKSUE",
    "AKSU ENERJİ VE TİCARET A.Ş."
  ],
  [
    "AKTIF",
    "AKTİF YATIRIM BANKASI A.Ş."
  ],
  [
    "AKTVK",
    "AKTİF BANK SUKUK VARLIK KİRALAMA A.Ş."
  ],
  [
    "AKYHO",
    "AKDENİZ YATIRIM HOLDİNG A.Ş."
  ],
  [
    "ALARK",
    "ALARKO HOLDİNG A.Ş."
  ],
  [
    "ALBRK",
    "ALBARAKA TÜRK KATILIM BANKASI A.Ş."
  ],
  [
    "ALBTN",
    "ALBAYRAK HAZIR BETON SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ALCAR",
    "ALARKO CARRIER SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ALCTL",
    "ALCATEL LUCENT TELETAŞ TELEKOMÜNİKASYON A.Ş."
  ],
  [
    "ALFAS",
    "ALFA SOLAR ENERJİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ALGYO",
    "ALARKO GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ALJF",
    "ALJ FİNANSMAN A.Ş."
  ],
  [
    "ALKA",
    "ALKİM KAĞIT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ALKIM",
    "ALKİM ALKALİ KİMYA A.Ş."
  ],
  [
    "ALKLC",
    "ALTINKILIÇ GIDA VE SÜT SANAYİ TİCARET A.Ş."
  ],
  [
    "ALNUS",
    "ALNUS YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "ALTNY",
    "ALTINAY SAVUNMA TEKNOLOJİLERİ A.Ş."
  ],
  [
    "ALVES",
    "ALVES KABLO SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ANELE",
    "ANEL ELEKTRİK PROJE TAAHHÜT VE TİCARET A.Ş."
  ],
  [
    "ANGEN",
    "ANATOLİA TANI VE BİYOTEKNOLOJİ ÜRÜNLERİ ARAŞTIRMA GELİŞTİRME SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ANHYT",
    "ANADOLU HAYAT EMEKLİLİK A.Ş."
  ],
  [
    "ANSGR",
    "ANADOLU ANONİM TÜRK SİGORTA ŞİRKETİ"
  ],
  [
    "ARASE",
    "DOĞU ARAS ENERJİ YATIRIMLARI A.Ş."
  ],
  [
    "ARCLK",
    "ARÇELİK A.Ş."
  ],
  [
    "ARDYZ",
    "ARD GRUP BİLİŞİM TEKNOLOJİLERİ A.Ş."
  ],
  [
    "ARENA",
    "ARENA BİLGİSAYAR SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ARFYE",
    "ARF BİO YENİLENEBİLİR ENERJİ ÜRETİM A.Ş."
  ],
  [
    "ARMGD",
    "ARMADA GIDA TİCARET SANAYİ A.Ş."
  ],
  [
    "ARSAN",
    "ARSAN HOLDİNG A.Ş."
  ],
  [
    "ARSVY",
    "ARSAN VARLIK YÖNETİM A.Ş."
  ],
  [
    "ARTMS",
    "ARTEMİS HALI A.Ş."
  ],
  [
    "ARZUM",
    "ARZUM ELEKTRİKLİ EV ALETLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ASELS",
    "ASELSAN ELEKTRONİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ASGYO",
    "ASCE GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ASTOR",
    "ASTOR ENERJİ A.Ş."
  ],
  [
    "ASUZU",
    "ANADOLU ISUZU OTOMOTİV SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ATAGY",
    "ATA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ATAKP",
    "ATAKEY PATATES GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ATATP",
    "ATP YAZILIM VE TEKNOLOJİ A.Ş."
  ],
  [
    "ATATR",
    "ATA TURİZM İŞLETMECİLİK TAŞIMACILIK MADENCİLİK KUYUMCULUK SANAYİ VE DIŞ TİCARET A.Ş."
  ],
  [
    "ATAVK",
    "ATA VARLIK KİRALAMA A.Ş."
  ],
  [
    "ATAYM",
    "ATA YATIRIM MENKUL KIYMETLER A.Ş."
  ],
  [
    "ATEKS",
    "AKIN TEKSTİL A.Ş."
  ],
  [
    "ATLAS",
    "ATLAS MENKUL KIYMETLER YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ATLFA",
    "ATILIM FAKTORİNG A.Ş."
  ],
  [
    "ATSYH",
    "ATLANTİS YATIRIM HOLDİNG A.Ş."
  ],
  [
    "AVGYO",
    "AVRASYA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AVHOL",
    "AVRUPA YATIRIM HOLDİNG A.Ş."
  ],
  [
    "AVOD",
    "A.V.O.D. KURUTULMUŞ GIDA VE TARIM ÜRÜNLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "AVPGY",
    "AVRUPAKENT GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "AVTUR",
    "AVRASYA PETROL VE TURİSTİK TESİSLER YATIRIMLAR A.Ş."
  ],
  [
    "AYCES",
    "ALTIN YUNUS ÇEŞME TURİSTİK TESİSLER A.Ş."
  ],
  [
    "AYDEM",
    "AYDEM YENİLENEBİLİR ENERJİ A.Ş."
  ],
  [
    "AYEN",
    "AYEN ENERJİ A.Ş."
  ],
  [
    "AYES",
    "AYES ÇELİK HASIR VE ÇİT SANAYİ A.Ş."
  ],
  [
    "AYGAZ",
    "AYGAZ A.Ş."
  ],
  [
    "AZTEK",
    "AZTEK TEKNOLOJİ ÜRÜNLERİ TİCARET A.Ş."
  ],
  [
    "BAGFS",
    "BAGFAŞ BANDIRMA GÜBRE FABRİKALARI A.Ş."
  ],
  [
    "BAHKM",
    "BAHADIR KİMYA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BAKAB",
    "BAK AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BALAT",
    "BALATACILAR BALATACILIK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BALSU",
    "BALSU GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BANVT",
    "BANVİT BANDIRMA VİTAMİNLİ YEM SANAYİ A.Ş."
  ],
  [
    "BARMA",
    "BAREM AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BASCM",
    "BAŞTAŞ BAŞKENT ÇİMENTO SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BASGZ",
    "BAŞKENT DOĞALGAZ DAĞITIM GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "BAYRK",
    "BAYRAK EBT TABAN SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BEGYO",
    "BATI EGE GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "BERA",
    "BERA HOLDİNG A.Ş."
  ],
  [
    "BESLR",
    "BESLER GIDA VE KİMYA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BESTE",
    "BEST BRANDS GRUP ENERJİ YATIRIM A.Ş."
  ],
  [
    "BETAE",
    "BETA ENERJİ VE TEKNOLOJİ A.Ş."
  ],
  [
    "BEYAZ",
    "BEYAZ FİLO OTO KİRALAMA A.Ş."
  ],
  [
    "BFREN",
    "BOSCH FREN SİSTEMLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BIENY",
    "BİEN YAPI ÜRÜNLERİ SANAYİ TURİZM VE TİCARET A.Ş."
  ],
  [
    "BIGCH",
    "BÜYÜK ŞEFLER GIDA TURİZM TEKSTİL DANIŞMANLIK ORGANİZASYON EĞİTİM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BIGEN",
    "BİRLEŞİM GRUP ENERJİ YATIRIMLARI A.Ş."
  ],
  [
    "BIGTK",
    "BİG MEDYA TEKNOLOJİ A.Ş."
  ],
  [
    "BIMAS",
    "BİM BİRLEŞİK MAĞAZALAR A.Ş."
  ],
  [
    "BINBN",
    "BİN ULAŞIM VE AKILLI ŞEHİR TEKNOLOJİLERİ A.Ş."
  ],
  [
    "BINHO",
    "1000 YATIRIMLAR HOLDİNG A.Ş."
  ],
  [
    "BIOEN",
    "BİOTREND ÇEVRE VE ENERJİ YATIRIMLARI A.Ş."
  ],
  [
    "BIZIM",
    "BİZİM TOPTAN SATIŞ MAĞAZALARI A.Ş."
  ],
  [
    "BJKAS",
    "BEŞİKTAŞ FUTBOL YATIRIMLARI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BLCYT",
    "BİLİCİ YATIRIM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BLKOM",
    "BİLKOM BİLİŞİM HİZMETLERİ A.Ş."
  ],
  [
    "BLSMD",
    "BULLS YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "BLUME",
    "BLUME METAL KİMYA A.Ş."
  ],
  [
    "BMSCH",
    "BMS ÇELİK HASIR SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BMSTL",
    "BMS BİRLEŞİK METAL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BNPPI",
    "BNP PARIBAS ISSUANCE B.V."
  ],
  [
    "BNTAS",
    "BANTAŞ BANDIRMA AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BOBET",
    "BOĞAZİÇİ BETON SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BORLS",
    "BORLEASE OTOMOTİV A.Ş."
  ],
  [
    "BORSK",
    "BOR ŞEKER A.Ş."
  ],
  [
    "BOSSA",
    "BOSSA TİCARET VE SANAYİ İŞLETMELERİ T.A.Ş."
  ],
  [
    "BRGAN",
    "BURGAN BANK A.Ş."
  ],
  [
    "BRGFK",
    "BURGAN FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "BRISA",
    "BRİSA BRİDGESTONE SABANCI LASTİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BRKO",
    "BİRKO BİRLEŞİK KOYUNLULULAR MENSUCAT TİCARET VE SANAYİ A.Ş."
  ],
  [
    "BRKSN",
    "BERKOSAN YALITIM VE TECRİT MADDELERİ ÜRETİM VE TİCARET A.Ş."
  ],
  [
    "BRKT",
    "BEREKET VARLIK KİRALAMA A.Ş."
  ],
  [
    "BRKVY",
    "BİRİKİM VARLIK YÖNETİM A.Ş."
  ],
  [
    "BRLSM",
    "BİRLEŞİM MÜHENDİSLİK ISITMA SOĞUTMA HAVALANDIRMA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BRMEN",
    "BİRLİK MENSUCAT TİCARET VE SANAYİ İŞLETMESİ A.Ş."
  ],
  [
    "BRSAN",
    "BORUSAN BİRLEŞİK BORU FABRİKALARI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BRYAT",
    "BORUSAN YATIRIM VE PAZARLAMA A.Ş."
  ],
  [
    "BSOKE",
    "BATIÇİM ÇİMENTO SANAYİ A.Ş."
  ],
  [
    "BTCIM",
    "BATIÇİM BATI ANADOLU SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BUCIM",
    "BURSA ÇİMENTO FABRİKASI A.Ş."
  ],
  [
    "BULGS",
    "BULLS GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "BURCE",
    "BURÇELİK BURSA ÇELİK DÖKÜM SANAYİİ A.Ş."
  ],
  [
    "BURVA",
    "BURÇELİK VANA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BVSAN",
    "BÜLBÜLOĞLU VİNÇ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "BYDNR",
    "BAYDÖNER RESTORANLARI A.Ş."
  ],
  [
    "CAGFA",
    "ÇAĞDAŞ FAKTORİNG A.Ş."
  ],
  [
    "CANTE",
    "ÇAN2 TERMİK A.Ş."
  ],
  [
    "CASA",
    "CASA EMTİA PETROL KİMYEVİ VE TÜREVLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CATES",
    "ÇATES ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "CCOLA",
    "COCA-COLA İÇECEK A.Ş."
  ],
  [
    "CELHA",
    "ÇELİK HALAT VE TEL SANAYİİ A.Ş."
  ],
  [
    "CEMAS",
    "ÇEMAŞ DÖKÜM SANAYİ A.Ş."
  ],
  [
    "CEMTS",
    "ÇEMTAŞ ÇELİK MAKİNA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CEMZY",
    "CEM ZEYTİN A.Ş."
  ],
  [
    "CEOEM",
    "CEO EVENT MEDYA A.Ş."
  ],
  [
    "CGCAM",
    "ÇAĞDAŞ CAM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CIMSA",
    "ÇİMSA ÇİMENTO SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CLEBI",
    "ÇELEBİ HAVA SERVİSİ A.Ş."
  ],
  [
    "CLKMT",
    "ÇELİK MOTOR TİCARET A.Ş."
  ],
  [
    "CMBTN",
    "ÇİMBETON HAZIRBETON VE PREFABRİK YAPI ELEMANLARI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CMENT",
    "ÇİMENTAŞ İZMİR ÇİMENTO FABRİKASI T.A.Ş."
  ],
  [
    "CMSAN",
    "ÇAMSAN ENTEGRE AĞAÇ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CONSE",
    "CONSUS ENERJİ İŞLETMECİLİĞİ VE HİZMETLERİ A.Ş."
  ],
  [
    "COSMO",
    "COSMOS YATIRIM HOLDİNG A.Ş."
  ],
  [
    "CRDFA",
    "CREDITWEST FAKTORİNG A.Ş."
  ],
  [
    "CRFSA",
    "CARREFOURSA CARREFOUR SABANCI TİCARET MERKEZİ A.Ş."
  ],
  [
    "CUSAN",
    "ÇUHADAROĞLU METAL SANAYİ VE PAZARLAMA A.Ş."
  ],
  [
    "CVKMD",
    "CVK MADEN İŞLETMELERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "CWENE",
    "CW ENERJİ MÜHENDİSLİK TİCARET VE SANAYİ A.Ş."
  ],
  [
    "DAGI",
    "DAGİ GİYİM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DAPGM",
    "DAP GAYRİMENKUL GELİŞTİRME A.Ş."
  ],
  [
    "DARDL",
    "DARDANEL ÖNENTAŞ GIDA SANAYİ A.Ş."
  ],
  [
    "DCTTR",
    "DCT TRADİNG DIŞ TİCARET A.Ş."
  ],
  [
    "DENFA",
    "DENİZ FAKTORİNG A.Ş."
  ],
  [
    "DENGE",
    "DENGE YATIRIM HOLDİNG A.Ş."
  ],
  [
    "DENVA",
    "DENGE VARLIK YÖNETİM A.Ş."
  ],
  [
    "DERHL",
    "DERLÜKS YATIRIM HOLDİNG A.Ş."
  ],
  [
    "DERIM",
    "DERİMOD KONFEKSİYON AYAKKABI DERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DESA",
    "DESA DERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DESPC",
    "DESPEC BİLGİSAYAR PAZARLAMA VE TİCARET A.Ş."
  ],
  [
    "DEVA",
    "DEVA HOLDİNG A.Ş."
  ],
  [
    "DFKTR",
    "DORUK FAKTORİNG A.Ş."
  ],
  [
    "DGATE",
    "DATAGATE BİLGİSAYAR MALZEMELERİ TİCARET A.Ş."
  ],
  [
    "DGGYO",
    "DOĞUŞ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "DGNMO",
    "DOĞANLAR MOBİLYA GRUBU İMALAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DGRVK",
    "DEĞER VARLIK KİRALAMA A.Ş."
  ],
  [
    "DIMES",
    "DİMES GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DIRIT",
    "DİRİTEKS DİRİLİŞ TEKSTİL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DITAS",
    "DİTAŞ BDY YEDEK PARÇA İMALAT VE TEKNİK A.Ş."
  ],
  [
    "DKVRL",
    "DK VARLIK KİRALAMA A.Ş."
  ],
  [
    "DMLKT",
    "EMLAK KONUT DAMLA KENT GMS"
  ],
  [
    "DMRGD",
    "DMR UNLU MAMULLER ÜRETİM GIDA TOPTAN PERAKENDE İHRACAT A.Ş."
  ],
  [
    "DMSAS",
    "DEMİSAŞ DÖKÜM EMAYE MAMÜLLERİ SANAYİ A.Ş."
  ],
  [
    "DNFIN",
    "DENİZ FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "DNISI",
    "DİNAMİK ISI MAKİNA YALITIM MALZEMELERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DNYVA",
    "DÜNYA VARLIK YÖNETİM A.Ş."
  ],
  [
    "DNZEN",
    "DENİZ EKO ENERJİ VE GERİ DÖNÜŞÜM A.Ş."
  ],
  [
    "DOAS",
    "DOĞUŞ OTOMOTİV SERVİS VE TİCARET A.Ş."
  ],
  [
    "DOCO",
    "DO & CO AKTIENGESELLSCHAFT"
  ],
  [
    "DOFER",
    "DOFER YAPI MALZEMELERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DOFRB",
    "DOF ROBOTİK SANAYİ A.Ş."
  ],
  [
    "DOGUB",
    "DOĞUSAN BORU SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DOGVY",
    "DOĞRU VARLIK YÖNETİM A.Ş."
  ],
  [
    "DOHOL",
    "DOĞAN ŞİRKETLER GRUBU HOLDİNG A.Ş."
  ],
  [
    "DOKTA",
    "DÖKTAŞ DÖKÜMCÜLÜK TİCARET VE SANAYİ A.Ş."
  ],
  [
    "DRPHN",
    "T.C. HAZİNE VE MALİYE BAKANLIĞI DARPHANE VE DAMGA MATBAASI GENEL MÜDÜRLÜĞÜ"
  ],
  [
    "DSTKF",
    "DESTEK FİNANS FAKTORİNG A.Ş."
  ],
  [
    "DSYAT",
    "DESTEK YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "DUNYH",
    "DÜNYA HOLDİNG A.Ş."
  ],
  [
    "DURDO",
    "DURAN DOĞAN BASIM VE AMBALAJ SANAYİ A.Ş."
  ],
  [
    "DURKN",
    "DURUKAN ŞEKERLEME SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DVRLK",
    "D VARLIK KİRALAMA A.Ş."
  ],
  [
    "DYBNK",
    "D YATIRIM BANKASI A.Ş."
  ],
  [
    "DYOBY",
    "DYO BOYA FABRİKALARI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "DZGYO",
    "DENİZ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "EBEBK",
    "EBEBEK MAĞAZACILIK A.Ş."
  ],
  [
    "ECILC",
    "EİS ECZACIBAŞI İLAÇ SINAİ VE FİNANSAL YATIRIMLAR SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ECOGR",
    "ECOGREEN ENERJİ HOLDİNG A.Ş."
  ],
  [
    "ECZIP",
    "EİP ECZACIBAŞI İLAÇ PAZARLAMA A.Ş."
  ],
  [
    "ECZYT",
    "ECZACIBAŞI YATIRIM HOLDİNG ORTAKLIĞI A.Ş."
  ],
  [
    "EDATA",
    "E-DATA TEKNOLOJİ PAZARLAMA A.Ş."
  ],
  [
    "EDIP",
    "EDİP GAYRİMENKUL YATIRIM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EFOR",
    "EFOR YATIRIM SANAYİ TİCARET A.Ş."
  ],
  [
    "EGEEN",
    "EGE ENDÜSTRİ VE TİCARET A.Ş."
  ],
  [
    "EGEGY",
    "EGEYAPI AVRUPA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "EGEPO",
    "NASMED ÖZEL SAĞLIK HİZMETLERİ TİCARET A.Ş."
  ],
  [
    "EGGUB",
    "EGE GÜBRE SANAYİİ A.Ş."
  ],
  [
    "EGPRO",
    "EGE PROFİL TİCARET VE SANAYİ A.Ş."
  ],
  [
    "EGSER",
    "EGE SERAMİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EKDMR",
    "EKİNCİLER DEMİR VE ÇELİK SANAYİ A.Ş."
  ],
  [
    "EKER",
    "EKER SÜT ÜRÜNLERİ GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EKGYO",
    "EMLAK KONUT GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "EKIM",
    "EKİM TURİZM TİCARET VE SANAYİ A.Ş."
  ],
  [
    "EKIZ",
    "EKİZ KİMYA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EKOFA",
    "EKO FAKTORİNG A.Ş."
  ],
  [
    "EKOS",
    "EKOS TEKNOLOJİ VE ELEKTRİK A.Ş."
  ],
  [
    "EKSUN",
    "EKSUN GIDA TARIM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EKTVK",
    "EMLAK KATILIM VARLIK KİRALAMA A.Ş."
  ],
  [
    "ELITE",
    "ELİTE NATUREL ORGANİK GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EMIRV",
    "EMİR VARLIK YÖNETİM A.Ş."
  ],
  [
    "EMKEL",
    "EMEK ELEKTRİK ENDÜSTRİSİ A.Ş."
  ],
  [
    "EMNIS",
    "EMİNİŞ AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EMPAE",
    "EMPA ELEKTRONİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EMVAR",
    "EMLAK VARLIK KİRALAMA A.Ş."
  ],
  [
    "ENDAE",
    "ENDA ENERJİ HOLDİNG A.Ş."
  ],
  [
    "ENERY",
    "ENERYA ENERJİ A.Ş."
  ],
  [
    "ENJSA",
    "ENERJİSA ENERJİ A.Ş."
  ],
  [
    "ENKAI",
    "ENKA İNŞAAT VE SANAYİ A.Ş."
  ],
  [
    "ENPRA",
    "ENPARA BANK A.Ş."
  ],
  [
    "ENSRI",
    "ENSARİ SINAİ YATIRIMLAR A.Ş."
  ],
  [
    "ENTRA",
    "IC ENTERRA YENİLENEBİLİR ENERJİ A.Ş."
  ],
  [
    "EPLAS",
    "EGEPLAST EGE PLASTİK TİCARET VE SANAYİ A.Ş."
  ],
  [
    "ERBOS",
    "ERBOSAN ERCİYAS BORU SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ERCB",
    "ERCİYAS ÇELİK BORU SANAYİ A.Ş."
  ],
  [
    "EREGL",
    "EREĞLİ DEMİR VE ÇELİK FABRİKALARI T.A.Ş."
  ],
  [
    "ERGLI",
    "EREĞLİ TEKSTİL TURİZM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ERSU",
    "ERSU MEYVE VE GIDA SANAYİ A.Ş."
  ],
  [
    "ESCAR",
    "ESCAR FİLO KİRALAMA HİZMETLERİ A.Ş."
  ],
  [
    "ESCOM",
    "ESCORT TEKNOLOJİ YATIRIM A.Ş."
  ],
  [
    "ESEN",
    "ESENBOĞA ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "ETILR",
    "ETİLER GIDA VE TİCARİ YATIRIMLAR SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ETYAT",
    "EURO TREND YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "EUHOL",
    "EURO YATIRIM HOLDİNG A.Ş."
  ],
  [
    "EUKYO",
    "EURO KAPİTAL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "EUPWR",
    "EUROPOWER ENERJİ VE OTOMASYON TEKNOLOJİLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "EUREN",
    "EUROPEN ENDÜSTRİ İNŞAAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "EUYO",
    "EURO MENKUL KIYMET YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "EXIMB",
    "TÜRKİYE İHRACAT KREDİ BANKASI A.Ş."
  ],
  [
    "EYGYO",
    "EYG GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "FADE",
    "FADE GIDA YATIRIM SANAYİ TİCARET A.Ş."
  ],
  [
    "FAIRF",
    "FAİR FİNANSMAN A.Ş."
  ],
  [
    "FBBNK",
    "FİBABANKA A.Ş."
  ],
  [
    "FENER",
    "FENERBAHÇE FUTBOL A.Ş."
  ],
  [
    "FIGOF",
    "FİGO FİNANS FAKTORİNG A.Ş."
  ],
  [
    "FKPET",
    "FİKRET PETROL ÜRÜNLERİ PAZARLAMA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "FLAP",
    "FLAP KONGRE TOPLANTI HİZMETLERİ OTOMOTİV VE TURİZM A.Ş."
  ],
  [
    "FMIZP",
    "FEDERAL MOGUL İZMİT PİSTON VE PİM ÜRETİM TESİSLERİ A.Ş."
  ],
  [
    "FONET",
    "FONET BİLGİ TEKNOLOJİLERİ A.Ş."
  ],
  [
    "FORMT",
    "FORMET METAL VE CAM SANAYİ A.Ş."
  ],
  [
    "FORTE",
    "FORTE BİLGİ İLETİŞİM TEKNOLOJİLERİ VE SAVUNMA SANAYİ A.Ş."
  ],
  [
    "FRIGO",
    "FRİGO-PAK GIDA MADDELERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "FRMPL",
    "FORMÜL PLASTİK VE METAL SANAYİ A.Ş."
  ],
  [
    "FROTO",
    "FORD OTOMOTİV SANAYİ A.Ş."
  ],
  [
    "FZLGY",
    "FUZUL GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "GARAN",
    "TÜRKİYE GARANTİ BANKASI A.Ş."
  ],
  [
    "GARFA",
    "GARANTİ FAKTORİNG A.Ş."
  ],
  [
    "GARFL",
    "GARANTİ BBVA OPERASYONEL KİRALAMA HİZMETLERİ A.Ş."
  ],
  [
    "GATEG",
    "GATE GROUP TEKNOLOJİ MEDYA VE SİBER GÜVENLİK HİZMETLERİ A.Ş."
  ],
  [
    "GEDIK",
    "GEDİK YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "GEDZA",
    "GEDİZ AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GENIL",
    "GEN İLAÇ VE SAĞLIK ÜRÜNLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GENKM",
    "GENTAŞ KİMYA SANAYİ VE TİCARET PAZARLAMA A.Ş."
  ],
  [
    "GENTS",
    "GENTAŞ DEKORATİF YÜZEYLER SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GEREL",
    "GERSAN ELEKTRİK TİCARET VE SANAYİ A.Ş."
  ],
  [
    "GESAN",
    "GİRİŞİM ELEKTRİK SANAYİ TAAHHÜT VE TİCARET A.Ş."
  ],
  [
    "GGBVK",
    "GOLDEN GLOBAL VARLIK KİRALAMA A.Ş."
  ],
  [
    "GIPTA",
    "GIPTA OFİS KIRTASİYE VE PROMOSYON ÜRÜNLERİ İMALAT SANAYİ A.Ş."
  ],
  [
    "GLBMD",
    "GLOBAL MENKUL DEĞERLER A.Ş."
  ],
  [
    "GLCVY",
    "GELECEK VARLIK YÖNETİMİ A.Ş."
  ],
  [
    "GLRMK",
    "GÜLERMAK AĞIR SANAYİ İNŞAAT VE TAAHHÜT A.Ş."
  ],
  [
    "GLRYH",
    "GÜLER YATIRIM HOLDİNG A.Ş."
  ],
  [
    "GLYHO",
    "GLOBAL YATIRIM HOLDİNG A.Ş."
  ],
  [
    "GMTAS",
    "GİMAT MAĞAZACILIK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GOKNR",
    "GÖKNUR GIDA MADDELERİ ENERJİ İMALAT İTHALAT İHRACAT TİCARET VE SANAYİ A.Ş."
  ],
  [
    "GOLDA",
    "GOLDA GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GOLTS",
    "GÖLTAŞ GÖLLER BÖLGESİ ÇİMENTO SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GOODY",
    "GOODYEAR LASTİKLERİ T.A.Ş."
  ],
  [
    "GOZDE",
    "GÖZDE GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "GRNYO",
    "GARANTİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "GRSEL",
    "GÜR-SEL TURİZM TAŞIMACILIK VE SERVİS TİCARET A.Ş."
  ],
  [
    "GRTHO",
    "GRAINTURK HOLDİNG A.Ş."
  ],
  [
    "GRYAT",
    "GARANTİ YATIRIM MENKUL KIYMETLER A.Ş."
  ],
  [
    "GSDDE",
    "GSD DENİZCİLİK GAYRİMENKUL İNŞAAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "GSDHO",
    "GSD HOLDİNG A.Ş."
  ],
  [
    "GSIPD",
    "GOLDMAN SACHS INTERNATIONAL"
  ],
  [
    "GSRAY",
    "GALATASARAY SPORTİF SINAİ VE TİCARİ YATIRIMLAR A.Ş."
  ],
  [
    "GUBRF",
    "GÜBRE FABRİKALARI T.A.Ş."
  ],
  [
    "GUNDG",
    "GÜNDOĞDU GIDA SÜT ÜRÜNLERİ SANAYİ VE DIŞ TİCARET A.Ş."
  ],
  [
    "GWIND",
    "GALATA WIND ENERJİ A.Ş."
  ],
  [
    "GYVAR",
    "GY VARLIK KİRALAMA A.Ş."
  ],
  [
    "GZNMI",
    "GEZİNOMİ SEYAHAT TURİZM TİCARET A.Ş."
  ],
  [
    "HALKB",
    "TÜRKİYE HALK BANKASI A.Ş."
  ],
  [
    "HALKF",
    "HALK FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "HALKI",
    "HALK YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "HATEK",
    "HATEKS HATAY TEKSTİL İŞLETMELERİ A.Ş."
  ],
  [
    "HATSN",
    "HAT-SAN GEMİ İNŞAA BAKIM ONARIM DENİZ NAKLİYAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "HAYVK",
    "HAYAT VARLIK KİRALAMA A.Ş."
  ],
  [
    "HDFFL",
    "HEDEF ARAÇ KİRALAMA VE SERVİS A.Ş."
  ],
  [
    "HDFGS",
    "HEDEF GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "HDFVK",
    "HEDEF VARLIK KİRALAMA A.Ş."
  ],
  [
    "HDFYB",
    "HEDEF YATIRIM BANKASI A.Ş."
  ],
  [
    "HEDEF",
    "HEDEF HOLDİNG A.Ş."
  ],
  [
    "HEKTS",
    "HEKTAŞ TİCARET T.A.Ş."
  ],
  [
    "HKTM",
    "HİDROPAR HAREKET KONTROL TEKNOLOJİLERİ MERKEZİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "HLGYO",
    "HALK GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "HLVKS",
    "HALK VARLIK KİRALAMA A.Ş."
  ],
  [
    "HOROZ",
    "HOROZ LOJİSTİK KARGO HİZMETLERİ VE TİCARET A.Ş."
  ],
  [
    "HRKET",
    "HAREKET PROJE TAŞIMACILIĞI VE YÜK MÜHENDİSLİĞİ A.Ş."
  ],
  [
    "HTTBT",
    "HİTİT BİLGİSAYAR HİZMETLERİ A.Ş."
  ],
  [
    "HUBVC",
    "HUB GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "HUNER",
    "HUN YENİLENEBİLİR ENERJİ ÜRETİM A.Ş."
  ],
  [
    "HURGZ",
    "HÜRRİYET GAZETECİLİK VE MATBAACILIK A.Ş."
  ],
  [
    "HUZFA",
    "HUZUR FAKTORİNG A.Ş."
  ],
  [
    "ICBCT",
    "ICBC TURKEY BANK A.Ş."
  ],
  [
    "ICUGS",
    "ICU GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "IDGYO",
    "İDEALİST GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "IEYHO",
    "IŞIKLAR ENERJİ VE YAPI HOLDİNG A.Ş."
  ],
  [
    "IHAAS",
    "İHLAS HABER AJANSI A.Ş."
  ],
  [
    "IHEVA",
    "İHLAS EV ALETLERİ İMALAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "IHGZT",
    "İHLAS GAZETECİLİK A.Ş."
  ],
  [
    "IHLAS",
    "İHLAS HOLDİNG A.Ş."
  ],
  [
    "IHLGM",
    "İHLAS GAYRİMENKUL PROJE GELİŞTİRME VE TİCARET A.Ş."
  ],
  [
    "IHYAY",
    "İHLAS YAYIN HOLDİNG A.Ş."
  ],
  [
    "IMASM",
    "İMAŞ MAKİNA SANAYİ A.Ş."
  ],
  [
    "INDES",
    "İNDEKS BİLGİSAYAR SİSTEMLERİ MÜHENDİSLİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "INFO",
    "İNFO YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "INGRM",
    "INGRAM MİCRO BİLİŞİM SİSTEMLERİ A.Ş."
  ],
  [
    "INTEK",
    "İNNOSA TEKNOLOJİ A.Ş."
  ],
  [
    "INTEM",
    "İNTEMA İNŞAAT VE TESİSAT MALZEMELERİ YATIRIM VE PAZARLAMA A.Ş."
  ],
  [
    "INVAZ",
    "INVEST-AZ YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "INVEO",
    "INVEO YATIRIM HOLDİNG A.Ş."
  ],
  [
    "INVES",
    "INVESTCO HOLDİNG A.Ş."
  ],
  [
    "ISATR",
    "TÜRKİYE İŞ BANKASI A.Ş."
  ],
  [
    "ISBIR",
    "İŞBİR HOLDİNG A.Ş."
  ],
  [
    "ISBTR",
    "TÜRKİYE İŞ BANKASI A.Ş."
  ],
  [
    "ISCTR",
    "TÜRKİYE İŞ BANKASI A.Ş."
  ],
  [
    "ISDMR",
    "İSKENDERUN DEMİR VE ÇELİK A.Ş."
  ],
  [
    "ISFAK",
    "İŞ FAKTORİNG A.Ş."
  ],
  [
    "ISFIN",
    "İŞ FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "ISGSY",
    "İŞ GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ISGYO",
    "İŞ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ISKPL",
    "IŞIK PLASTİK SANAYİ VE DIŞ TİCARET PAZARLAMA A.Ş."
  ],
  [
    "ISKUR",
    "TÜRKİYE İŞ BANKASI A.Ş."
  ],
  [
    "ISMEN",
    "İŞ YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "ISSEN",
    "İŞBİR SENTETİK DOKUMA SANAYİ A.Ş."
  ],
  [
    "ISTFK",
    "İSTANBUL FAKTORİNG A.Ş."
  ],
  [
    "ISTVY",
    "İSTANBUL VARLIK YÖNETİM A.Ş."
  ],
  [
    "ISVEA",
    "İSVEA SERAMİK VE BANYO ÜRÜNLERİ SANAYİ A.Ş."
  ],
  [
    "ISYAT",
    "İŞ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "IZENR",
    "İZDEMİR ENERJİ ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "IZFAS",
    "İZMİR FIRÇA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "IZINV",
    "İZ YATIRIM HOLDİNG A.Ş."
  ],
  [
    "IZMDC",
    "İZMİR DEMİR ÇELİK SANAYİ A.Ş."
  ],
  [
    "JANTS",
    "JANTSA JANT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KAPLM",
    "KAPLAMİN AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KARCL",
    "KARDEMİR ÇELİK SANAYİ A.Ş."
  ],
  [
    "KAREL",
    "KAREL ELEKTRONİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KARSN",
    "KARSAN OTOMOTİV SANAYİİ VE TİCARET A.Ş."
  ],
  [
    "KARTN",
    "KARTONSAN KARTON SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KATMR",
    "KATMERCİLER ARAÇ ÜSTÜ EKİPMAN SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KATVK",
    "KATILIM VARLIK KİRALAMA A.Ş."
  ],
  [
    "KAYSE",
    "KAYSERİ ŞEKER FABRİKASI A.Ş."
  ],
  [
    "KBORU",
    "KUZEY BORU A.Ş."
  ],
  [
    "KCAER",
    "KOCAER ÇELİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KCHOL",
    "KOÇ HOLDİNG A.Ş."
  ],
  [
    "KENT",
    "KENT GIDA MADDELERİ SANAYİİ VE TİCARET A.Ş."
  ],
  [
    "KERVN",
    "KERVANSARAY YATIRIM HOLDİNG A.Ş."
  ],
  [
    "KFEIN",
    "KAFEİN YAZILIM HİZMETLERİ TİCARET A.Ş."
  ],
  [
    "KFILO",
    "KAYATUR FİLO KİRALAMA A.Ş."
  ],
  [
    "KGYO",
    "KORAY GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "KIMMR",
    "ERSAN ALIŞVERİŞ HİZMETLERİ VE GIDA SANAYİ TİCARET A.Ş."
  ],
  [
    "KLGYO",
    "KİLER GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "KLKIM",
    "KALEKİM KİMYEVİ MADDELER SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KLMSN",
    "KLİMASAN KLİMA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KLNMA",
    "TÜRKİYE KALKINMA VE YATIRIM BANKASI A.Ş."
  ],
  [
    "KLRHO",
    "KİLER HOLDİNG A.Ş."
  ],
  [
    "KLSER",
    "KALESERAMİK ÇANAKKALE KALEBODUR SERAMİK SANAYİ A.Ş."
  ],
  [
    "KLSYN",
    "KOLEKSİYON MOBİLYA SANAYİ A.Ş."
  ],
  [
    "KLVKS",
    "KALKINMA YATIRIM VARLIK KİRALAMA A.Ş."
  ],
  [
    "KLYPV",
    "KALYON GÜNEŞ TEKNOLOJİLERİ ÜRETİM A.Ş."
  ],
  [
    "KMPUR",
    "KİMTEKS POLİÜRETAN SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KNFRT",
    "KONFRUT TARIM A.Ş."
  ],
  [
    "KNTFA",
    "KENT FİNANS FAKTORİNG A.Ş."
  ],
  [
    "KOCFN",
    "KOÇ FİNANSMAN A.Ş."
  ],
  [
    "KOCMT",
    "KOÇ METALURJİ A.Ş."
  ],
  [
    "KONKA",
    "KONYA KAĞIT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KONTR",
    "KONTROLMATİK TEKNOLOJİ ENERJİ VE MÜHENDİSLİK A.Ş."
  ],
  [
    "KONYA",
    "KONYA ÇİMENTO SANAYİİ A.Ş."
  ],
  [
    "KOPOL",
    "KOZA POLYESTER SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KORDS",
    "KORDSA TEKNİK TEKSTİL A.Ş."
  ],
  [
    "KORTS",
    "KORTEKS MENSUCAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KOTON",
    "KOTON MAĞAZACILIK TEKSTİL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KPTGY",
    "KAPİTAL GAYRİMENKUL YATIRIMI GELİŞTİRME VE İŞLETMECİLİK A.Ş."
  ],
  [
    "KRDMA",
    "KARDEMİR KARABÜK DEMİR ÇELİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KRDMB",
    "KARDEMİR KARABÜK DEMİR ÇELİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KRDMD",
    "KARDEMİR KARABÜK DEMİR ÇELİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KRGYO",
    "KÖRFEZ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "KRONT",
    "KRON TEKNOLOJİ A.Ş."
  ],
  [
    "KRPLS",
    "KOROPLAST TEMİZLİK AMBALAJ ÜRÜNLERİ SANAYİ VE DIŞ TİCARET A.Ş."
  ],
  [
    "KRSTL",
    "KRİSTAL KOLA VE MEŞRUBAT SANAYİ TİCARET A.Ş."
  ],
  [
    "KRTEK",
    "KARSU TEKSTİL SANAYİİ VE TİCARET A.Ş."
  ],
  [
    "KRVGD",
    "KERVAN GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "KSFIN",
    "KOÇ STELLANTİS FİNANSMAN A.Ş."
  ],
  [
    "KSTUR",
    "KUŞTUR KUŞADASI TURİZM ENDÜSTRİSİ A.Ş."
  ],
  [
    "KTKVK",
    "KT KİRA SERTİFİKALARI VARLIK KİRALAMA A.Ş."
  ],
  [
    "KTLEV",
    "KATILIMEVİM TASARRUF FİNANSMAN A.Ş."
  ],
  [
    "KTSKR",
    "KÜTAHYA ŞEKER FABRİKASI A.Ş."
  ],
  [
    "KTSVK",
    "KT SUKUK VARLIK KİRALAMA A.Ş."
  ],
  [
    "KUTPO",
    "KÜTAHYA PORSELEN SANAYİ A.Ş."
  ],
  [
    "KUVVA",
    "KUVVA GIDA TİCARET VE SANAYİ YATIRIMLARI A.Ş."
  ],
  [
    "KUYAS",
    "KUYAŞ YATIRIM A.Ş."
  ],
  [
    "KZBGY",
    "KIZILBÜK GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "KZGYO",
    "KUZUGRUP GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "LIDER",
    "LDR TURİZM A.Ş."
  ],
  [
    "LIDFA",
    "LİDER FAKTORİNG A.Ş."
  ],
  [
    "LILAK",
    "LİLA KAĞIT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "LINK",
    "LİNK BİLGİSAYAR SİSTEMLERİ YAZILIMI VE DONANIMI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "LKMNH",
    "LOKMAN HEKİM ENGÜRÜSAĞ SAĞLIK TURİZM EĞİTİM HİZMETLERİ VE İNŞAAT TAAHHÜT A.Ş."
  ],
  [
    "LMKDC",
    "LİMAK DOĞU ANADOLU ÇİMENTO SANAYİ VE TİCARET A.Ş."
  ],
  [
    "LOGO",
    "LOGO YAZILIM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "LRSHO",
    "LORAS HOLDİNG A.Ş."
  ],
  [
    "LUKSK",
    "LÜKS KADİFE TİCARET VE SANAYİİ A.Ş."
  ],
  [
    "LXGYO",
    "LUXERA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "LYDHO",
    "LYDİA HOLDİNG A.Ş."
  ],
  [
    "LYDYE",
    "LYDİA YEŞİL ENERJİ KAYNAKLARI A.Ş."
  ],
  [
    "MAALT",
    "MARMARİS ALTINYUNUS TURİSTİK TESİSLER A.Ş."
  ],
  [
    "MACKO",
    "MACKOLİK İNTERNET HİZMETLERİ TİCARET A.Ş."
  ],
  [
    "MAGEN",
    "MARGÜN ENERJİ ÜRETİM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MAKIM",
    "MAKİM MAKİNA TEKNOLOJİLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MAKTK",
    "MAKİNA TAKIM ENDÜSTRİSİ A.Ş."
  ],
  [
    "MANAS",
    "MANAS ENERJİ YÖNETİMİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MARBL",
    "TUREKS TURUNÇ MADENCİLİK İÇ VE DIŞ TİCARET A.Ş."
  ],
  [
    "MARKA",
    "MARKA YATIRIM HOLDİNG A.Ş."
  ],
  [
    "MARMR",
    "MARMARA HOLDİNG A.Ş."
  ],
  [
    "MARTI",
    "MARTI OTEL İŞLETMELERİ A.Ş."
  ],
  [
    "MASFN",
    "MASFEN ENERJİ A.Ş."
  ],
  [
    "MAVI",
    "MAVİ GİYİM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MBFTR",
    "MERCEDES-BENZ FİNANSMAN TÜRK A.Ş."
  ],
  [
    "MCARD",
    "METROPAL KURUMSAL HİZMETLER A.Ş."
  ],
  [
    "MDASM",
    "MİDAS MENKUL DEĞERLER A.Ş."
  ],
  [
    "MDIAZ",
    "MEDİAZZ YENİ MEDYA VE TEKNOLOJİ YATIRIMLARI A.Ş."
  ],
  [
    "MEDTR",
    "MEDİTERA TIBBİ MALZEME SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MEGAP",
    "MEGA POLİETİLEN KÖPÜK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MEGMT",
    "MEGA METAL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MEKAG",
    "MEKA GLOBAL MAKİNE İMALAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MEKMD",
    "MEKSA YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "MEPET",
    "MEPET METRO PETROL VE TESİSLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "MERCN",
    "MERCAN KİMYA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MERIT",
    "MERİT TURİZM YATIRIM VE İŞLETME A.Ş."
  ],
  [
    "MERKO",
    "MERKO GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "METEN",
    "METGÜN ENERJİ YATIRIMLARI A.Ş."
  ],
  [
    "METRO",
    "METRO TİCARİ VE MALİ YATIRIMLAR HOLDİNG A.Ş."
  ],
  [
    "MEYSU",
    "MEYSU GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MGROS",
    "MİGROS TİCARET A.Ş."
  ],
  [
    "MHRGY",
    "MHR GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "MIATK",
    "MİA TEKNOLOJİ A.Ş."
  ],
  [
    "MILKS",
    "MİLK ACADEMY SÜT ÜRÜNLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MINTF",
    "MİNT FİNANSMAN A.Ş."
  ],
  [
    "MMCAS",
    "MMC SANAYİ VE TİCARİ YATIRIMLAR A.Ş."
  ],
  [
    "MNDRS",
    "MENDERES TEKSTİL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MNDTR",
    "MONDİ TURKEY OLUKLU MUKAVVA KAĞIT VE AMBALAJ SANAYİ A.Ş."
  ],
  [
    "MNGFA",
    "MNG FAKTORİNG A.Ş."
  ],
  [
    "MOBTL",
    "MOBİLTEL İLETİŞİM HİZMETLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MOGAN",
    "MOGAN ENERJİ YATIRIM HOLDİNG A.Ş."
  ],
  [
    "MOPAS",
    "MOPAŞ MARKETÇİLİK GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "MPARK",
    "MLP SAĞLIK HİZMETLERİ A.Ş."
  ],
  [
    "MRBAS",
    "MARBAŞ MENKUL DEĞERLER A.Ş."
  ],
  [
    "MRBKF",
    "MERCEDES BENZ KAMYON FİNANSMAN A.Ş."
  ],
  [
    "MRGYO",
    "MARTI GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "MRMAG",
    "MARKA MAĞAZACILIK A.Ş."
  ],
  [
    "MRSHL",
    "MARSHALL BOYA VE VERNİK SANAYİİ A.Ş."
  ],
  [
    "MSGYO",
    "MİSTRAL GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "MSYBN",
    "MİSYON YATIRIM BANKASI A.Ş."
  ],
  [
    "MTRKS",
    "MATRİKS FİNANSAL TEKNOLOJİLER A.Ş."
  ],
  [
    "MTRYO",
    "METRO YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "MZHLD",
    "MAZHAR ZORLU HOLDİNG A.Ş."
  ],
  [
    "NATEN",
    "NATUREL YENİLENEBİLİR ENERJİ TİCARET A.Ş."
  ],
  [
    "NETAS",
    "NETAŞ TELEKOMÜNİKASYON A.Ş."
  ],
  [
    "NETCD",
    "NETCAD YAZILIM A.Ş."
  ],
  [
    "NIBAS",
    "NİĞBAŞ NİĞDE BETON SANAYİ VE TİCARET A.Ş."
  ],
  [
    "NRBNK",
    "NUROL YATIRIM BANKASI A.Ş."
  ],
  [
    "NTGAZ",
    "NATURELGAZ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "NTHOL",
    "NET HOLDİNG A.Ş."
  ],
  [
    "NUGYO",
    "NUROL GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "NUHCM",
    "NUH ÇİMENTO SANAYİ A.Ş."
  ],
  [
    "NURVK",
    "NUROL VARLIK KİRALAMA A.Ş."
  ],
  [
    "OBAMS",
    "OBA MAKARNACILIK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "OBASE",
    "OBASE BİLGİSAYAR VE DANIŞMANLIK HİZMETLERİ TİCARET A.Ş."
  ],
  [
    "ODAS",
    "ODAŞ ELEKTRİK ÜRETİM SANAYİ TİCARET A.Ş."
  ],
  [
    "ODINE",
    "ODİNE SOLUTİONS TEKNOLOJİ TİCARET VE SANAYİ A.Ş."
  ],
  [
    "OFSYM",
    "OFİS YEM GIDA SANAYİ TİCARET A.Ş."
  ],
  [
    "ONCSM",
    "ONCOSEM ONKOLOJİK SİSTEMLER SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ONRYT",
    "ONUR YÜKSEK TEKNOLOJİ A.Ş."
  ],
  [
    "OPET",
    "OPET PETROLCÜLÜK A.Ş."
  ],
  [
    "ORCAY",
    "ORÇAY ORTAKÖY ÇAY SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ORFIN",
    "ORFİN FİNANSMAN A.Ş."
  ],
  [
    "ORGE",
    "ORGE ENERJİ ELEKTRİK TAAHHÜT A.Ş."
  ],
  [
    "ORMA",
    "ORMA ORMAN MAHSÜLLERİ İNTEGRE SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ORZAX",
    "ORZAKS İLAÇ VE KİMYA SANAYİ TİCARET A.Ş."
  ],
  [
    "OSMEN",
    "OSMANLI YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "OSTIM",
    "OSTİM ENDÜSTRİYEL YATIRIMLAR VE İŞLETME A.Ş."
  ],
  [
    "OSVKS",
    "OSMANLI VARLIK KİRALAMA A.Ş."
  ],
  [
    "OTKAR",
    "OTOKAR OTOMOTİV VE SAVUNMA SANAYİ A.Ş."
  ],
  [
    "OTOSR",
    "OTOSOR OTOMOTİV A.Ş."
  ],
  [
    "OTTO",
    "OTTO HOLDİNG A.Ş."
  ],
  [
    "OYAKC",
    "OYAK ÇİMENTO FABRİKALARI A.Ş."
  ],
  [
    "OYAYO",
    "OYAK YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "OYLUM",
    "OYLUM SINAİ YATIRIMLAR A.Ş."
  ],
  [
    "OYYAT",
    "OYAK YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "OZATD",
    "ÖZATA DENİZCİLİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "OZGYO",
    "ÖZDERİCİ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "OZKGY",
    "ÖZAK GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "OZRDN",
    "ÖZERDEN AMBALAJ SANAYİ A.Ş."
  ],
  [
    "OZSUB",
    "ÖZSU BALIK ÜRETİM A.Ş."
  ],
  [
    "OZYSR",
    "ÖZYAŞAR TEL VE GALVANİZLEME SANAYİ A.Ş."
  ],
  [
    "PAGYO",
    "PANORA GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "PAHOL",
    "PASİFİK HOLDİNG A.Ş."
  ],
  [
    "PAMEL",
    "PAMEL YENİLENEBİLİR ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "PAPIL",
    "PAPİLON SAVUNMA TEKNOLOJİ VE TİCARET A.Ş."
  ],
  [
    "PARSN",
    "PARSAN MAKİNA PARÇALARI SANAYİİ A.Ş."
  ],
  [
    "PASEU",
    "PASİFİK EURASİA LOJİSTİK DIŞ TİCARET A.Ş."
  ],
  [
    "PATEK",
    "PASİFİK TEKNOLOJİ A.Ş."
  ],
  [
    "PBTR",
    "PASHA YATIRIM BANKASI A.Ş."
  ],
  [
    "PCILT",
    "PC İLETİŞİM VE MEDYA HİZMETLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "PEKGY",
    "PEKER GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "PENGD",
    "PENGUEN GIDA SANAYİ A.Ş."
  ],
  [
    "PENTA",
    "PENTA TEKNOLOJİ ÜRÜNLERİ DAĞITIM TİCARET A.Ş."
  ],
  [
    "PETKM",
    "PETKİM PETROKİMYA HOLDİNG A.Ş."
  ],
  [
    "PETUN",
    "PINAR ENTEGRE ET VE UN SANAYİİ A.Ş."
  ],
  [
    "PGSUS",
    "PEGASUS HAVA TAŞIMACILIĞI A.Ş."
  ],
  [
    "PINSU",
    "PINAR SU VE İÇECEK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PKART",
    "PLASTİKKART AKILLI KART İLETİŞİM SİSTEMLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PKENT",
    "PETROKENT TURİZM A.Ş."
  ],
  [
    "PLTUR",
    "PLATFORM TURİZM TAŞIMACILIK GIDA İNŞAAT TEMİZLİK HİZMETLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PNLSN",
    "PANELSAN ÇATI CEPHE SİSTEMLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PNSUT",
    "PINAR SÜT MAMÜLLERİ SANAYİİ A.Ş."
  ],
  [
    "POLHO",
    "POLİSAN HOLDİNG A.Ş."
  ],
  [
    "POLTK",
    "POLİTEKNİK METAL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PRDGS",
    "PARDUS GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "PRFFK",
    "PARAFİNANS FAKTORİNG A.Ş."
  ],
  [
    "PRKAB",
    "TÜRK PRYSMİAN KABLO VE SİSTEMLERİ A.Ş."
  ],
  [
    "PRKME",
    "PARK ELEKTRİK ÜRETİM MADENCİLİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PRZMA",
    "PRİZMA PRES MATBAACILIK YAYINCILIK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "PSDTC",
    "PERGAMON STATUS DIŞ TİCARET A.Ş."
  ],
  [
    "PSGYO",
    "PASİFİK GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "QNBFF",
    "QNB FAKTORİNG A.Ş."
  ],
  [
    "QNBFK",
    "QNB FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "QNBTR",
    "QNB BANK A.Ş."
  ],
  [
    "QNBVK",
    "QNB VARLIK KİRALAMA A.Ş."
  ],
  [
    "QUAGR",
    "QUA GRANITE HAYAL YAPI VE ÜRÜNLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "QUFIN",
    "QUICK FİNANSMAN A.Ş."
  ],
  [
    "QYATB",
    "Q YATIRIM BANKASI A.Ş."
  ],
  [
    "QYHOL",
    "Q YATIRIM HOLDİNG A.Ş."
  ],
  [
    "RALYH",
    "RAL YATIRIM HOLDİNG A.Ş."
  ],
  [
    "RAYSG",
    "RAY SİGORTA A.Ş."
  ],
  [
    "REEDR",
    "REEDER TEKNOLOJİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "RGYAS",
    "RÖNESANS GAYRİMENKUL YATIRIM A.Ş."
  ],
  [
    "RNPOL",
    "RAİNBOW POLİKARBONAT SANAYİ TİCARET A.Ş."
  ],
  [
    "RODRG",
    "RODRİGO TEKSTİL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "RTALB",
    "RTA LABORATUVARLARI BİYOLOJİK ÜRÜNLER İLAÇ VE MAKİNE SANAYİ TİCARET A.Ş."
  ],
  [
    "RUBNS",
    "RUBENİS TEKSTİL SANAYİ TİCARET A.Ş."
  ],
  [
    "RUZYE",
    "RUZY MADENCİLİK VE ENERJİ YATIRIMLARI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "RYGYO",
    "REYSAŞ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "RYSAS",
    "REYSAŞ TAŞIMACILIK VE LOJİSTİK TİCARET A.Ş."
  ],
  [
    "SAFKR",
    "SAFKAR EGE SOĞUTMACILIK KLİMA SOĞUK HAVA TESİSLERİ İHRACAT İTHALAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SAHOL",
    "HACI ÖMER SABANCI HOLDİNG A.Ş."
  ],
  [
    "SAMAT",
    "SARAY MATBAACILIK KAĞITÇILIK KIRTASİYECİLİK TİCARET VE SANAYİ A.Ş."
  ],
  [
    "SANEL",
    "SAN-EL MÜHENDİSLİK ELEKTRİK TAAHHÜT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SANFM",
    "SANİFOAM ENDÜSTRİ VE TÜKETİM ÜRÜNLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "SANKO",
    "SANKO PAZARLAMA İTHALAT İHRACAT A.Ş."
  ],
  [
    "SARAE",
    "ŞA-RA ENERJİ İNŞAAT TİCARET VE SANAYİ A.Ş."
  ],
  [
    "SARKY",
    "SARKUYSAN ELEKTROLİTİK BAKIR SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SARTN",
    "SARTEN AMBALAJ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SASA",
    "SASA POLYESTER SANAYİ A.Ş."
  ],
  [
    "SAYAS",
    "SAY YENİLENEBİLİR ENERJİ EKİPMANLARI SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SDTTR",
    "SDT UZAY VE SAVUNMA TEKNOLOJİLERİ A.Ş."
  ],
  [
    "SEGMN",
    "SEĞMEN KARDEŞLER GIDA ÜRETİM VE AMBALAJ SANAYİ A.Ş."
  ],
  [
    "SEGYO",
    "ŞEKER GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "SEKFK",
    "ŞEKER FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "SEKUR",
    "SEKURO PLASTİK AMBALAJ SANAYİ A.Ş."
  ],
  [
    "SELEC",
    "SELÇUK ECZA DEPOSU TİCARET VE SANAYİ A.Ş."
  ],
  [
    "SELVA",
    "SELVA GIDA SANAYİ A.Ş."
  ],
  [
    "SERNT",
    "SERANİT GRANİT SERAMİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SEYKM",
    "SEYİTLER KİMYA SANAYİ A.Ş."
  ],
  [
    "SILVR",
    "SİLVERLİNE ENDÜSTRİ VE TİCARET A.Ş."
  ],
  [
    "SISE",
    "TÜRKİYE ŞİŞE VE CAM FABRİKALARI A.Ş."
  ],
  [
    "SKBNK",
    "ŞEKERBANK T.A.Ş."
  ],
  [
    "SKTAS",
    "SÖKTAŞ TEKSTİL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SKYLP",
    "SKYALP FİNANSAL TEKNOLOJİLER VE DANIŞMANLIK A.Ş."
  ],
  [
    "SKYMD",
    "ŞEKER YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "SMART",
    "SMARTİKS YAZILIM A.Ş."
  ],
  [
    "SMRFA",
    "SÜMER FAKTORİNG A.Ş."
  ],
  [
    "SMRTG",
    "SMART GÜNEŞ ENERJİSİ TEKNOLOJİLERİ ARAŞTIRMA GELİŞTİRME ÜRETİM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SMRVA",
    "SÜMER VARLIK YÖNETİM A.Ş."
  ],
  [
    "SNGYO",
    "SİNPAŞ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "SNICA",
    "SANİCA ISI SANAYİ A.Ş."
  ],
  [
    "SNPAM",
    "SÖNMEZ PAMUKLU SANAYİİ A.Ş."
  ],
  [
    "SODSN",
    "SODAŞ SODYUM SANAYİİ A.Ş."
  ],
  [
    "SOHOE",
    "SOHO GİYİM VE ENERJİ A.Ş."
  ],
  [
    "SOKE",
    "SÖKE DEĞİRMENCİLİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SOKM",
    "ŞOK MARKETLER TİCARET A.Ş."
  ],
  [
    "SONME",
    "SÖNMEZ FİLAMENT SENTETİK İPLİK VE ELYAF SANAYİ A.Ş."
  ],
  [
    "SRVGY",
    "SERVET GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "SSAAT",
    "SAAT VE SAAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SUMAS",
    "SUMAŞ SUNİ TAHTA VE MOBİLYA SANAYİİ A.Ş."
  ],
  [
    "SUNTK",
    "SUN TEKSTİL SANAYİ VE TİCARET A.Ş."
  ],
  [
    "SURGY",
    "SUR TATİL EVLERİ GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "SUWEN",
    "SUWEN TEKSTİL SANAYİ PAZARLAMA A.Ş."
  ],
  [
    "SVGYO",
    "SAVUR GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "TABGD",
    "TAB GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TAMFA",
    "TAM FİNANS FAKTORİNG A.Ş."
  ],
  [
    "TARFN",
    "TARFİN TARIM A.Ş."
  ],
  [
    "TARKM",
    "TARKİM BİTKİ KORUMA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TATEN",
    "TATLIPINAR ENERJİ ÜRETİM A.Ş."
  ],
  [
    "TATGD",
    "TAT GIDA SANAYİ A.Ş."
  ],
  [
    "TAVHL",
    "TAV HAVALİMANLARI HOLDİNG A.Ş."
  ],
  [
    "TBORG",
    "TÜRK TUBORG BİRA VE MALT SANAYİİ A.Ş."
  ],
  [
    "TCELL",
    "TURKCELL İLETİŞİM HİZMETLERİ A.Ş."
  ],
  [
    "TCKRC",
    "KIRAÇ GALVANİZ TELEKOMİNİKASYON METAL MAKİNE İNŞAAT ELEKTRİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TCRYT",
    "TACİRLER YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "TDGYO",
    "TREND GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "TEBFA",
    "TEB FAKTORİNG A.Ş."
  ],
  [
    "TEHOL",
    "TERA YATIRIM TEKNOLOJİ HOLDİNG A.Ş."
  ],
  [
    "TEKTU",
    "TEK-ART İNŞAAT TİCARET TURİZM SANAYİ VE YATIRIMLAR A.Ş."
  ],
  [
    "TERA",
    "TERA YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "TEVKS",
    "TERA VARLIK KİRALAMA A.Ş."
  ],
  [
    "TEZOL",
    "EUROPAP TEZOL KAĞIT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TFNVK",
    "TF VARLIK KİRALAMA A.Ş."
  ],
  [
    "TGSAS",
    "TGS DIŞ TİCARET A.Ş."
  ],
  [
    "THYAO",
    "TÜRK HAVA YOLLARI A.O."
  ],
  [
    "TIMUR",
    "TİMUR GAYRİMENKUL GELİŞTİRME YAPI VE YATIRIM A.Ş."
  ],
  [
    "TKFEN",
    "TEKFEN HOLDİNG A.Ş."
  ],
  [
    "TKNSA",
    "TEKNOSA İÇ VE DIŞ TİCARET A.Ş."
  ],
  [
    "TLMAN",
    "TRABZON LİMAN İŞLETMECİLİĞİ A.Ş."
  ],
  [
    "TMPOL",
    "TEMAPOL POLİMER PLASTİK VE İNŞAAT SANAYİ TİCARET A.Ş."
  ],
  [
    "TMSN",
    "TÜMOSAN MOTOR VE TRAKTÖR SANAYİ A.Ş."
  ],
  [
    "TNZTP",
    "TAPDİ OKSİJEN ÖZEL SAĞLIK VE EĞİTİM HİZMETLERİ SANAYİ TİCARET A.Ş."
  ],
  [
    "TOASO",
    "TOFAŞ TÜRK OTOMOBİL FABRİKASI A.Ş."
  ],
  [
    "TRALT",
    "TÜRK ALTIN İŞLETMELERİ A.Ş."
  ],
  [
    "TRBNK",
    "TERA YATIRIM BANKASI A.Ş."
  ],
  [
    "TRCAS",
    "TURCAS HOLDİNG A.Ş."
  ],
  [
    "TRENJ",
    "TR DOĞAL ENERJİ KAYNAKLARI ARAŞTIRMA VE ÜRETİM A.Ş."
  ],
  [
    "TRFFA",
    "TERA FİNANS FAKTORİNG A.Ş."
  ],
  [
    "TRGYO",
    "TORUNLAR GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "TRHOL",
    "TERA FİNANSAL YATIRIMLAR HOLDİNG A.Ş."
  ],
  [
    "TRILC",
    "TURK İLAÇ VE SERUM SANAYİ A.Ş."
  ],
  [
    "TRKFN",
    "TURK FİNANSMAN A.Ş."
  ],
  [
    "TRKNT",
    "TURKNET İLETİŞİM HİZMETLERİ A.Ş."
  ],
  [
    "TRMEN",
    "TRIVE YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "TRMET",
    "TR ANADOLU METAL MADENCİLİK İŞLETMELERİ A.Ş."
  ],
  [
    "TRYKI",
    "TİRYAKİ AGRO GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TSGYO",
    "TSKB GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "TSKB",
    "TÜRKİYE SINAİ KALKINMA BANKASI A.Ş."
  ],
  [
    "TSPOR",
    "TRABZONSPOR SPORTİF YATIRIM VE FUTBOL İŞLETMECİLİĞİ TİCARET A.Ş."
  ],
  [
    "TTKOM",
    "TÜRK TELEKOMÜNİKASYON A.Ş."
  ],
  [
    "TTRAK",
    "TÜRK TRAKTÖR VE ZİRAAT MAKİNELERİ A.Ş."
  ],
  [
    "TUCLK",
    "TUĞÇELİK ALÜMİNYUM VE METAL MAMÜLLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TUKAS",
    "TUKAŞ GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "TUPRS",
    "TÜPRAŞ-TÜRKİYE PETROL RAFİNERİLERİ A.Ş."
  ],
  [
    "TUREX",
    "TUREKS TURİZM TAŞIMACILIK A.Ş."
  ],
  [
    "TURGG",
    "TÜRKER PROJE GAYRİMENKUL VE YATIRIM GELİŞTİRME A.Ş."
  ],
  [
    "TURSG",
    "TÜRKİYE SİGORTA A.Ş."
  ],
  [
    "TV8TV",
    "TV8 TV YAYINCILIK A.Ş."
  ],
  [
    "UCAYM",
    "ÜÇAY MÜHENDİSLİK ENERJİ VE İKLİMLENDİRME TEKNOLOJİLERİ A.Ş."
  ],
  [
    "UFUK",
    "UFUK YATIRIM YÖNETİM VE GAYRİMENKUL A.Ş."
  ],
  [
    "ULAS",
    "ULAŞLAR TURİZM ENERJİ TARIM GIDA VE İNŞAAT YATIRIMLARI A.Ş."
  ],
  [
    "ULKER",
    "ÜLKER BİSKÜVİ SANAYİ A.Ş."
  ],
  [
    "ULUFA",
    "ULUSAL FAKTORİNG A.Ş."
  ],
  [
    "ULUSE",
    "ULUSOY ELEKTRİK İMALAT TAAHHÜT VE TİCARET A.Ş."
  ],
  [
    "ULUUN",
    "ULUSOY UN SANAYİ VE TİCARET A.Ş."
  ],
  [
    "UMPAS",
    "UMPAŞ HOLDİNG A.Ş."
  ],
  [
    "UNLU",
    "ÜNLÜ YATIRIM HOLDİNG A.Ş."
  ],
  [
    "USAK",
    "UŞAK SERAMİK SANAYİ A.Ş."
  ],
  [
    "VAKBN",
    "TÜRKİYE VAKIFLAR BANKASI T.A.O."
  ],
  [
    "VAKFA",
    "VAKIF FAKTORİNG A.Ş."
  ],
  [
    "VAKFN",
    "VAKIF FİNANSAL KİRALAMA A.Ş."
  ],
  [
    "VAKKO",
    "VAKKO TEKSTİL VE HAZIR GİYİM SANAYİ İŞLETMELERİ A.Ş."
  ],
  [
    "VAKVK",
    "VAKIF VARLIK KİRALAMA A.Ş."
  ],
  [
    "VANGD",
    "VANET GIDA SANAYİ İÇ VE DIŞ TİCARET A.Ş."
  ],
  [
    "VBTYZ",
    "VBT YAZILIM A.Ş."
  ],
  [
    "VDFAS",
    "VOLKSWAGEN DOĞUŞ FİNANSMAN A.Ş."
  ],
  [
    "VDFLO",
    "VDF FİLO KİRALAMA A.Ş."
  ],
  [
    "VERTU",
    "VERUSATURK GİRİŞİM SERMAYESİ YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "VERUS",
    "VERUSA HOLDİNG A.Ş."
  ],
  [
    "VESBE",
    "VESTEL BEYAZ EŞYA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "VESTL",
    "VESTEL ELEKTRONİK SANAYİ VE TİCARET A.Ş."
  ],
  [
    "VKFYO",
    "VAKIF MENKUL KIYMET YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "VKGYO",
    "VAKIF GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "VKING",
    "VİKİNG KAĞIT VE SELÜLOZ A.Ş."
  ],
  [
    "VRGYO",
    "VERA KONSEPT GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "VSNMD",
    "VİŞNE MADENCİLİK ÜRETİM SANAYİ VE TİCARET A.Ş."
  ],
  [
    "YAPRK",
    "YAPRAK SÜT VE BESİ ÇİFTLİKLERİ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "YATAS",
    "YATAŞ YATAK VE YORGAN SANAYİ TİCARET A.Ş."
  ],
  [
    "YATVK",
    "YATIRIM VARLIK KİRALAMA A.Ş."
  ],
  [
    "YAYLA",
    "YAYLA ENERJİ ÜRETİM TURİZM VE İNŞAAT TİCARET A.Ş."
  ],
  [
    "YBTAS",
    "YİBİTAŞ YOZGAT İŞÇİ BİRLİĞİ İNŞAAT MALZEMELERİ TİCARET VE SANAYİ A.Ş."
  ],
  [
    "YEOTK",
    "YEO TEKNOLOJİ ENERJİ VE ENDÜSTRİ A.Ş."
  ],
  [
    "YESIL",
    "YEŞİL YATIRIM HOLDİNG A.Ş."
  ],
  [
    "YGGYO",
    "YENİ GİMAT GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "YIGIT",
    "YİĞİT AKÜ MALZEMELERİ NAKLİYAT TURİZM İNŞAAT SANAYİ VE TİCARET A.Ş."
  ],
  [
    "YKBNK",
    "YAPI VE KREDİ BANKASI A.Ş."
  ],
  [
    "YKFIN",
    "YAPI KREDİ FİNANSAL KİRALAMA A.O."
  ],
  [
    "YKFKT",
    "YAPI KREDİ FAKTORİNG A.Ş."
  ],
  [
    "YKSLN",
    "YÜKSELEN ÇELİK A.Ş."
  ],
  [
    "YKYAT",
    "YAPI KREDİ YATIRIM MENKUL DEĞERLER A.Ş."
  ],
  [
    "YONGA",
    "YONGA MOBİLYA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "YUNSA",
    "YÜNSA YÜNLÜ SANAYİ VE TİCARET A.Ş."
  ],
  [
    "YYAPI",
    "YEŞİL YAPI ENDÜSTRİSİ A.Ş."
  ],
  [
    "YYLGD",
    "YAYLA AGRO GIDA SANAYİ VE TİCARET A.Ş."
  ],
  [
    "ZEDUR",
    "ZEDUR ENERJİ ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "ZERGY",
    "ZERAY GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ZGYO",
    "Z GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ],
  [
    "ZKBVK",
    "ZİRAAT KATILIM VARLIK KİRALAMA A.Ş."
  ],
  [
    "ZKBVR",
    "ZKB VARLIK KİRALAMA A.Ş."
  ],
  [
    "ZOREN",
    "ZORLU ENERJİ ELEKTRİK ÜRETİM A.Ş."
  ],
  [
    "ZRGYO",
    "ZİRAAT GAYRİMENKUL YATIRIM ORTAKLIĞI A.Ş."
  ]
]);

const BIST_EQUITY_ALIAS_OVERRIDES = Object.freeze({
  ASELS: Object.freeze(['aselsan', 'aselsan hissesi', 'aselsan elektronik']),
  THYAO: Object.freeze(['thy', 'turk hava yollari', 'turk hava yollari hissesi', 'thy ao']),
  KCHOL: Object.freeze(['koc', 'koc holding', 'koc holding hissesi']),
  TUPRS: Object.freeze(['tupras', 'tupras hissesi', 'tupras rafineri']),
  EREGL: Object.freeze(['eregli', 'erdemir', 'eregli demir celik']),
  SISE: Object.freeze(['sise', 'sisecam', 'sise cam']),
  GARAN: Object.freeze(['garanti', 'garanti bankasi', 'garanti bbva']),
  ISCTR: Object.freeze(['is bankasi', 'turkiye is bankasi', 'is c']),
  BIMAS: Object.freeze(['bim', 'bimas', 'bim market', 'bim magazalar'])
});

function normalizeName(value) {
  return String(value || '')
    .replace(/[??]/g, 'c').replace(/[??]/g, 'g').replace(/[?I?i]/g, 'i')
    .replace(/[??]/g, 'o').replace(/[??]/g, 's').replace(/[??]/g, 'u')
    .toLowerCase().replace(/[?'`]/g, '').replace(/[^a-z0-9\s.]/g, ' ')
    .replace(/\b(a\.s|as|anonim|sirketi|ve|ticaret|sanayi|holding|yatirim|ortakligi|bankasi)\b/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

function uniqueAliases(items) {
  return Object.freeze([...new Set(items.map(item => String(item || '').trim().toLowerCase()).filter(Boolean))]);
}

function buildEquityAsset([symbol, name]) {
  const aliases = uniqueAliases([symbol.toLowerCase(), normalizeName(name), ...(BIST_EQUITY_ALIAS_OVERRIDES[symbol] || [])]);
  return Object.freeze({
    internalAssetId: 'bist:equity:' + symbol,
    canonicalSymbol: symbol,
    displayName: name,
    normalizedName: normalizeName(name),
    assetType: 'equity',
    exchange: 'BIST',
    market: 'BIST',
    currency: 'TRY',
    providerSymbols: Object.freeze({ yahoo: symbol + '.IS' }),
    aliases,
    searchTerms: Object.freeze([]),
    isActive: true,
    metadataUpdatedAt: null
  });
}

function buildIndexAsset({ symbol, name, aliases, yahoo = null }) {
  return Object.freeze({
    internalAssetId: 'bist:index:' + symbol,
    canonicalSymbol: symbol,
    displayName: name,
    normalizedName: normalizeName(name),
    assetType: 'index',
    exchange: 'BIST',
    market: 'BIST',
    currency: 'TRY',
    providerSymbols: Object.freeze({ yahoo }),
    aliases: Object.freeze(aliases),
    searchTerms: Object.freeze([]),
    isActive: true,
    metadataUpdatedAt: null
  });
}

const TEFAS_FUND_ROWS = Object.freeze([
  ["AAK", "ATA PORTFÖY ÇOKLU VARLIK DEĞİŞKEN FON", "Değişken Fon"],
  ["AAL", "ATA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["AAS", "ATA PORTFÖY FON SEPETİ SERBEST FONU", "Serbest Fon"],
  ["AAV", "ATA PORTFÖY İKİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["AC1", "PARDUS PORTFÖY KISA VADELİ KATILIM SERBEST FONU", "Serbest Fon"],
  ["AC4", "A1 PORTFÖY PARA PİYASASI (TL) FON", "Para Piyasası Fonu"],
  ["AC5", "A1 PORTFÖY İSTATİSTİKSEL ARBİTRAJ SERBEST FON", "Serbest Fon"],
  ["AC6", "A1 PORTFÖY DÖRDÜNCÜ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["ACC", "İSTANBUL PORTFÖY DÖRDÜNCÜ HİSSE SENEDİ FONU (HİSSE SENEDİ YOĞUN)", "Hisse Senedi Fonu"],
  ["ACD", "İSTANBUL PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ACU", "İSTANBUL PORTFÖY URARTU SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["ADE", "AK PORTFÖY DEĞİŞKEN FON", "Değişken Fon"],
  ["ADP", "AK PORTFÖY BIST BANKA ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["AED", "ATA PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["AES", "AK PORTFÖY PETROL YABANCI BYF FON SEPETİ FONU", "Yabancı Fon Sepeti Fonu"],
  ["AEV", "ALLBATROSS PORTFÖY İHRACATÇI ŞİRKETLER HİSSE SENEDİ SERBEST (TL) FON", "Hisse Senedi Fonu"],
  ["AFA", "AK PORTFÖY AMERİKA YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["AFO", "AK PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["AFS", "AK PORTFÖY SAĞLIK SEKTÖRÜ YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["AFT", "AK PORTFÖY YENİ TEKNOLOJİLER YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["AFV", "AK PORTFÖY AVRUPA YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["AGC", "AK PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["AHI", "ATLAS PORTFÖY BİRİNCİ HİSSE SENEDİ FONU(HİSSE SENEDİ YOĞUN)", "Hisse Senedi Fonu"],
  ["AHN", "ATLAS PORTFÖY SERBEST(DÖVİZ)FON", "Serbest Fon"],
  ["AHU", "ATLAS PORTFÖY BİRİNCİ ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["AHV", "AZİMUT PYŞ DENGELİ SERBEST FON", "Fon Sepeti Fonu"],
  ["AIS", "AK PORTFÖY KİRA SERTİFİKALARI KATILIM FONU", "Katılım Fonu"],
  ["AJK", "AK PORTFÖY İKINCI SERBEST (DÖVIZ) FON", "Serbest Fon"],
  ["AK2", "AK PORTFÖY UZUN VADELİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["AK3", "AK PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["AKE", "AK PORTFÖY EUROBOND (AMERİKAN DOLARI) BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["AKU", "AK PORTFÖY BIST 30 ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["ALC", "AK PORTFÖY BİST TEMETTÜ 25 ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["AN1", "STRATEJİ PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ANZ", "ATA PORTFÖY DÖRDÜNCÜ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["AOJ", "ALLBATROSS PORTFÖY İNŞAAT SEKTÖRÜ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["AOY", "AK PORTFÖY ALTERNATİF ENERJİ YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["AP7", "PARDUS PORTFÖY YEDİNCİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["APJ", "AK PORTFÖY BIST ŞİRKETLERİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["APT", "AK PORTFÖY ORTA VADELI BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["ARE", "İSTANBUL PORTFÖY YABANCI (GELİŞMEKTE OLAN PİYASALAR) BORÇLANMA ARAÇLARI FONU", "Hisse Senedi Fonu"],
  ["ARL", "AK PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["ARM", "AK PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["AS1", "ALLBATROSS PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["ASJ", "AKTİF PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["AUT", "ATA PORTFÖY DENGELİ DEĞİŞKEN FON", "Değişken Fon"],
  ["AUV", "AK PORTFÖY UZUN VADELİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["AYA", "ATA PORTFÖY KAR PAYI ÖDEYEN HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["AYR", "AK PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["BBF", "A1 PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["BBP", "ALLBATROSS PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["BDS", "PARDUS PORTFÖY BIST 30 DIŞI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Yoğun"],
  ["BDY", "AK PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["BFE", "ALLBATROSS PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["BFT", "AZİMUT PORTFÖY BANKA VE FİNANS SEKTÖRÜ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["BGP", "AK PORTFÖY ÜÇÜNCÜ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["BHF", "A1 PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["BHI", "BV PORTFÖY İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["BHL", "İŞ PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["BID", "QNB FİNANS PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["BIG", "YAPI KREDİ PORTFÖY ÜÇÜNCÜ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["BIH", "A1 PORTFÖY BİRİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["BIO", "İŞ PORTFÖY SÜRDÜRÜLEBİLİRLİK HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["BIS", "BV PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["BJD", "AZİMUT PORTFÖY 13.0 SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["BNC", "AK PORTFÖY BEŞİNCİ SERBEST FON", "Serbest Fon"],
  ["BOL", "AKTİF PORTFÖY BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["BSH", "ATLAS PORTFÖY BANKACILIK SEKTÖRÜ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["BST", "A1 PORTFÖY BANKACILIK SEKTÖRÜ DIŞI HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["BTE", "BV PORTFÖY OYUN VE TEKNOLOJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["BTJ", "ATLAS PORTFÖY İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["BTZ", "ATLAS PORTFÖY BIST 30 DIŞI ŞİRKETLER HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["BUL", "AKTİF PORTFÖY İNŞAAT SEKTÖRÜ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["BUY", "AK PORTFÖY BÜYÜYEN ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["BVM", "ALLBATROSS PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["BVV", "BV PORTFÖY TEKNOLOJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["BVZ", "BV PORTFÖY İSTATİSTİKSEL ARBİTRAJ SERBEST (TL) FON", "Serbest Fon"],
  ["CFO", "ROTA PORTFÖY İKİNCİ PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["CIN", "AKTİF PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["CKF", "ALBARAKA PORTFÖY ÇOKLU VARLIK KATILIM FONU", "Katılım Fonu"],
  ["CKS", "İŞ PORTFÖY BİRİNCİ KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["CPT", "ROTA PORTFÖY ÇİP TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["CPU", "AKTİF PORTFÖY TEKNOLOJİ KATILIM FONU", "Katılım Fonu"],
  ["CVK", "INVEO PORTFÖY ÇOKLU VARLIK KATILIM FONU", "Katılım Fonu"],
  ["DAH", "DENİZ PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["DAS", "DENİZ PORTFÖY ONİKİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["DBA", "DENİZ PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["DBB", "DENİZ PORTFÖY BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["DBH", "DENİZ PORTFÖY EUROBOND (DÖVİZ) BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["DBK", "DENİZ PORTFÖY KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["DBP", "DENİZ PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["DBZ", "DENİZ PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["DCB", "DENİZ PORTFÖY KISA VADELİ SERBEST (TL) FON", "Serbest Fon"],
  ["DDA", "DENİZ PORTFÖY ALTINCI SERBEST FON", "Serbest Fon"],
  ["DDF", "DENİZ PORTFÖY DİNAMO SERBEST FON", "Serbest Fon"],
  ["DEF", "ALLBATROSS PORTFÖY DEFNE SERBEST FON", "Serbest Fon"],
  ["DFC", "DENİZ PORTFÖY TARIM VE GIDA DEĞİŞKEN FON", "Değişken Fon"],
  ["DFD", "DENİZ PORTFÖY EMTİA SERBEST FON", "Serbest Fon"],
  ["DFI", "ATLAS PORTFÖY İKİNCİ SERBEST (TL) FON", "Serbest Fon"],
  ["DGH", "ATA PORTFÖY ÜÇÜNCÜ SERBEST (TL) FONU", "Serbest Fon"],
  ["DHJ", "DENİZ PORTFÖY TEKNOLOJİ ŞİRKETLERİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["DHM", "DENİZ PORTFÖY ESG-SÜRDÜRÜLEBİLİRLİK FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["DKH", "DENİZ PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["DKL", "DENİZ PORTÖY BİRİNCİ KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["DKR", "DENİZ PORTFÖY ONDÖRDÜNCÜ SERBEST FON", "Serbest Fon"],
  ["DL2", "DENİZ PORTFÖY İKİNCİ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["DLD", "DENİZ PORTFÖY SÜRDÜRÜLEBİLİRLİK HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["DLY", "DENİZ PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["DMG", "DENİZ PORTFÖY GÜMÜŞ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["DNK", "TACİRLER PORTFÖY DENGE KATILIM SERBEST FON", "Serbest Fon"],
  ["DNM", "QNB PORTFÖY DİNAMİK DAĞILIMLI SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["DOL", "AKTİF PORTFÖY ÜÇÜNCÜ AKTİF SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["DOV", "DENİZ PORTFÖY ONÜÇÜNCÜ SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["DPB", "DENİZ PORTFÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["DPI", "DENİZ PORTFÖY İSTATİSTİKSEL ARBİTRAJ SERBEST FON", "Serbest Fon"],
  ["DPK", "DENİZ PORTFÖY KİRA SERTİFİKALARI KATILIM (TL) FONU", "Katılım Fonu"],
  ["DPT", "DENİZ PORTFÖY BİST TEMETTÜ 25 ENDEKSİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["DSD", "DENİZ PORTFÖY İKİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["DSP", "DENİZ PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["DTL", "DENİZ PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["DTZ", "AK PORTFÖY DÖNÜŞTÜRÜCÜ TEKNOLOJİLER DEĞİŞKEN FON", "Değişken Fon"],
  ["DUH", "HEDEF PORTFÖY UFUK HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["DVT", "DENİZ PORTFÖY METAVERSE VE DİJİTAL YAŞAM TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["DXP", "DENİZ PORTFÖY İHRACATÇI ŞİRKETLER HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["DYN", "DENİZ PORTFÖY ELEKTRİKLİ VE OTONOM ARAÇ TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["DZE", "DENİZ PORTFÖY BIST 100 ENDEKSİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["DZM", "DENİZ PORTFÖY BEŞİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["EBD", "GLOBAL MD PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["EC2", "GLOBAL MD PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ECA", "GLOBAL MD PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["EDT", "DENİZ PORTFÖY TED EĞİTİME DESTEK SERBEST FON", "Serbest Fon"],
  ["EDU", "İŞ PORTFÖY TEV EĞİTİME DESTEK SERBEST FON", "Değişken Fon"],
  ["EIB", "QİNVEST PORTFÖY DEĞİŞKEN FON", "Değişken Fon"],
  ["EIC", "QİNVEST PORTFÖY İKİNCİ DEĞİŞKEN FONU", "Değişken Fon"],
  ["EID", "QİNVEST PORTFÖY HİSSE SENEDİ FONU (HİSSE YOĞUN FON)", "Hisse Senedi Fonu"],
  ["EIL", "QİNVEST PORTFÖY PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["EKF", "QİNVEST PORTFÖY KİRA SERTİFİKASI KATILIM (TL) FONU", "Katılım Fonu"],
  ["ELZ", "QİNVEST PORTFÖY KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ENJ", "AKTİF PORTFÖY ENERJİ ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["ESG", "AKTİF PORTFÖY ESG SÜRDÜRÜLEBİLİRLİK SERBEST FON", "Serbest Fon"],
  ["ESP", "AURA PORTFÖY EMTİA SERBEST FON", "Serbest Fon"],
  ["EUN", "GARANTİ PORTFÖY İKİNCİ SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["EUZ", "GARANTİ PORTFÖY SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["EYT", "AKTİF PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["FAK", "FONEVA PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["FBC", "FONERİA PORTFÖY KATILIM FONU", "Katılım Fonu"],
  ["FBI", "FİBA PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["FBV", "İŞ PORTFÖY MODEL SERBEST FON", "Serbest Fon"],
  ["FBZ", "FİBA PORTFÖY KAR PAYI ÖDEYEN SERBEST FON", "Serbest Fon"],
  ["FCK", "FONERİA PORTFÖY ÇOKLU VARLIK KATILIM FONU", "Katılım Fonu"],
  ["FD1", "FONERİA PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["FDG", "FONEVA PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["FFH", "QNB FİNANS PORTFÖY ÇOKLU VARLIK KATILIM FONU", "Katılım Fonu"],
  ["FFP", "QNB FİNANS PORTFÖY FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["FFS", "FİBA PORTFÖY 2023 SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["FI3", "QNB FİNANS PORTFÖY BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["FIB", "FİBA PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["FID", "FİBA PORTFÖY ÇOKLU VARLIK İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["FIL", "FİBA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["FIT", "FİBA PORTFÖY BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["FJB", "FİBA PORTFÖY BLOK ZİNCİRİ TEKNOLOJİLERİ SERBEST FON", "Serbest Fon"],
  ["FJZ", "FİBA PORTFÖY FIRTINA SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["FKE", "QNB FİNANS PORTFÖY KRİSTAL SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["FLY", "AKTİF PORTFÖY HAVACILIK VE SAVUNMA TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["FMG", "QNB PORTFÖY GÜMÜŞ SERBEST FON", "Serbest Fon"],
  ["FMR", "FİBA PORTFÖY MART 2025 SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["FNO", "QNB FİNANS PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["FNT", "HEDEF PORTFÖY MODEL HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["FPE", "FİBA PORTFÖY EUROBOND BORÇLANMA ARAÇLARI (DÖVİZ)FONU", "Borçlanma Araçları Fonu"],
  ["FPH", "FİBA PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["FPI", "FONEVA PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["FPK", "FİBA PORTFÖY KISA VADELİ BORÇLANMA ARAÇLARI (TL)FONU", "Borçlanma Araçları Fonu"],
  ["FPZ", "QNB FİNANS PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["FRC", "FONEVA PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["FS5", "FONERİA PORTFÖY BİRİNCİ İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["FS6", "FONERİA PORTFÖY İKİNCİ İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["FSF", "FİBA PORTFÖY PARA PİYASASI SERBEST (TL) FON", "Serbest Fon"],
  ["FSG", "FİBA PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["FSH", "FİBA PORTFÖY FON SEPETİ SERBEST FON", "Serbest Fon"],
  ["FSK", "QNB FİNANS PORTFÖY PARA PİYASASI SERBEST (TL) FON", "Para Piyasası Fonu"],
  ["FSR", "FİBA PORTFÖY İKİNCİ SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["FUA", "AK PORTFÖY İHRACATÇI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["FUB", "QNB PORTFÖY EUROBOND (DÖVİZ) BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["FYD", "QNB FİNANS PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["FYI", "AZİMUT PORTFÖY 4.0 SERBEST FON", "Serbest Fon"],
  ["FYO", "QNB FİNANS PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["FZJ", "FİBA PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["FZP", "FİBA PORTFÖY SERBEST FON", "Serbest Fon"],
  ["GA1", "GARANTİ PORTFÖY BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["GAE", "GARANTİ PORTFÖY BİST30 ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GAF", "INVEO PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["GAG", "INVEO PORTFÖY BİRİNCİ SERBEST (DÖVIZ) FON", "Serbest Fon"],
  ["GAH", "GARANTİ PORTFÖY MUTLAK GETİRİ HEDEFLİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GAS", "GARANTİ PORTFÖY ÜÇÜNCÜ SERBEST(DÖVİZ) FON", "Serbest Fon"],
  ["GBC", "AZİMUT PYŞ YABANCI BYF FON SEPETİ FONU", "Hisse Senedi Fonu"],
  ["GBG", "INVEO PORTFÖY G-20 ÜLKELERİ YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["GBH", "GARANTİ PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["GBJ", "GARANTİ PORTFÖY BANKACILIK SEKTÖRÜ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["GBL", "AZİMUT PYŞ KISA VADELİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["GBN", "GARANTİ PORTFÖY BEŞİNCİ (TL) SERBEST FON", "Serbest Fon"],
  ["GBV", "GARANTİ PORTFÖY BLOCKCHAİN TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GBZ", "AZİMUT PORTFÖY EMTİA FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GGK", "INVEO PORTFÖY ALTIN FON", "Altın Fonu"],
  ["GHS", "GARANTİ PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GID", "GARANTİ PORTFÖY İNŞAAT SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["GIE", "GARANTİ PORTFÖY GARANTİ BBVA İKLİM ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GIH", "ALLBATROSS PORTFÖY GIDA VE İÇECEK SEKTÖRÜ HİSSE SENEDİ SERBEST (TL) FON", "Hisse Senedi Fonu"],
  ["GJB", "INVEO PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GKF", "GLOBAL MD PORTFÖY KATILIM FONU", "Katılım Fonu"],
  ["GKH", "GARANTİ PORTFÖY KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["GKV", "GARANTİ PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GL1", "AZİMUT PYŞ BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["GLC", "GLOBAL MD PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GLG", "GLOBAL MD PORTFÖY CAPİTAL HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["GLS", "AZİMUT PORTFÖY KİRA SERTİFİKALARI (SUKUK) KATILIM FONU", "Katılım Fonu"],
  ["GMA", "AZİMUT PORTFÖY ÇOKLU VARLIK DEĞİŞKEN FON", "Değişken Fon"],
  ["GMC", "TEB PORTFÖY GÜMÜŞ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GMD", "GLOBAL MD PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GMR", "INVEO PORTFÖY İKİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["GNS", "GARANTİ PORTFÖY ENERJİ ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GO1", "FONERİA PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GO2", "FONERİA PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GO3", "FONERİA PORTFÖY ÜÇÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GO4", "FONERİA PORTFÖY DÖRDÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GO6", "FONERİA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["GO9", "FONERİA PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["GOH", "GARANTİ PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GOL", "GARANTİ PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["GPA", "GARANTİ PORTFÖY EUROBOND BORÇLANMA ARAÇLARI (DÖVİZ) FONU", "Borçlanma Araçları Fonu"],
  ["GPB", "GARANTİ PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GPC", "GARANTİ PORTFÖY İKİNCİ SERBEST ( DÖVİZ ) FON", "Serbest Fon"],
  ["GPF", "GARANTİ PORTFÖY BİRİNCİ KATILIM FONU", "Katılım Fonu"],
  ["GPG", "INVEO PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GPI", "GARANTİ PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GPL", "GARANTİ PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["GPT", "AKTİF PORTFÖY ROBOTİK TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GPU", "GARANTİ PORTFÖY ÜÇÜNCÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["GPZ", "GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["GRL", "QNB PORTFÖY AGRESİF SERBEST FON", "Serbest Fon"],
  ["GRO", "GARANTİ PORTFÖY OTUZUNCU SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["GRT", "GARANTİ PORTFÖY TEKNOLOJİ ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GSP", "AZİMUT PYŞ KAR PAYI ÖDEYEN HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["GTA", "GARANTİ PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["GTF", "AZİMUT PYŞ BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["GTH", "GARANTİ PORTFÖY İHRACATÇI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GTM", "GARANTİ PORTFÖY TEMETTÜ ÖDEYEN ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GTY", "GARANTİ PORTFÖY TREND SERBEST FON", "Serbest Fon"],
  ["GTZ", "GARANTİ PORTFÖY GÜMÜŞ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GUB", "GARANTİ PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["GUH", "GARANTI PORTFÖY YABANCI TEKNOLOJİ BYF FON SEPETİ FONU", "Hisse Senedi Fonu"],
  ["GUM", "AK PORTFÖY GÜMÜŞ FON SEPETI FONU", "Fon Sepeti Fonu"],
  ["GUV", "GARANTİ PORTFÖY UZUN VADELİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["GVA", "GARANTİ PORTFÖY ELEKTRİKLİ VE OTONOM ARAÇLAR DEĞİŞKEN FON", "Değişken Fon"],
  ["GVI", "GARANTİ PORTFÖY ÜÇÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GYK", "INVEO PORTFÖY BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["GZE", "GARANTİ PORTFÖY EMTİA SERBEST FON", "Serbest Fon"],
  ["GZG", "GARANTİ PORTFÖY SAĞLIK SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["GZH", "GARANTİ PORTFÖY TEMİZ ENERJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["GZJ", "GARANTİ PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GZL", "GARANTİ PORTFÖY TARIM VE GIDA SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["GZM", "GLOBAL MD PORTFÖY DİNAMİK SERBEST (TL) FON", "Serbest Fon"],
  ["GZN", "GLOBAL MD PORTFÖY BOĞAZİÇİ SERBEST FON", "Serbest Fon"],
  ["GZP", "GARANTİ PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GZR", "GARANTİ PORTFÖY SÜRDÜRÜLEBİLİRLİK HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["GZV", "GARANTİ PORTFÖY ESG SÜRDÜRÜLEBİLİRLİK FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["GZY", "GARANTİ PORTFÖY TURİZM VE SEYAHAT SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["GZZ", "GARANTİ PORTFÖY FİNANS SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["HAM", "HEDEF PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["HAT", "HEDEF PORTFÖY ATLAS İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["HBF", "HSBC PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["HBN", "HSBC PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["HBU", "HSBC PORTFÖY BİST 30 ENDEKSİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["HDA", "HEDEF PORTFÖY DÖRDÜNCÜ İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HDK", "HEDEF PORTFÖY VEGA İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["HEH", "HEDEF PORTFÖY ALGO EVEREST İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HFI", "HEDEF PORTFÖY İKİNCİ KATILIM HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HGM", "HEDEF PORTFÖY İKİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["HGV", "HEDEF PORTFÖY SENTİMENT SERBEST FON", "Serbest Fon"],
  ["HIM", "HEDEF PORTFÖY İKİNCİ MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HIZ", "AZİMUT PORTFÖY DİNAMİK DEĞİŞKEN FON", "Değişken Fon"],
  ["HJB", "HEDEF PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["HKG", "ZİRAAT PORTFÖY HALK'IN ÜRETEN KADINLARI DEĞİŞKEN FON", "Değişken Fon"],
  ["HKH", "HEDEF PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["HKJ", "HEDEF PORTFÖY KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["HKM", "HEDEF PORTFÖY BAŞAK HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HKR", "HSBC PORTFÖY KIRMIZI HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HMC", "HEDEF PORTFÖY EKİNOKS SERBEST (TL) FON", "Serbest Fon"],
  ["HMG", "HSBC PYŞ MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["HMS", "HSBC PORTFÖY SÜRDÜRÜLEBİLİRLİK HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["HOA", "HSBC PORTFÖY TEKNOLOJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["HOY", "HSBC PORTFÖY YABANCI BYF FON SEPETI", "Yabancı Fon Sepeti Fonu"],
  ["HP3", "HEDEF PORTFÖY LİDYA SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["HPD", "HSBC PORTFÖY ÇOKLU VARLIK İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["HPH", "HEDEF PORTFÖY PARA PİYASASI KATILIM FONU", "Katılım Fonu"],
  ["HPO", "HSBC PORTFÖY ÇOKLU VARLIK BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["HPT", "HSBC PORTFÖY KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["HRZ", "AKTİF PORTFÖY BIST HALKA ARZ ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["HSA", "HSBC PORTFÖY DEĞİŞKEN (TL) FON", "Değişken Fon"],
  ["HSL", "HSBC PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["HST", "HSBC PORTFÖY BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["HTJ", "HEDEF PORTFÖY TEKNOLOJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["HVK", "HEDEF PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["HVS", "HSBC PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["HVT", "ALLBATROSS PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["HVU", "ALLBATROSS PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["HVZ", "ALLBATROSS PORTFÖY BİRİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["HYP", "AZİMUT PORTFÖY İVME SERBEST FON", "Serbest Fon"],
  ["HYV", "HEDEF PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["IAE", "İSTANBUL PORTFÖY AGRESİF DEĞİŞKEN FON", "Değişken Fon"],
  ["IAM", "İŞ PORTFÖY AGRESİF FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["IAR", "İSTANBUL PORTFÖY DÖRDÜNCÜ SERBEST FON", "Serbest Fon"],
  ["IAT", "İŞ PORTFÖY KİRA SERTİFİKALARI KATILIM (TL) FONU", "Katılım Fonu"],
  ["IAU", "A1 PORTFÖY İKİNCİ İSTATİSTİKSEL ARBİTRAJ SERBEST FON", "Serbest Fon"],
  ["IAY", "INVEO PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["IBB", "İŞ PORTFÖY ATAK DEĞİŞKEN FON", "Değişken Fon"],
  ["ICA", "ICBC TURKEY PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["ICC", "ICBC TURKEY PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ICD", "ICBC TURKEY PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ICE", "ICBC TURKEY PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["ICF", "ICBC TURKEY PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ICH", "PARDUS PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ICS", "ICBC TURKEY PORTFÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["ICV", "ICBC TURKEY PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["ICZ", "AK PORTFÖY TEKNOLOJİ ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IDD", "LOGOS PORTFÖY DİNAMİK DAĞIMLI SERBEST FON", "Serbest Fon"],
  ["IDF", "İŞ PORTFÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["IDH", "İŞ PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IDL", "AKTİF PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["IDO", "İŞ PORTFÖY ONDOKUZUNCU SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["IDY", "TEB PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["IEV", "İŞ PORTFÖY TAŞIMACILIK DEĞİŞKEN FON", "Değişken Fon"],
  ["IFN", "ICBC TURKEY PORTFÖY SÜRDÜRÜLEBİLİRLİK HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["IFV", "ICBC TURKEY PORTFÖY BİRİNCİ KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["IHA", "ALLBATROSS PORTFÖY İKİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IHC", "INVEO PORTFÖY INTER SERBEST FON", "Serbest Fon"],
  ["IHK", "İŞ PORTFÖY İŞ'TE KADIN HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IHP", "İSTANBUL PORTFÖY İKİNCİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["IHT", "İŞ PORTFÖY İHRACATÇI ŞİRKETLER HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IHV", "INVEO PORTFÖY BEŞİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["IHZ", "ALLBATROSS PORTFÖY İKİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["IIE", "İSTANBUL PORTFÖY ONDÖRDÜNCÜ SERBEST (TL) FON", "Serbest Fon"],
  ["IIH", "İSTANBUL PORTFÖY ÜÇÜNCÜ HİSSE SENEDİ FONU", "Hisse Senedi Yoğun"],
  ["IJA", "INVEO PORTFÖY ATAK DEĞİŞKEN FON", "Değişken Fon"],
  ["IJB", "İŞ PORTFÖY DİJİTAL OYUN SEKTÖRÜ KARMA FON", "Karma Fon"],
  ["IJC", "İŞ PORTFÖY YARI İLETKEN TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["IJH", "ICBC TURKEY PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["IJP", "İŞ PORTFÖY BLOCKCHAİN TEKNOLOJİLERİ KARMA FON", "Karma Fon"],
  ["IJT", "İŞ PORTFÖY TARIM SERBEST FON", "Serbest Fon"],
  ["IJV", "İSTANBUL PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["IJZ", "İŞ PORTFÖY SİBER GÜVENLİK TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["IKL", "İŞ PORTFÖY SAĞLIK ŞİRKETLERİ KARMA FON", "Karma Fon"],
  ["IKP", "İŞ PORTFÖY YENİLENEBİLİR ENERJİ KARMA FON", "Karma Fon"],
  ["ILZ", "İŞ PORTFÖY TEMKİNLİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["IMF", "İSTANBUL PORTFÖY MAESTRO SERBEST FON", "Serbest Fon"],
  ["IML", "İŞ PORTFÖY MODEL PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IOG", "İŞ PORTFÖY GÜMÜŞ SERBEST FON", "Serbest Fon"],
  ["IOO", "İŞ PORTFÖY İKİNCİ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["IPB", "İSTANBUL PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["IPG", "İŞ PORTFÖY ATAK FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["IPJ", "İŞ PORTFÖY ELEKTRİKLİ ARAÇLAR KARMA FON", "Karma Fon"],
  ["IPV", "İŞ PORTFÖY EUROBOND BORÇLANMA ARAÇLARI (DÖVİZ) FONU", "Borçlanma Araçları Fonu"],
  ["IRF", "İSTANBUL PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["IRO", "İSTANBUL PORTFÖY ROBOTİK TEKNOLOJİLERİ SERBEST FON", "Serbest Fon"],
  ["IRT", "INVEO PORTFÖY TEKNOLOJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["IRV", "İSTANBUL PORTFÖY İSTATİSTİKSEL ARBİTRAJ SERBEST FON", "Serbest Fon"],
  ["IRY", "INVEO PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["IST", "İSTANBUL PORTFÖY KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["ITP", "İŞ PORTFÖY TEKNOLOJİ KARMA FON", "Karma Fon"],
  ["IUF", "İŞ PORTFÖY YEDİNCİ SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["IUH", "INVEO PORTFÖY DÖNÜŞTÜRÜCÜ TEKNOLOJİLER FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["IUV", "İŞ PORTFÖY BEŞİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["IV8", "INVEO PORTFÖY KİRA SERTİFİKALARI KATILIM FONU", "Katılım Fonu"],
  ["IVF", "İSTANBUL PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["IVY", "İSTANBUL PORTFÖY BLOCKCHAİN TEKNOLOJİLERİ KARMA FON", "Karma Fon"],
  ["IYB", "AURA PORTFÖY DEĞİŞKEN FONU", "Değişken Fon"],
  ["IZB", "İSTANBUL PORTFÖY BİRİNCİ FON SEPETİ SERBEST FON", "Serbest Fon"],
  ["IZF", "QİNVEST PORTFÖY İKİNCİ KATILIM SERBEST FON", "Serbest Fon"],
  ["IZS", "İSTANBUL PORTFÖY ALTINCI SERBEST FON", "Serbest Fon"],
  ["JET", "ATA PORTFÖY HAVACILIK VE SAVUNMA TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["JUP", "AURA PORTFÖY JÜPİTER SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KAV", "KT PORTFÖY ALTINCI KATILIM SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["KCL", "KARE PORTFÖY ÇOKLU VARLIK KATILIM FONU", "Katılım Fonu"],
  ["KCV", "KT PORTFÖY ÇOKLU VARLIK KATILIM FONU", "Katılım Fonu"],
  ["KDL", "KT PORTFÖY BEŞİNCİ KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KDT", "GARANTİ PORTFÖY KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KGM", "KUVEYT TÜRK PORTFÖY GÜMÜŞ KATILIM FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["KHA", "PARDUS PORTFÖY İKİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["KHB", "KARE PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["KHC", "PARDUS PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["KHJ", "ATLAS PORTFÖY KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["KHT", "ALLBATROSS PORTFÖY KARTAL HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["KIA", "TRIVE PORTFÖY MUTLAK GETİRİ HEDEFLİ DEĞİŞKEN FON", "Değişken Fon"],
  ["KIB", "TRIVE PORTFÖY ROBOTİK TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["KIE", "TRIVE PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["KIS", "QİNVEST PORTFÖY KİRA SERTİFİKASI KATILIM (DÖVİZ) FONU", "Katılım Fonu"],
  ["KKH", "İŞ PORTFÖY DENGELİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["KKL", "ALLBATROSS PORTFÖY KISA VADELİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["KLH", "ATLAS PORTFÖY KATILIM HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["KLS", "ALLBATROSS PORTFÖY KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KLU", "KT PORTFÖY PARA PİYASASI KATILIM (TL) FONU", "Katılım Fonu"],
  ["KMF", "AZİMUT PORTFÖY KIYMETLİ MADENLER KATILIM FONU", "Katılım Fonu"],
  ["KNJ", "KUVEYT TÜRK PORTFÖY ENERJİ KATILIM FONU", "Katılım Fonu"],
  ["KPA", "KUVEYT TÜRK PORTFÖY KAR PAYI ÖDEYEN KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["KPC", "KT PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Yoğun"],
  ["KPD", "KUVEYT TÜRK PORTFÖY KAR PAYI ÖDEYEN KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KPF", "NEO PORTFÖY KAPADOKYA HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["KPH", "İŞ PORTFÖY KAR PAYI ÖDEYEN HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["KPP", "KARE PORTFÖY PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["KPU", "KT PORTFÖY İKİNCİ KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["KRC", "KARE PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["KRF", "KARE PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["KRS", "KARE PORTFÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KRT", "KARE PORTFÖY TÜRKİYE ODAKLI SERBEST (DÖVİZ ) FON", "Serbest Fon"],
  ["KSA", "HEDEF PORTFÖY KISA VADELİ SERBEST (TL) FON", "Serbest Fon"],
  ["KSK", "AZİMUT PORTFÖY İKİNCİ KİRA SERTİFİKALARI KATILIM FONU", "Katılım Fonu"],
  ["KSR", "KT PORTFÖY SÜRDÜRÜLEBİLİRLİK KATILIM FONU", "Katılım Fonu"],
  ["KST", "ALLBATROSS PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["KSV", "KT PORTFÖY KISA VADELİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["KTI", "AZİMUT PORTFÖY KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["KTJ", "KUVEYT TÜRK PORTFÖY TEKNOLOJİ KATILIM FONU", "Katılım Fonu"],
  ["KTM", "KT PORTFÖY BİRİNCİ KATILIM (TL) FONU", "Katılım Fonu"],
  ["KTN", "KT PORTFÖY KİRA SERTİFİKALARI KATILIM (TL) FONU", "Katılım Fonu"],
  ["KTR", "KT PORTFÖY BİRİNCİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["KTS", "KT PORTFÖY İKİNCİ KATILIM SERBEST FON", "Serbest Fon"],
  ["KTT", "KT PORTFÖY DÖRDÜNCÜ KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["KTV", "KT PORTFÖY KISA VADELİ KİRA SERTİFİKALARI KATILIM (TL) FONU", "Kisa Vadeli Kira Sertifikalari Katilim Fonu"],
  ["KUB", "KARE PORTFÖY DEĞİŞKEN (DÖVİZ) FONU", "Değişken Fon"],
  ["KUT", "KT PORTFÖY KIYMETLİ MADENLER KATILIM FONU", "Katılım Fonu"],
  ["KVK", "HEDEF PORTFÖY KISA VADELİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["KVS", "AZİMUT PORTFÖY KISA VADELİ SERBEST (TL) FON", "Serbest Fon"],
  ["KVT", "AK PORTFÖY ENERJİ ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["KYA", "KARE PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["KZL", "KT PORTFÖY KIZILAY'A DESTEK ALTIN KATILIM FONU", "Katılım Fonu"],
  ["KZU", "KUVEYT TÜRK PORTFÖY İKİNCİ ALTIN KATILIM FONU", "Katılım Fonu"],
  ["LLA", "ALLBATROSS PORTFÖY AYDIN HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["LPH", "STATECH PORTFÖY İKİNCİ ALPHA SERBEST FON", "Serbest Fon"],
  ["MAC", "MARMARA CAPITAL PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["MAD", "MEKSA PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["MBL", "MEKSA PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["MD1", "MT PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["MD2", "MT PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["MET", "GARANTİ PORTFÖY METAVERSE VE YENİ TEKNOLOJİLER DEĞİŞKEN FON", "Değişken Fon"],
  ["MGB", "İŞ PORTFÖY MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["MGH", "TEB PORTFÖY MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["MJB", "AKTİF PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["MJG", "AKTİF PORTFÖY GÜMÜŞ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["MJH", "AKTİF PORTFÖY FORTUNA SERBEST FON", "Serbest Fon"],
  ["MJL", "AKTİF PORTFÖY AKTİF SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["MKA", "MARMARA CAPİTAL PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["MKG", "AKTİF PORTFÖY ALTIN KATILIM FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["MMH", "AKTİF PORTFÖY BIST 30 ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Yoğun"],
  ["MPF", "AKTİF PORTFÖY KISA VADELİ KİRA SERTİFİKASI KATILIM (TL) FONU", "Kisa Vadeli Kira Sertifikalari Katilim Fonu"],
  ["MPK", "AKTİF PORTFÖY KİRA SERTİFİKASI KATILIM (TL) FONU", "Katılım Fonu"],
  ["MPL", "MT PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["MPN", "AKTİF PORTFÖY İKİNCİ AKTİF SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["MPP", "MEKSA PORTFÖY PRİME SERBEST FON", "Serbest Fon"],
  ["MPS", "AKTİF PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Yoğun"],
  ["MRI", "TEB PORTFÖY MERİDYEN SERBEST FON", "Serbest Fon"],
  ["MT1", "MT PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["MT2", "MT PORTFÖY İKİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["MTG", "DENİZ PORTÖY MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST FON (HİSSE SENEDİ YOGUN FON)", "Serbest Fon"],
  ["MTH", "MT PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["MTS", "AKTİF PORTFÖY TARIM VE SÜRDÜRÜLEBİLİRLİK FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["MTV", "AK PORTFÖY METAVERSE VE DİJİTAL YAŞAM TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["MTX", "TEB PORTFÖY METAVERSE VE DİJİTAL TEKNOLOJİLER DEĞİŞKEN FON", "Değişken Fon"],
  ["MUT", "GARANTİ PORTFÖY MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["NAU", "NEO PORTFÖY ALTIN FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["NBZ", "NEO PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["NCS", "NUROL PORTFÖY ÜÇÜNCÜ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["NFF", "NEO PORTFÖY FON SEPETİ SERBEST FON", "Serbest Fon"],
  ["NHP", "NEO PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["NHY", "NEO PORTFÖY BİRİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["NJF", "NUROL PORTFÖY ALTIN FONU", "Katılım Fonu"],
  ["NJR", "NUROL PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["NJY", "NUROL PORTFÖY BİRİNCİ KATILIM FONU", "Katılım Fonu"],
  ["NNF", "HEDEF PORTFÖY BİRİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["NPH", "NUROL PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["NRC", "NEO PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["NRG", "NEO PORTFÖY BİRİNCİ PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["NSA", "NEO PORTFÖY PARA PİYASASI KATILIM SERBEST FON", "Serbest Fon"],
  ["NSD", "NUROL PORTFÖY DÖRDÜNCÜ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["NSH", "NUROL PORTFÖY İSTATİSTİKSEL ARBİTRAJ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["NSK", "NEO PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["NUB", "NUROL PORTFÖY BEŞİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["NVB", "NEO PORTFÖY İKİNCİ PARA PİYASASI (TL) FON", "Para Piyasası Fonu"],
  ["NVC", "NEO PORTFÖY VENTO SERBEST FON", "Serbest Fon"],
  ["NVK", "INVEO PORTFÖY KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["NVT", "NEO PORTFÖY ÜÇÜNCÜ SERBEST (TL) FON", "Serbest Fon"],
  ["NVZ", "NEO PORTFÖY ORSA SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["NZH", "NEO PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Değişken Fon"],
  ["NZT", "NEO PORTFÖY PARA PİYASASI SERBEST FON", "Serbest Fon"],
  ["OBI", "OYAK PORTFÖY İKİNCİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["OBP", "OYAK PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ODD", "OYAK PORTFÖY DÖRDÜNCÜ SERBEST FON", "Serbest Fon"],
  ["ODP", "OSMANLI PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["ODS", "OYAK PORTFÖY İKİNCİ SERBEST(DÖVİZ) FON", "Serbest Fon"],
  ["ODV", "AK PORTFÖY ÜÇÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OFI", "OYAK PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OFS", "OYAK PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OGD", "OYAK PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["OHB", "OYAK PORTFÖY BİRİNCİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["OHK", "OYAK PORTFÖY KATILIM HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["OIL", "OSMANLI PORTFÖY AGRESİF FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OIR", "OSMANLI PORTFÖY DENGELİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OJB", "QNB FİNANS PORTFÖY BEŞİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["OJK", "QNB FİNANS PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["OJT", "QNB FİNANS PORTFÖY TEKNOLOJİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OKD", "OYAK PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["OKP", "OYAK PORTFÖY BİRİNCİ KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["OKT", "OYAK PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["OLA", "OSMANLI PORTFÖY İKİNCİ SERBEST (DÖVİZ- AVRO) FON", "Serbest Fon"],
  ["OLD", "QNB FİNANS PORTFÖY TEMİZ ENERJİ VE SU FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OLE", "OSMANLI PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OMG", "AZİMUT PORTFÖY FORZA INVEST SERBEST ÖZEL FON", "Hisse Senedi Fonu"],
  ["ONE", "AKTİF PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["ONK", "AK PORTFÖY ONİKİNCİ SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["ONN", "AKTİF PORTFÖY AKTİF ONİKS SERBEST (TL) FON", "Serbest Fon"],
  ["ONS", "İŞ PORTFÖY ONİKİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["OPB", "OSMANLI PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["OPD", "OSMANLI PORTFÖY ANKA SERBEST FON", "Serbest Fon"],
  ["OPF", "OSMANLI PORTFÖY AGRESİF DEĞİŞKEN FON", "Değişken Fon"],
  ["OPH", "OSMANLI PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["OPI", "OSMANLI PORTFÖY İKİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["OPL", "OSMANLI PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ORC", "QİNVEST PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["OSD", "OSMANLI PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["OSL", "OSMANLI PORTFÖY KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["OTJ", "OYAK PORTFÖY KIYMETLİ MADENLER FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["OTK", "OYAK PORTFÖY BİRİNCİ KATILIM SERBEST FON", "Serbest Fon"],
  ["OUD", "OSMANLI PORTFÖY ATLANTİK SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["OVD", "QNB FİNANS PORTFÖY EMTİA FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["PAF", "A1 PORTFÖY ALTIN FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["PAL", "AK PORTFÖY ALTINCI SERBEST(DÖVİZ) FON", "Serbest Fon"],
  ["PBI", "PARDUS PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["PBK", "QİNVEST PORTFÖY BİRİNCİ KATILIM SERBEST(DÖVİZ) FON", "Serbest Fon"],
  ["PBR", "PUSULA PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["PDD", "QİNVEST PORTFÖY KATILIM FONU", "Katılım Fonu"],
  ["PDF", "QİNVEST PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["PFO", "PHİLLİP PORTFÖY FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["PFS", "ATLAS PORTFÖY FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["PHE", "PUSULA PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["PHI", "PİRAMİT PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["PID", "PİRAMİT PORTFÖY DEĞİŞKEN FON", "Değişken Fon"],
  ["PIL", "ROTA PORTFÖY PİL TEKNOLOJİLERİ VE ENERJİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["PIR", "PİRAMİT PORTFÖY ALTIN FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["PJL", "PHİLLİP PORTFÖY PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["PJP", "PERFORM PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["PKF", "ATA PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["PKV", "PARDUS PORTFÖY KISA VADELİ SERBEST (TL) FON", "Serbest Fon"],
  ["POS", "PARDUS PORTFÖY ONBEŞİNCİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["PP1", "PARDUS PORTFÖY BİRİNCİ KATILIM FONU", "Katılım Fonu"],
  ["PPB", "PHİLLİP PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["PPE", "PHİLLİP PORTFÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["PPI", "YAPI KREDİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PPK", "QNB PORTFÖY PARA PİYASASI KATILIM (TL) FONU", "Katılım Fonu"],
  ["PPM", "PİRAMİT PORTFÖY MUTLAK GETİRİ HEDEFLİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["PPN", "NUROL PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PPP", "PERFORM PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PPS", "PHİLLİP PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["PPT", "ATLAS PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PPZ", "AZİMUT PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PRD", "PİRAMİT PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PRH", "AURA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PRU", "ALLBATROSS PORTFÖY PARA PİYASASI SERBEST (TL) FON", "Serbest Fon"],
  ["PRY", "PUSULA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["PSE", "ATLAS PORTFÖY PARA PİYASASI SERBEST FON", "Serbest Fon"],
  ["PSL", "AZİMUT PORTFÖY 8.0 SERBEST FON", "Serbest Fon"],
  ["PUC", "AK PORTFÖY BİRİNCİ KISA VADELİ SERBEST (TL) FON", "Serbest Fon"],
  ["PVK", "ALBARAKA PORTFÖY KISA VADELİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["RAF", "ROTA PORTFÖY ALTINCI SERBEST FON", "Serbest Fon"],
  ["RBA", "ALBARAKA PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["RBF", "ROTA PORTFÖY BİRİNCİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["RBH", "ALBARAKA PORTFÖY KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Yoğun"],
  ["RBI", "RE-PIE PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["RBK", "ALBARAKA PORTFÖY KATILIM FONU", "Katılım Fonu"],
  ["RBL", "QNB PORTFÖY ROBOTİK VE BLOCKCHAİN TEKNOLOJİLERİ SERBEST FON", "Serbest Fon"],
  ["RBN", "RE-PIE PORTFÖY BEŞİNCİ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["RBP", "RE-PIE PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["RBR", "RE-PIE PORTFÖY BİRİNCİ KATILIM SERBEST FON", "Serbest Fon"],
  ["RBT", "ALBARAKA PORTFÖY KİRA SERTİFİKALARI KATILIM FONU", "Kira Sertifikası Fonu"],
  ["RBV", "ALBARAKA PORTFÖY KISA VADELİ KİRA SERTİFİKALARI KATILIM (TL) FONU", "Kisa Vadeli Kira Sertifikalari Katilim Fonu"],
  ["RD1", "ROTA PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RDF", "ROTA PORTFÖY DOKUZUNCU HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["RHS", "ROTA PORTFÖY HİSSE SENEDİ (TL) FON", "Hisse Senedi Fonu"],
  ["RIH", "RE-PIE PORTFÖY İKİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["RIK", "RE-PIE PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RJG", "RE-PIE PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["RKH", "RE-PIE PORTFÖY KATILIM HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["RKS", "ROTA PORTFÖY KİRA SERTİFİKALARI KATILIM FONU", "Katılım Fonu"],
  ["RKV", "RE-PIE PORTFÖY KISA VADELİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["ROF", "ROTA PORTFÖY ONUNCU SERBEST FON", "Serbest Fon"],
  ["RPC", "ROTA PORTFÖY İKLİM DEĞİŞİKLİĞİ ÇÖZÜMLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RPD", "RE-PIE PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RPG", "ROTA PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["RPI", "ROTA PORTFÖY İKİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["RPM", "ROTA PORTFÖY İLAÇ VE MEDİKAL TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RPP", "ROTA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["RPS", "ROTA PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["RPT", "ROTA PORTFÖY İKİNCİ SERBEST (TL) FON", "Serbest Fon"],
  ["RPX", "ROTA PORTFÖY ÜÇÜNCÜ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["RTD", "RE-PIE PORTFÖY TEKNOLOJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RTG", "ATA PORTFÖY ROBOTİK TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["RTH", "RE-PIE PORTFÖY BİRİNCİ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["RTP", "RE-PIE PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["RUT", "BV PORTFÖY ROBOTİK VE UZAY TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["SAS", "AK PORTFÖY SABANCI TOPLULUĞU ŞİRKETLERİ ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["SHE", "TEB PORTFÖY ÖNCE KADIN DEĞİŞKEN FON", "Değişken Fon"],
  ["SNY", "ATLAS PORTFÖY SANAYİ SEKTÖRÜ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["SOS", "HEDEF PORTFÖY SAĞLIK SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["SPE", "AZIMUT PORTFÖY 5.0 SERBEST (DÖVIZ) FON", "Serbest Fon"],
  ["SPN", "AZIMUT PORTFÖY PİYASA NÖTR SERBEST FON", "Serbest Fon"],
  ["SPR", "BV PORTFÖY SPOR ENDÜSTRİSİ DEĞİŞKEN FON", "Değişken Fon"],
  ["SPT", "AKTİF PORTFÖY KATILIM FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["SSK", "DENİZ PORTFÖY SAĞLIK SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["ST1", "STRATEJİ PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["STI", "ATLAS PORTFÖY SENTİMENT SERBEST FON", "Serbest Fon"],
  ["SUA", "ÜNLÜ PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["SUB", "ÜNLÜ PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["SUC", "ÜNLÜ PORTFÖY ÜÇÜNCÜ DEĞIŞKEN FON", "Değişken Fon"],
  ["SVB", "STRATEJİ PORTFÖY AGRESİF DEĞİŞKEN FON", "Değişken Fon"],
  ["TAL", "ATLAS PORTFÖY ALTIN KATILIM FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["TAR", "AK PORTFÖY TARIM VE GIDA TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["TAU", "İŞ PORTFÖY BIST BANKA ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["TBT", "TEB PORTFÖY BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["TBV", "İŞ PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["TCA", "ZİRAAT PORTFÖY ALTIN KATILIM FONU", "Katılım Fonu"],
  ["TCB", "TACİRLER PORTFÖY PARA PİYASASI FONU", "Para Piyasası Fonu"],
  ["TCC", "TACİRLER PORTFÖY SERBEST ( DÖVİZ ) FON", "Serbest Fon"],
  ["TCD", "TACİRLER PORTFÖY DEĞIŞKEN FON", "Değişken Fon"],
  ["TCF", "TEB PORTFÖY ÜÇÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TDG", "İŞ PORTFÖY YABANCI BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["TE3", "TEB PORTFÖY MUTLAK GETİRİ HEDEFLİ DEĞİŞKEN FON", "Değişken Fon"],
  ["TE4", "TEB PORTFÖY BİRİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["TEJ", "AZİMUT PORTFÖY TEKNOLOJİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TFF", "TEB PORTFÖY AMERİKA TEKNOLOJİ YABANCI BYF FON SEPETİ FONU", "Yabancı Fon Sepeti Fonu"],
  ["TGA", "GARANTİ PORTFÖY AGRESİF DEĞİŞKEN FON", "Değişken Fon"],
  ["TGE", "İŞ PORTFÖY EMTİA YABANCI BYF FON SEPETİ FONU", "Yabancı Fon Sepeti Fonu"],
  ["TGR", "AK PORTFÖY TURİZM VE SEYAHAT SEKTÖRÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["THD", "TRIVE PORTFÖY BİRİNCİ HİSSE SENEDİ (TL) FON", "Hisse Senedi Fonu"],
  ["THT", "TRİVE PORTFÖY HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["TI2", "İŞ PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["TI3", "İŞ PORTFÖY İŞ BANKASI İŞTİRAKLERİ ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["TI4", "İŞ PORTFÖY TEMKİNLİ DEĞİŞKEN FON", "Değişken Fon"],
  ["TI6", "İŞ PORTFÖY ORTA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["TI7", "İŞ PORTFÖY DENGELİ DEĞİŞKEN FON", "Değişken Fon"],
  ["TIE", "İŞ PORTFÖY BIST 30 ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["TJF", "TEB PORTFÖY SÜRDÜRÜLEBİLİRLİK FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TJI", "TEB PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TJT", "TEB PORTFÖY ALTINCI SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["TKF", "TACİRLER PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["TLE", "AURA PORTFÖY YABANCI BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["TLH", "AURA PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["TLY", "TERA PORTFÖY BİRİNCİ SERBEST FON", "Serbest Fon"],
  ["TLZ", "ATA PORTFÖY ANALİZ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["TMC", "İŞ PORTFÖY TEMA DEĞİŞKEN FON", "Değişken Fon"],
  ["TMG", "İŞ PORTFÖY YABANCI HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["TMM", "TERA PORTFÖY İKİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["TMZ", "İŞ PORTFÖY SÜRDÜRÜLEBİLİRLİK VE TARIM FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TOT", "TEB PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["TP2", "TERA PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["TPC", "TEB PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TPF", "TACİRLER PORTFÖY BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["TPJ", "TEB PORTFÖY BİRİNCİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["TPL", "TEB PORTFÖY EUROBOND (DÖVİZ) BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["TPP", "TEB PORTFÖY PUSULA SERBEST FON", "Serbest Fon"],
  ["TPV", "AURA PORTFÖY İKİNCİ DEĞİŞKEN FON", "Değişken Fon"],
  ["TPZ", "TEB PORTFÖY KİRA SERTİFİKALARI (DÖVİZ) KATILIM FONU", "Katılım Fonu"],
  ["TRO", "TRIVE PORTFÖY ALTIN FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["TRU", "TERA PORTFÖY KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["TTA", "İŞ PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["TTE", "İŞ PORTFÖY BIST TEKNOLOJİ AĞIRLIK SINIRLAMALI ENDEKSİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["TTL", "TACİRLER PORTFÖY KARTOPU SERBEST FON", "Serbest Fon"],
  ["TTV", "TACİRLER PORTFÖY VEGA SERBEST (TL) FON", "Serbest Fon"],
  ["TUA", "TEB PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["TVN", "TRIVE PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["TYH", "TEB PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["TZD", "ZİRAAT PORTFÖY HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["TZT", "ZİRAAT PORTFÖY BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["UJA", "ÜNLÜ PORTFÖY İSTATİSTİKSEL ARBİTRAJ SERBEST FON", "Serbest Fon"],
  ["ULH", "ÜNLÜ PORTFÖY ONUNCU SERBEST FON", "Serbest Fon"],
  ["UP1", "ÜNLÜ PORTFÖY ALTIN FONU", "Altın Ve Diğer Kıymetli Madenler Fonu"],
  ["UP2", "ÜNLÜ PORTFÖY ONBİRİNCİ SERBEST (TL) FON", "Serbest Fon"],
  ["UPD", "ÜNLÜ PORTFÖY DÖRDÜNCÜ SERBEST (DÖVIZ) FON", "Serbest Fon"],
  ["UPH", "ÜNLÜ PORTFÖY HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["UPP", "ÜNLÜ PORTFÖY PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["URA", "ATA PORTFÖY ENERJİ DEĞİŞKEN FON", "Değişken Fon"],
  ["USY", "ÜNLÜ PORTFÖY MUTLAK GETİRİ HEDEFLİ SERBEST FON", "Serbest Fon"],
  ["VAY", "AK PORTFÖY DEĞER ODAKLI 100 ŞİRKETLERİ HİSSE SENEDİ (TL) FONU", "Hisse Senedi Fonu"],
  ["VCY", "AK PORTFÖY ELEKTRİKLİ VE OTONOM ARAÇ TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["VFK", "ZİRAAT PORTFÖY İKİNCİ KISA VADELİ KİRA SERTİFİKALARI KATILIM (TL) FONU", "Kisa Vadeli Kira Sertifikalari Katilim Fonu"],
  ["VMV", "VEGA PORTFÖY MAVİ SERBEST FON", "Serbest Fon"],
  ["VNK", "VEGA PORTFÖY ANKA SERBEST FON", "Serbest Fon"],
  ["YAC", "YAPI KREDİ PORTFÖY İKİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["YAK", "YAPI KREDİ PORTFÖY KARMA FON", "Karma Fon"],
  ["YAN", "YAPI KREDİ PORTFÖY BİRİNCİ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["YAS", "YAPI KREDİ PORTFÖY KOÇ HOLDİNG İŞTİRAK VE HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YAY", "YAPI KREDİ PORTFÖY YABANCI TEKNOLOJİ SEKTÖRÜ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YBE", "YAPI KREDİ PORTFÖY EUROBOND (DOLAR) BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["YBH", "YAPI KREDİ PORTFÖY 5-15 YIL VADELİ SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YBS", "YAPI KREDİ PORTFÖY ÖZEL SEKTÖR BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["YCK", "YAPI KREDİ PORTFÖY PY CİHANGİR SERBEST ÖZEL FON", "Serbest Fon"],
  ["YCP", "YAPI KREDİ PORTFÖY BANKACILIK SEKTÖRÜ HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["YCY", "İSTANBUL PORTFÖY KİRA SERTİFİKALARI KATILIM FONU", "Fon Sepeti Fonu"],
  ["YDI", "YAPI KREDİ PORTFÖY İKİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YDP", "YAPI KREDİ PORTFÖY PY ÜÇÜNCÜ DEĞİŞKEN ÖZEL FON", "Değişken Fon"],
  ["YEF", "YAPI KREDİ PORTFÖY BIST 30 ENDEKSİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YFV", "YAPI KREDİ PORTFÖY KİRA SERTİFİKALARI KATILIM FONU", "Katılım Fonu"],
  ["YGM", "YAPI KREDİ PORTFÖY EMTİA SERBEST FON", "Serbest Fon"],
  ["YHB", "YAPI KREDİ PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YHI", "YAPI KREDİ PORTFÖY İNŞAAT SEKTÖRÜ HİSSE SENEDİ SERBEST (TL) FON", "Serbest Fon"],
  ["YHK", "YAPI KREDİ PORTFÖY KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YHS", "YAPI KREDİ PORTFÖY BİRİNCİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YHT", "YAPI KREDİ PORTFÖY KISA VADELİ BORÇLANMA ARAÇLARI (TL) FONU", "Borçlanma Araçları Fonu"],
  ["YHZ", "YAPI KREDİ PORTFÖY BIST TEKNOLOJİ AĞIRLIK SINIRLAMALI ENDEKSİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YJH", "YAPI KREDİ PORTFÖY TEMİZ ENERJİ DEĞİŞKEN FONU", "Değişken Fon"],
  ["YJK", "YAPI KREDİ PORTFÖY DÖRDÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["YJY", "YAPI KREDİ PORTFÖY YENİKÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YKS", "YAPI KREDİ PORTFÖY İSTANBUL SERBEST FON", "Serbest Fon"],
  ["YKT", "YAPI KREDİ PORTFÖY ALTIN FONU", "Altın Fonu"],
  ["YLC", "ATA PORTFÖY TARIM VE GIDA DEĞİŞKEN FON", "Değişken Fon"],
  ["YLE", "YAPI KREDİ PORTFÖY BIST SÜRDÜRÜLEBİLİRLİK ENDEKSİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["YLO", "YAPI KREDİ PORTFÖY ELEKTRİKLİ ARAÇLAR DEĞİŞKEN FON", "Değişken Fon"],
  ["YMD", "YAPI KREDİ PORTFÖY MASLAK SERBEST (DÖVİZ- ABD DOLARI) FON", "Serbest Fon"],
  ["YNK", "YAPI KREDİ PORTFÖY NİŞANTAŞI KAR PAYI ÖDEYEN SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YOT", "YAPI KREDİ PORTFÖY ORTA VADELİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["YP4", "YAPI KREDİ PORTFÖY FERİKÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YPC", "YAPI KREDİ PORTFÖY İKLİM DEĞİŞİKLİĞİ ÇÖZÜMLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["YPF", "YAPI KREDİ PORTFÖY ALFA SERBEST FON", "Serbest Fon"],
  ["YPK", "YAPI KREDİ PORTFÖY GALATA SERBEST FON", "Serbest Fon"],
  ["YPL", "YAPI KREDİ PORTFÖY BALAT SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YPV", "YAPI KREDİ PORTFÖY ÜÇÜNCÜ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["YSL", "YAPI KREDİ PORTFÖY KAR PAYI ÖDEYEN KİRA SERTİFİKALARI KATILIM SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YSO", "YAPI KREDİ PORTFÖY SAĞLIK SEKTÖRÜ SERBEST FON", "Serbest Fon"],
  ["YSU", "YAPI KREDİ PORTFÖY ÜÇÜNCÜ DEĞİŞKEN FON", "Değişken Fon"],
  ["YTD", "YAPI KREDİ PORTFÖY YABANCI FON SEPETİ FONU", "Yabancı Fon Sepeti Fonu"],
  ["YTV", "YAPI KREDİ PORTFÖY TARIM DEĞİŞKEN FON", "Değişken Fon"],
  ["YTY", "YAPI KREDİ PORTFÖY TARABYA SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["YUB", "YAPI KREDİ PORTFÖY KARAKÖY HİSSE SENEDİ SERBEST FON", "Serbest Fon"],
  ["YUN", "YAPI KREDİ PORTFÖY İSTİNYE SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["YVB", "YAPI KREDİ PORTFÖY UZUN VADELİ BORÇLANMA ARAÇLARI FONU", "Borçlanma Araçları Fonu"],
  ["YVG", "YAPI KREDİ PORTFÖY SARIYER SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["YZC", "YAPI KREDİ PORTFÖY FİNTECH VE BLOCKCHAİN TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["YZG", "YAPI KREDİ PORTFÖY GÜMÜŞ FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["YZH", "TEB PORTFÖY BIST BANKA ENDEKSİ HİSSE SENEDİ FONU (HİSSE SENEDİ YOĞUN)", "Hisse Senedi Fonu"],
  ["YZK", "YAPI KREDİ PORTFÖY KALAMIŞ SERBEST FON", "Serbest Fon"],
  ["ZBD", "ZİRAAT PORTFÖY DENGELİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ZBI", "ZİRAAT PORTFÖY ÇOKLU VARLIK BİRİNCİ KATILIM FONU", "Katılım Fonu"],
  ["ZBJ", "ZİRAAT PORTFÖY BAŞAK PARA PİYASASI (TL) FONU", "Para Piyasası Fonu"],
  ["ZBO", "ZİRAAT PORTFÖY İKİNCİ KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["ZCD", "ZİRAAT PORTFÖY ALTINCI SERBEST (TL) FON", "Serbest Fon"],
  ["ZCK", "ZİRAAT PORTFÖY ÇOKLU VARLIK İKİNCİ KATILIM FONU", "Katılım Fonu"],
  ["ZCN", "ZİRAAT PORTFÖY EMTİA FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["ZDD", "ZİRAAT PORTFÖY TEMKİNLİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ZDZ", "ZİRAAT PORTFÖY AGRESİF DEĞİŞKEN FON", "Değişken Fon"],
  ["ZFB", "AK PORTFÖY FİNTEK VE BLOKZİNCİRİ TEKNOLOJİLERİ DEĞİŞKEN FON", "Değişken Fon"],
  ["ZHH", "ZİRAAT PORTFÖY HALKBANK SÜRDÜRÜLEBİLİRLİK 30 ŞİRKETLERİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ZJB", "ZİRAAT PORTFÖY BİRİNCİ SERBEST (TL) FON", "Serbest Fon"],
  ["ZJI", "ZİRAAT PORTFÖY İKİNCİ SERBEST (TL) FON", "Serbest Fon"],
  ["ZJL", "ZİRAAT PORTFÖY BIST 100 DIŞI ŞİRKETLER HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ZJV", "ZİRAAT PORTFÖY BIST 30 DIŞI YILDIZ PAZAR ŞİRKETLERİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ZLH", "ZİRAAT PORTFÖY BIST 100-30 ŞİRKETLERİ HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ZMT", "AZİMUT PORTFÖY 22.0 SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["ZMY", "ZİRAAT PORTFÖY METAVERSE VE YENİ TEKNOLOJİLER DEĞİŞKEN FON", "Değişken Fon"],
  ["ZP6", "ZİRAAT PORTFÖY SEDEF KATILIM SERBEST (DÖVİZ - AMERİKAN DOLARI) FON", "Serbest Fon"],
  ["ZP8", "ZİRAAT PORTFÖY KEHRİBAR KATILIM SERBEST (TL) FON", "Serbest Fon"],
  ["ZP9", "ZİRAAT PORTFÖY AKİK KATILIM SERBEST (DÖVİZ-AVRO) FON", "Serbest Fon"],
  ["ZPA", "ZİRAAT PORTFÖY SERBEST (DÖVİZ) FON", "Serbest Fon"],
  ["ZPC", "ZİRAAT PORTFÖY FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["ZPE", "ZİRAAT PORTFÖY KATILIM HİSSE SENEDİ FONU", "Hisse Senedi Fonu"],
  ["ZPF", "ZİRAAT PORTFÖY KATILIM FONU (DÖVİZ)", "Katılım Fonu"],
  ["ZPG", "ZİRAAT PORTFÖY KİRA SERTİFİKALARI (SUKUK) KATILIM FONU", "Katılım Fonu"],
  ["ZSF", "ZİRAAT PORTFÖY S&P/OIC COMCEC (İSEDAK) 50 SHARİAH ŞİRKETLERİ YABANCI HİSSE SENEDİ FONU", "Yabancı Hisse Senedi Fonu"],
  ["ZSG", "ZİRAAT PORTFÖY ESG SÜRDÜRÜLEBİLİRLİK FON SEPETİ FONU", "Fon Sepeti Fonu"],
  ["ZVO", "ZİRAAT PORTFÖY ÜÇÜNCÜ SERBEST (TL) FON", "Serbest Fon"]
]);

function buildTefasFundAsset([symbol, name, category]) {
  return Object.freeze({
    internalAssetId: 'tefas:fund:' + symbol,
    canonicalSymbol: symbol,
    displayName: name,
    normalizedName: normalizeName(name),
    assetType: 'fund',
    exchange: 'TEFAS',
    market: 'TEFAS',
    currency: null,
    providerSymbols: Object.freeze({ yahoo: null }),
    aliases: uniqueAliases([symbol, symbol + ' fonu', name, normalizeName(name)]),
    searchTerms: Object.freeze(category ? [category] : []),
    isActive: true,
    metadataUpdatedAt: null
  });
}

const BIST_INDEX_ROWS = Object.freeze([
  Object.freeze({ symbol: 'XU100', name: 'BIST 100 Endeksi', yahoo: 'XU100.IS', aliases: Object.freeze(['xu100', 'xu100.is', 'bist 100', 'bist100', 'borsa istanbul 100', 'bist yuz']) }),
  Object.freeze({ symbol: 'XU030', name: 'BIST 30 Endeksi', yahoo: 'XU030.IS', aliases: Object.freeze(['xu030', 'xu030.is', 'bist 30', 'bist30', 'bist otuz']) }),
  Object.freeze({ symbol: 'XU050', name: 'BIST 50 Endeksi', aliases: Object.freeze(['xu050', 'bist 50', 'bist50']) }),
  Object.freeze({ symbol: 'XUTUM', name: 'BIST Tum Endeksi', aliases: Object.freeze(['xutum', 'bist tum', 'bist tum endeksi']) }),
  Object.freeze({ symbol: 'XTUMY', name: 'BIST Tum-100 Endeksi', aliases: Object.freeze(['xtumy', 'bist tum 100', 'bist tum-100', 'bist tum eksi 100']) }),
  Object.freeze({ symbol: 'XBANK', name: 'BIST Banka Endeksi', yahoo: 'XBANK.IS', aliases: Object.freeze(['xbank', 'xbank.is', 'bist banka', 'banka endeksi', 'bankacilik endeksi']) }),
  Object.freeze({ symbol: 'XUSIN', name: 'BIST Sinai Endeksi', yahoo: 'XUSIN.IS', aliases: Object.freeze(['xusin', 'xusin.is', 'bist sinai', 'sinai endeksi', 'sanayi endeksi']) }),
  Object.freeze({ symbol: 'XUHIZ', name: 'BIST Hizmetler Endeksi', yahoo: 'XUHIZ.IS', aliases: Object.freeze(['xuhiz', 'xuhiz.is', 'bist hizmetler', 'hizmetler endeksi']) }),
  Object.freeze({ symbol: 'XUMAL', name: 'BIST Mali Endeksi', aliases: Object.freeze(['xumal', 'bist mali', 'mali endeks', 'mali endeksi']) }),
  Object.freeze({ symbol: 'XUTEK', name: 'BIST Teknoloji Endeksi', yahoo: 'XUTEK.IS', aliases: Object.freeze(['xutek', 'xutek.is', 'bist teknoloji', 'teknoloji endeksi']) }),
  Object.freeze({ symbol: 'XGIDA', name: 'BIST Gida, Icecek Endeksi', aliases: Object.freeze(['xgida', 'bist gida icecek', 'gida icecek endeksi']) }),
  Object.freeze({ symbol: 'XILTM', name: 'BIST Iletisim Endeksi', aliases: Object.freeze(['xiltm', 'bist iletisim', 'iletisim endeksi']) }),
  Object.freeze({ symbol: 'XTRZM', name: 'BIST Turizm Endeksi', aliases: Object.freeze(['xtrzm', 'bist turizm', 'turizm endeksi']) }),
  Object.freeze({ symbol: 'XULAS', name: 'BIST Ulastirma Endeksi', aliases: Object.freeze(['xulas', 'bist ulastirma', 'ulastirma endeksi']) }),
  Object.freeze({ symbol: 'XELEK', name: 'BIST Elektrik Endeksi', aliases: Object.freeze(['xelek', 'bist elektrik', 'elektrik endeksi']) }),
  Object.freeze({ symbol: 'XKMYA', name: 'BIST Kimya, Petrol, Plastik Endeksi', aliases: Object.freeze(['xkmya', 'bist kimya petrol plastik', 'kimya petrol plastik endeksi']) }),
  Object.freeze({ symbol: 'XMANA', name: 'BIST Metal Ana Endeksi', aliases: Object.freeze(['xmana', 'bist metal ana', 'metal ana endeksi']) }),
  Object.freeze({ symbol: 'XMESY', name: 'BIST Metal Esya, Makine Endeksi', aliases: Object.freeze(['xmesy', 'bist metal esya makine', 'metal esya makine endeksi']) }),
  Object.freeze({ symbol: 'XINSA', name: 'BIST Insaat Endeksi', aliases: Object.freeze(['xinsa', 'bist insaat', 'insaat endeksi']) }),
  Object.freeze({ symbol: 'XGMYO', name: 'BIST Gayrimenkul Yatirim Ortakliklari Endeksi', aliases: Object.freeze(['xgmyo', 'bist gmyo', 'bist gayrimenkul yatirim ortakliklari', 'gmyo endeksi']) }),
  Object.freeze({ symbol: 'XHOLD', name: 'BIST Holding ve Yatirim Endeksi', aliases: Object.freeze(['xhold', 'bist holding yatirim', 'holding yatirim endeksi']) }),
  Object.freeze({ symbol: 'XSGRT', name: 'BIST Sigorta Endeksi', aliases: Object.freeze(['xsgrt', 'bist sigorta', 'sigorta endeksi']) }),
  Object.freeze({ symbol: 'XFINK', name: 'BIST Finansal Kiralama, Faktoring Endeksi', aliases: Object.freeze(['xfink', 'bist finansal kiralama faktoring', 'finansal kiralama faktoring endeksi']) }),
  Object.freeze({ symbol: 'XSPOR', name: 'BIST Spor Endeksi', aliases: Object.freeze(['xspor', 'bist spor', 'spor endeksi']) }),
  Object.freeze({ symbol: 'XTEKS', name: 'BIST Tekstil, Deri Endeksi', aliases: Object.freeze(['xteks', 'bist tekstil deri', 'tekstil deri endeksi']) }),
  Object.freeze({ symbol: 'XKAGT', name: 'BIST Orman, Kagit, Basim Endeksi', aliases: Object.freeze(['xkagt', 'bist orman kagit basim', 'orman kagit basim endeksi']) }),
  Object.freeze({ symbol: 'XTAST', name: 'BIST Tas, Toprak Endeksi', aliases: Object.freeze(['xtast', 'bist tas toprak', 'tas toprak endeksi']) }),
  Object.freeze({ symbol: 'XMADN', name: 'BIST Madencilik Endeksi', aliases: Object.freeze(['xmadn', 'bist madencilik', 'madencilik endeksi']) })
]);

function buildFxAsset({ base, quote = 'TRY', name, aliases, yahoo = null }) {
  const symbol = base + quote;
  return Object.freeze({
    internalAssetId: 'fx:' + symbol,
    canonicalSymbol: symbol,
    displayName: name,
    normalizedName: normalizeName(name),
    assetType: 'fx',
    exchange: null,
    market: 'FX',
    currency: quote,
    providerSymbols: Object.freeze({ yahoo }),
    aliases: uniqueAliases([symbol, base + '/' + quote, base + ' ' + quote, name, normalizeName(name), ...(aliases || [])]),
    searchTerms: Object.freeze([]),
    isActive: true,
    metadataUpdatedAt: null
  });
}

const FX_CURRENCY_ROWS = Object.freeze([
  Object.freeze({ base: 'USD', name: 'USD/TRY', yahoo: 'TRY=X', aliases: Object.freeze(['dolar', 'dolar tl', 'dolar kuru', 'amerikan dolari', 'amerikan dolari tl']) }),
  Object.freeze({ base: 'EUR', name: 'EUR/TRY', aliases: Object.freeze(['euro tl', 'euro kuru', 'avro tl', 'avro kuru']) }),
  Object.freeze({ base: 'GBP', name: 'GBP/TRY', aliases: Object.freeze(['sterlin tl', 'sterlin kuru', 'ingiliz sterlini', 'ingiliz sterlini tl']) }),
  Object.freeze({ base: 'CHF', name: 'CHF/TRY', aliases: Object.freeze(['isvicre frangi tl', 'frank tl', 'isvicre franki tl']) }),
  Object.freeze({ base: 'JPY', name: 'JPY/TRY', aliases: Object.freeze(['japon yeni tl', 'yen tl']) }),
  Object.freeze({ base: 'CAD', name: 'CAD/TRY', aliases: Object.freeze(['kanada dolari tl', 'kanada dolari kuru']) }),
  Object.freeze({ base: 'AUD', name: 'AUD/TRY', aliases: Object.freeze(['avustralya dolari tl', 'avustralya dolari kuru']) }),
  Object.freeze({ base: 'NZD', name: 'NZD/TRY', aliases: Object.freeze(['yeni zelanda dolari tl', 'yeni zelanda dolari kuru']) }),
  Object.freeze({ base: 'CNY', name: 'CNY/TRY', aliases: Object.freeze(['cin yuani tl', 'yuan tl']) }),
  Object.freeze({ base: 'RUB', name: 'RUB/TRY', aliases: Object.freeze(['rus rublesi tl', 'ruble tl']) }),
  Object.freeze({ base: 'SAR', name: 'SAR/TRY', aliases: Object.freeze(['suudi arabistan riyali tl', 'riyal tl']) }),
  Object.freeze({ base: 'AED', name: 'AED/TRY', aliases: Object.freeze(['bae dirhemi tl', 'dubai dirhemi', 'dirhem tl']) }),
  Object.freeze({ base: 'QAR', name: 'QAR/TRY', aliases: Object.freeze(['katar riyali tl', 'katar riyali kuru']) }),
  Object.freeze({ base: 'KWD', name: 'KWD/TRY', aliases: Object.freeze(['kuveyt dinari tl', 'kuveyt dinari kuru']) }),
  Object.freeze({ base: 'NOK', name: 'NOK/TRY', aliases: Object.freeze(['norvec kronu tl', 'norvec kronu kuru']) }),
  Object.freeze({ base: 'SEK', name: 'SEK/TRY', aliases: Object.freeze(['isvec kronu tl', 'isvec kronu kuru']) }),
  Object.freeze({ base: 'DKK', name: 'DKK/TRY', aliases: Object.freeze(['danimarka kronu tl', 'danimarka kronu kuru']) })
]);

function buildCommodityAsset({ group, symbol, name, currency, aliases, yahoo = null }) {
  return Object.freeze({
    internalAssetId: 'commodity:' + group + ':' + symbol,
    canonicalSymbol: symbol,
    displayName: name,
    normalizedName: normalizeName(name),
    assetType: 'commodity',
    exchange: null,
    market: 'COMMODITY',
    currency,
    providerSymbols: Object.freeze({ yahoo }),
    aliases: uniqueAliases([symbol, name, normalizeName(name), ...(aliases || [])]),
    searchTerms: Object.freeze([]),
    isActive: true,
    metadataUpdatedAt: null
  });
}

const COMMODITY_ROWS = Object.freeze([
  Object.freeze({ group: 'gold', symbol: 'XAUUSD', name: 'Ons Altin', currency: 'USD', yahoo: 'XAUUSD=X', aliases: Object.freeze(['ons altin', 'altin ons', 'xauusd', 'xau/usd', 'spot altin', 'uluslararasi altin']) }),
  Object.freeze({ group: 'gold', symbol: 'GRAM_ALTIN', name: '24 Ayar Gram Altin', currency: 'TRY', aliases: Object.freeze(['altin', 'gram altin', 'gramaltin', 'altin gram', 'gram altin fiyati', '1 gram altin', '24 ayar gram altin', 'gram']) }),
  Object.freeze({ group: 'silver', symbol: 'XAGUSD', name: 'Ons Gumus', currency: 'USD', yahoo: 'XAGUSD=X', aliases: Object.freeze(['ons gumus', 'gumus ons', 'xagusd', 'xag/usd', 'spot gumus']) }),
  Object.freeze({ group: 'silver', symbol: 'GRAM_GUMUS', name: 'Gram Gumus', currency: 'TRY', aliases: Object.freeze(['gumus', 'gram gumus', 'gramgumus', 'gumus gram']) }),
  Object.freeze({ group: 'platinum', symbol: 'XPTUSD', name: 'Platin', currency: 'USD', aliases: Object.freeze(['platin', 'platin ons', 'xptusd', 'xpt/usd']) }),
  Object.freeze({ group: 'palladium', symbol: 'XPDUSD', name: 'Paladyum', currency: 'USD', aliases: Object.freeze(['paladyum', 'paladyum ons', 'xpdusd', 'xpd/usd']) }),
  Object.freeze({ group: 'energy', symbol: 'BRENT', name: 'Brent Petrol', currency: 'USD', aliases: Object.freeze(['brent', 'brent petrol', 'brent ham petrol']) }),
  Object.freeze({ group: 'energy', symbol: 'WTI', name: 'WTI Ham Petrol', currency: 'USD', aliases: Object.freeze(['wti', 'wti petrol', 'wti ham petrol', 'amerikan ham petrol']) }),
  Object.freeze({ group: 'energy', symbol: 'NATGAS', name: 'Dogal Gaz', currency: 'USD', aliases: Object.freeze(['dogal gaz', 'dogalgaz', 'natural gas', 'natgas']) }),
  Object.freeze({ group: 'industrial', symbol: 'COPPER', name: 'Bakir', currency: 'USD', aliases: Object.freeze(['bakir fiyati', 'bakir emtiasi', 'copper']) }),
  Object.freeze({ group: 'industrial', symbol: 'ALUMINUM', name: 'Aluminyum', currency: 'USD', aliases: Object.freeze(['aluminyum', 'aluminyum fiyati', 'aluminum']) }),
  Object.freeze({ group: 'industrial', symbol: 'ZINC', name: 'Cinko', currency: 'USD', aliases: Object.freeze(['cinko', 'cinko fiyati', 'zinc']) }),
  Object.freeze({ group: 'industrial', symbol: 'NICKEL', name: 'Nikel', currency: 'USD', aliases: Object.freeze(['nikel', 'nikel fiyati', 'nickel']) }),
  Object.freeze({ group: 'industrial', symbol: 'LEAD', name: 'Kursun', currency: 'USD', aliases: Object.freeze(['kursun', 'kursun fiyati', 'lead']) }),
  Object.freeze({ group: 'industrial', symbol: 'IRONORE', name: 'Demir Cevheri', currency: 'USD', aliases: Object.freeze(['demir cevheri', 'iron ore']) }),
  Object.freeze({ group: 'agriculture', symbol: 'WHEAT', name: 'Bugday', currency: 'USD', aliases: Object.freeze(['bugday', 'bugday fiyati', 'wheat']) }),
  Object.freeze({ group: 'agriculture', symbol: 'CORN', name: 'Misir', currency: 'USD', aliases: Object.freeze(['misir', 'misir fiyati', 'corn']) }),
  Object.freeze({ group: 'agriculture', symbol: 'COTTON', name: 'Pamuk', currency: 'USD', aliases: Object.freeze(['pamuk', 'pamuk fiyati', 'cotton']) }),
  Object.freeze({ group: 'agriculture', symbol: 'COFFEE', name: 'Kahve', currency: 'USD', aliases: Object.freeze(['kahve', 'kahve fiyati', 'coffee']) }),
  Object.freeze({ group: 'agriculture', symbol: 'COCOA', name: 'Kakao', currency: 'USD', aliases: Object.freeze(['kakao', 'kakao fiyati', 'cocoa']) }),
  Object.freeze({ group: 'agriculture', symbol: 'SUGAR', name: 'Seker', currency: 'USD', aliases: Object.freeze(['seker', 'seker fiyati', 'sugar']) })
]);

const NON_EQUITY_ASSETS = Object.freeze([
  ...BIST_INDEX_ROWS.map(buildIndexAsset),
  Object.freeze({
    internalAssetId: 'bist:certificate:ALTIN.S1', canonicalSymbol: 'ALTIN.S1', displayName: 'Darphane Altin Sertifikasi', normalizedName: 'darphane altin sertifikasi', assetType: 'certificate', exchange: 'BIST', market: 'BIST', currency: 'TRY', providerSymbols: Object.freeze({ yahoo: 'ALTIN.S1.IS' }), aliases: Object.freeze(['altin.s1', 'altin s1', 'altins1', 'darphane altin sertifikasi']), searchTerms: Object.freeze([]), isActive: true, metadataUpdatedAt: null
  }),
  ...COMMODITY_ROWS.map(buildCommodityAsset),
  ...FX_CURRENCY_ROWS.map(buildFxAsset)
]);

const ASSET_CATALOG = Object.freeze([...BIST_EQUITY_ROWS.map(buildEquityAsset), ...NON_EQUITY_ASSETS, ...TEFAS_FUND_ROWS.map(buildTefasFundAsset)]);

function cloneAsset(asset) {
  return { ...asset, providerSymbols: { ...(asset.providerSymbols || {}) }, aliases: [...(asset.aliases || [])], searchTerms: [...(asset.searchTerms || [])] };
}

function getAssetCatalog() {
  return ASSET_CATALOG.map(cloneAsset);
}

module.exports = { ASSET_CATALOG, getAssetCatalog };
