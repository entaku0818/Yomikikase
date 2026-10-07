//
//  ScreenshotDemoContent+Locales.swift
//  VoiceYourText
//
//  App Store スクリーンショット用のデモデータ（ja/en 以外の8言語）。DEBUG ビルドのみ。
//  名作の冒頭はパブリックドメイン。ko/th/tr/vi の一部は撮影用に書いた文章。
//

#if DEBUG
import Foundation

extension ScreenshotDemoContent {
    static let de = ScreenshotDemoContent(
        texts: [
            Item(
                title: "Die Verwandlung",
                text: [
                    "Als Gregor Samsa eines Morgens aus unruhigen Träumen erwachte, fand er sich in seinem ",
                    "Bett zu einem ungeheueren Ungeziefer verwandelt. Er lag auf seinem panzerartig harten ",
                    "Rücken und sah, wenn er den Kopf ein wenig hob, seinen gewölbten, braunen, von ",
                    "bogenförmigen Versteifungen geteilten Bauch, auf dessen Höhe sich die Bettdecke, zum ",
                    "gänzlichen Niedergleiten bereit, kaum noch erhalten konnte. Seine vielen, im Vergleich zu ",
                    "seinem sonstigen Umfang kläglich dünnen Beine flimmerten ihm hilflos vor den ",
                    "Augen.\n\n»Was ist mit mir geschehen?«, dachte er. Es war kein Traum. Sein Zimmer, ein ",
                    "richtiges, nur etwas zu kleines Menschenzimmer, lag ruhig zwischen den vier wohlbekannten ",
                    "Wänden."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "Notizen zum Team-Meeting",
                text: [
                    "Wir haben die offenen Aufgaben für das Release nächste Woche besprochen. Das Design wird ",
                    "am Dienstag abgenommen, getestet wird von Mittwoch bis Freitag."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Grimms Märchen",
                text: [
                    "Es war einmal ein kleines süßes Mädchen, das hatte jedermann lieb, der sie nur ansah, am ",
                    "allerliebsten aber ihre Großmutter."
                ].joined(),
                fileType: "epub"
            )
        ],
        pdf: PDF(
            fileName: "Schlaf und Konzentration.pdf",
            title: "Schlaf und Konzentration",
            body: [
                "Nach einer erholsamen Nacht bleiben wir bei der Arbeit länger konzentriert. Dieser ",
                "Bericht hat drei Monate lang Schlaf und Leistung am Tag verglichen."
            ].joined()
        ),
        dictionary: [
            ("SQL", "Sequel"),
            ("GIF", "Dschiff"),
            ("iOS", "ei-o-es"),
            ("Nguyen", "Wien"),
            ("Chiemsee", "Kiemsee")
        ]
    )

    static let es = ScreenshotDemoContent(
        texts: [
            Item(
                title: "Don Quijote de la Mancha",
                text: [
                    "En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que ",
                    "vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo ",
                    "corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y ",
                    "quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, ",
                    "consumían las tres partes de su hacienda.\n\nEl resto della concluían sayo de velarte, ",
                    "calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de ",
                    "entresemana se honraba con su vellorí de lo más fino."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "Notas de la reunión",
                text: [
                    "Repasamos las tareas pendientes para el lanzamiento de la próxima semana. El diseño se ",
                    "aprueba el martes y las pruebas van de miércoles a viernes."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Platero y yo",
                text: [
                    "Platero es pequeño, peludo, suave; tan blando por fuera, que se diría todo de algodón, ",
                    "que no lleva huesos."
                ].joined(),
                fileType: "epub"
            )
        ],
        pdf: PDF(
            fileName: "Sueño y concentración.pdf",
            title: "Sueño y concentración",
            body: [
                "Después de dormir bien, mantenemos la concentración durante más tiempo. Este informe ",
                "compara el sueño y el rendimiento diario durante tres meses."
            ].joined()
        ),
        dictionary: [
            ("SQL", "sicuel"),
            ("GIF", "yif"),
            ("Wi-Fi", "uaifai"),
            ("iOS", "ai o es"),
            ("Nguyen", "uin")
        ]
    )

    static let fr = ScreenshotDemoContent(
        texts: [
            Item(
                title: "Du côté de chez Swann",
                text: [
                    "Longtemps, je me suis couché de bonne heure. Parfois, à peine ma bougie éteinte, mes yeux ",
                    "se fermaient si vite que je n'avais pas le temps de me dire : « Je m'endors. » Et, une ",
                    "demi-heure après, la pensée qu'il était temps de chercher le sommeil m'éveillait ; je ",
                    "voulais poser le volume que je croyais avoir encore dans les mains et souffler ma ",
                    "lumière.\n\nJe n'avais pas cessé en dormant de faire des réflexions sur ce que je venais ",
                    "de lire, mais ces réflexions avaient pris un tour un peu particulier."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "Notes de réunion",
                text: [
                    "Nous avons passé en revue les tâches restantes avant la sortie de la semaine prochaine. ",
                    "Le design est validé mardi, les tests ont lieu du mercredi au vendredi."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Les Misérables",
                text: [
                    "En 1815, M. Charles-François-Bienvenu Myriel était évêque de Digne. C'était un vieillard ",
                    "d'environ soixante-quinze ans."
                ].joined(),
                fileType: "epub"
            )
        ],
        pdf: PDF(
            fileName: "Sommeil et concentration.pdf",
            title: "Sommeil et concentration",
            body: [
                "Après une bonne nuit, nous restons concentrés plus longtemps. Ce rapport compare le ",
                "sommeil et les performances de la journée pendant trois mois."
            ].joined()
        ),
        dictionary: [
            ("SQL", "sikouel"),
            ("GIF", "djif"),
            ("Wi-Fi", "oui-fi"),
            ("iOS", "aï o èss"),
            ("Nguyen", "nouyèn")
        ]
    )

    static let it = ScreenshotDemoContent(
        texts: [
            Item(
                title: "Le avventure di Pinocchio",
                text: [
                    "C'era una volta... — Un re! — diranno subito i miei piccoli lettori. No, ragazzi, avete ",
                    "sbagliato. C'era una volta un pezzo di legno. Non era un legno di lusso, ma un semplice ",
                    "pezzo da catasta, di quelli che d'inverno si mettono nelle stufe e nei caminetti per ",
                    "accendere il fuoco e per riscaldare le stanze.\n\nNon so come andasse, ma il fatto gli è ",
                    "che un bel giorno questo pezzo di legno capitò nella bottega di un vecchio falegname, il ",
                    "quale aveva nome mastr'Antonio."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "Appunti della riunione",
                text: [
                    "Abbiamo rivisto le attività rimaste per il rilascio della prossima settimana. Il design ",
                    "si approva martedì, i test vanno da mercoledì a venerdì."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "I promessi sposi",
                text: [
                    "Quel ramo del lago di Como, che volge a mezzogiorno, tra due catene non interrotte di ",
                    "monti, tutto a seni e a golfi."
                ].joined(),
                fileType: "epub"
            )
        ],
        pdf: PDF(
            fileName: "Sonno e concentrazione.pdf",
            title: "Sonno e concentrazione",
            body: [
                "Dopo una buona notte di sonno restiamo concentrati più a lungo. Questo rapporto confronta ",
                "sonno e rendimento quotidiano per tre mesi."
            ].joined()
        ),
        dictionary: [
            ("SQL", "siquel"),
            ("GIF", "gif"),
            ("Wi-Fi", "uai-fai"),
            ("iOS", "ai o es"),
            ("Nguyen", "nuien")
        ]
    )

    static let ko = ScreenshotDemoContent(
        texts: [
            Item(
                title: "서시",
                text: [
                    "죽는 날까지 하늘을 우러러 한 점 부끄럼이 없기를, 잎새에 이는 바람에도 나는 괴로워했다. 별을 노래하는 마음으로 모든 죽어가는 것을 사랑해야지. 그리고 나한테 ",
                    "주어진 길을 걸어가야겠다. 오늘 밤에도 별이 바람에 스치운다.\n\n계절이 지나가는 하늘에는 가을로 가득 차 있습니다. 나는 아무 걱정도 없이 가을 속의 별들을 ",
                    "다 헤일 듯합니다. 가슴 속에 하나 둘 새겨지는 별을 이제 다 못 헤는 것은 쉬이 아침이 오는 까닭이요, 내일 밤이 남은 까닭이요, 아직 나의 청춘이 다하지 ",
                    "않은 까닭입니다."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "회의 메모",
                text: "다음 주 출시를 앞두고 남은 작업을 확인했습니다. 디자인 확인은 화요일, 테스트는 수요일부터 금요일까지 진행합니다.",
                fileType: nil
            ),
            Item(
                title: "출근길에 듣는 뉴스",
                text: "오늘은 전국이 대체로 맑겠고, 낮 기온은 어제보다 조금 높겠습니다. 출근길에는 가벼운 겉옷을 챙기세요.",
                fileType: nil
            )
        ],
        pdf: PDF(
            fileName: "수면과 집중력 보고서.pdf",
            title: "수면과 집중력 보고서",
            body: "잠을 잘 잔 날에는 일이나 공부에 더 오래 집중할 수 있습니다. 이 보고서는 석 달 동안 수면 시간과 낮의 작업 효율을 비교했습니다."
        ),
        dictionary: [
            ("SQL", "시퀄"),
            ("GIF", "지프"),
            ("iOS", "아이오에스"),
            ("Kubernetes", "쿠버네티스"),
            ("ChatGPT", "챗지피티")
        ]
    )

    static let th = ScreenshotDemoContent(
        texts: [
            Item(
                title: "ฟังระหว่างเดินทาง",
                text: [
                    "ทุกเช้าฉันนั่งรถไฟฟ้าไปทำงานประมาณสี่สิบนาที ช่วงเวลานี้เคยหมดไปกับการเลื่อนดูโทรศัพท์ ",
                    "แต่ตอนนี้ฉันใช้มันฟังบทความและหนังสือแทน แค่เปิดแอปแล้วกดเล่น ",
                    "เสียงก็จะอ่านข้อความให้ฟังทีละประโยค ",
                    "ฉันจึงได้พักสายตาไปพร้อมกับได้ความรู้ใหม่ๆ\n\nตอนเย็นระหว่างทำอาหาร ",
                    "ฉันก็ฟังต่อจากที่ค้างไว้ได้ทันที และก่อนนอนก็ตั้งเวลาให้หยุดเองเมื่อครบสามสิบนาที ",
                    "การฟังแทนการอ่านทำให้ฉันอ่านหนังสือจบได้มากขึ้นกว่าเดิมหลายเล่ม"
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "บันทึกการประชุม",
                text: [
                    "เราได้ทบทวนงานที่เหลือก่อนเปิดตัวสัปดาห์หน้า ตรวจงานออกแบบวันอังคาร ",
                    "และทดสอบตั้งแต่วันพุธถึงวันศุกร์"
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "ข่าวเช้าวันนี้",
                text: "วันนี้อากาศแจ่มใสเกือบทั่วประเทศ อุณหภูมิช่วงกลางวันสูงขึ้นเล็กน้อย",
                fileType: nil
            )
        ],
        pdf: PDF(
            fileName: "รายงานการนอนหลับ.pdf",
            title: "การนอนหลับกับสมาธิ",
            body: [
                "วันที่นอนหลับเพียงพอ เราจะมีสมาธิกับงานได้นานขึ้น ",
                "รายงานนี้เปรียบเทียบการนอนกับประสิทธิภาพการทำงานตลอดสามเดือน"
            ].joined()
        ),
        dictionary: [
            ("SQL", "ซีเควล"),
            ("GIF", "จิฟ"),
            ("iOS", "ไอโอเอส"),
            ("Kubernetes", "คูเบอร์เนทีส"),
            ("ChatGPT", "แชตจีพีที")
        ]
    )

    static let tr = ScreenshotDemoContent(
        texts: [
            Item(
                title: "Yolda Dinlemek",
                text: [
                    "Her sabah işe giderken metroda yaklaşık kırk dakika geçiriyorum. Eskiden bu zamanı ",
                    "telefonda gezinerek harcıyordum, şimdi ise makale ve kitap dinliyorum. Uygulamayı açıp ",
                    "oynat tuşuna basmam yeterli; metin cümle cümle sesli okunuyor. Böylece hem gözlerimi ",
                    "dinlendiriyor hem de yeni şeyler öğreniyorum.\n\nAkşam yemek yaparken kaldığım yerden ",
                    "devam ediyorum. Yatmadan önce de zamanlayıcıyı otuz dakikaya kuruyorum. Okumak yerine ",
                    "dinlemeye başladığımdan beri çok daha fazla kitap bitirdim."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Toplantı notları",
                text: [
                    "Gelecek haftaki sürüm için kalan işleri gözden geçirdik. Tasarım onayı salı günü, testler ",
                    "çarşambadan cumaya kadar."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Sabah haberleri",
                text: "Bugün yurdun büyük bölümünde hava açık olacak, gündüz sıcaklıkları biraz artacak.",
                fileType: nil
            )
        ],
        pdf: PDF(
            fileName: "Uyku ve odaklanma.pdf",
            title: "Uyku ve Odaklanma",
            body: [
                "İyi uyuduğumuz günlerde işe daha uzun süre odaklanabiliyoruz. Bu rapor üç ay boyunca uyku ",
                "ile gündüz verimliliğini karşılaştırdı."
            ].joined()
        ),
        dictionary: [
            ("SQL", "sikuel"),
            ("GIF", "cif"),
            ("iOS", "ay o es"),
            ("Wi-Fi", "vay fay"),
            ("Nguyen", "nuyen")
        ]
    )

    static let vi = ScreenshotDemoContent(
        texts: [
            Item(
                title: "Truyện Kiều",
                text: [
                    "Trăm năm trong cõi người ta, chữ tài chữ mệnh khéo là ghét nhau. Trải qua một cuộc bể ",
                    "dâu, những điều trông thấy mà đau đớn lòng. Lạ gì bỉ sắc tư phong, trời xanh quen thói má ",
                    "hồng đánh ghen.\n\nMỗi sáng trên đường đi làm, tôi nghe lại những câu thơ này thay vì ",
                    "nhìn màn hình điện thoại. Chỉ cần mở ứng dụng và bấm phát, từng câu được đọc lên rõ ràng, ",
                    "giúp đôi mắt được nghỉ ngơi mà vẫn tiếp tục đọc sách mỗi ngày."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "Ghi chú cuộc họp",
                text: [
                    "Chúng tôi đã rà soát các việc còn lại trước khi phát hành tuần sau. Duyệt thiết kế vào ",
                    "thứ Ba, kiểm thử từ thứ Tư đến thứ Sáu."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Tin tức buổi sáng",
                text: "Hôm nay trời nắng ráo trên cả nước, nhiệt độ ban ngày tăng nhẹ so với hôm qua.",
                fileType: nil
            )
        ],
        pdf: PDF(
            fileName: "Giấc ngủ và sự tập trung.pdf",
            title: "Giấc ngủ và sự tập trung",
            body: [
                "Sau một đêm ngủ ngon, chúng ta tập trung được lâu hơn. Báo cáo này so sánh giấc ngủ và ",
                "hiệu suất làm việc trong ba tháng."
            ].joined()
        ),
        dictionary: [
            ("SQL", "si-quen"),
            ("GIF", "jíp"),
            ("iOS", "ai-ô-ét"),
            ("Wi-Fi", "oai-phai"),
            ("ChatGPT", "chát-gi-pi-ti")
        ]
    )
}
#endif
