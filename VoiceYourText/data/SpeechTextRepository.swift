//
//  SpeechTextRepository.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 25.11.2023.
//
import Foundation
import CoreData

class SpeechTextRepository: NSObject {

    static let shared = SpeechTextRepository()

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    let entityName: String = "SpeechText"

    enum LanguageSetting: String {
        case japanese = "ja"
        case english = "en"
        case german = "de"
        case spanish = "es"
        case turkish = "tr"
        case french = "fr"
        case vietnamese = "vi"
        case thai = "th"
        case korean = "ko"
        case italian = "it"
    }

    override init() {

        container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func insert(title: String, text: String, languageSetting: LanguageSetting) {
        if let speechText = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? SpeechText {

            speechText.uuid = UUID()
            speechText.title = title
            speechText.text = text
            speechText.languageSetting = languageSetting.rawValue
            speechText.createdAt = Date()
            speechText.updatedAt = Date()

            do {
                try managedContext.save()
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func fetchAllSpeechText(language: LanguageSetting) -> [Speeches.Speech] {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "languageSetting == %@", language.rawValue)
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let coreDataSpeechTexts = try managedContext.fetch(fetchRequest)

            // SpeechTextからSpeeches.Speechに変換
            var speeches = coreDataSpeechTexts.map { speechText in
                Speeches.Speech(
                    id: speechText.uuid ?? UUID(), title: speechText.title ?? "",
                    text: speechText.text ?? "",
                    createdAt: speechText.createdAt ?? Date(),
                    updatedAt: speechText.updatedAt ?? Date()
                )
            }

            // デフォルトの挨拶を追加
            let greetings = createGreetingSpeeches(language: language)
            speeches.append(contentsOf: greetings)

            return speeches
        } catch let error as NSError {
            print("FetchRequest error: \(error), \(error.userInfo)")
            return []
        }
    }

    func createGreetingSpeeches(language: LanguageSetting) -> [Speeches.Speech] {
        let greetings: [String]
        switch language {
        case .japanese:
            greetings = [
                "こんにちは",
                "こんばんは",
                "おやすみなさい",
                "いってきます",
                "ただいま",
                "いただきます",
                "ごちそうさまでした",
                "ありがとうございます",
                "すみません",
                "よろしくお願いします"
            ]
        case .english:
            greetings = [
                "Hello",
                "Good evening",
                "Good night",
                "I'm leaving",
                "I'm home",
                "Let's eat",
                "Thank you for the meal",
                "Thank you",
                "Excuse me",
                "Please treat me well"
            ]
        case .german:
            greetings = [
                "Hallo",
                "Guten Abend",
                "Gute Nacht",
                "Ich gehe",
                "Ich bin zu Hause",
                "Lass uns essen",
                "Danke für das Essen",
                "Danke",
                "Entschuldigung",
                "Bitte behandle mich gut"
            ]
        case .spanish:
            greetings = [
                "Hola",
                "Buenas noches",
                "Buenas noches",
                "Me estoy yendo",
                "Ya llegué a casa",
                "Vamos a comer",
                "Gracias por la comida",
                "Gracias",
                "Disculpe",
                "Por favor, trátame bien"
            ]
        case .turkish:
            greetings = [
                "Merhaba",
                "İyi akşamlar",
                "İyi geceler",
                "Gidiyorum",
                "Eve geldim",
                "Hadi yemek yiyelim",
                "Yemeğin için teşekkür ederim",
                "Teşekkür ederim",
                "Affedersiniz",
                "Lütfen beni iyi tedavi et"
            ]
        case .french:
            greetings = [
                "Bonjour",
                "Bonsoir",
                "Bonne nuit",
                "Je pars",
                "Je suis à la maison",
                "Mangeons",
                "Merci pour le repas",
                "Merci",
                "Excusez-moi",
                "S'il vous plaît, traitez-moi bien"
            ]
        case .vietnamese:
            greetings = [
                "Xin chào", // Hello
                "Chào buổi tối", // Good evening
                "Chúc ngủ ngon", // Good night
                "Tôi đi đây", // I'm leaving
                "Tôi về", // I'm home
                "Ăn thôi", // Let's eat
                "Cảm ơn bữa ăn", // Thank you for the meal
                "Cảm ơn", // Thank you
                "Xin lỗi", // Excuse me
                "Xin hãy đối xử tốt với tôi" // Please treat me well
            ]
        case .thai:
            greetings = [
                "สวัสดี", // Hello
                "สวัสดีตอนเย็น", // Good evening
                "ราตรีสวัสดิ์", // Good night
                "ฉันกำลังจะไป", // I'm leaving
                "ฉันกลับถึงบ้านแล้ว", // I'm home
                "มากินกันเถอะ", // Let's eat
                "ขอบคุณสำหรับอาหาร", // Thank you for the meal
                "ขอบคุณ", // Thank you
                "ขอโทษ", // Excuse me
                "โปรดดูแลฉันด้วยนะ" // Please treat me well
            ]
        case .korean:
            greetings = [
                "안녕하세요", // Hello
                "안녕하세요", // Good evening (same as Hello)
                "안녕히 주무세요", // Good night
                "잘 가요", // I'm leaving
                "집에 돌아왔어요", // I'm home
                "식사합시다", // Let's eat
                "식사를 잘 했습니다", // Thank you for the meal
                "감사합니다", // Thank you
                "실례합니다", // Excuse me
                "잘 부탁드립니다" // Please treat me well
            ]
        case .italian:
            greetings = [
                "Ciao", // Hello
                "Buonasera", // Good evening
                "Buonanotte", // Good night
                "Sto andando", // I'm leaving
                "Sono a casa", // I'm home
                "Mangiamo", // Let's eat
                "Grazie per il pasto", // Thank you for the meal
                "Grazie", // Thank you
                "Scusami", // Excuse me
                "Per favore, trattami bene" // Please treat me well
            ]
        }

        return greetings.map { greeting in
            createDefaultSpeech(text: greeting)
        }
    }

    private func createDefaultSpeech(text: String) -> Speeches.Speech {
        Speeches.Speech(
            id: UUID(), title: text,
            text: text,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func delete(id: UUID) {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)
        
        do {
            let fetchedItems = try managedContext.fetch(fetchRequest)
            if let itemToDelete = fetchedItems.first {
                managedContext.delete(itemToDelete)
                try managedContext.save()
            }
        } catch {
            print("Delete error: \(error.localizedDescription)")
        }
    }

}
