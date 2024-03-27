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
    }

    override init() {

        container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores(completionHandler: { (_, error) in
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
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func insert(text:String) {
        if let speechText = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? SpeechText {

            speechText.uuid = UUID()
            speechText.text = text
            speechText.createdAt = Date()
            speechText.updatedAt = Date()


            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func fetchAllSpeechText(language: LanguageSetting) -> [Speeches.Speech] {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let coreDataSpeechTexts = try managedContext.fetch(fetchRequest)

            // SpeechTextからSpeeches.Speechに変換
            var speeches = coreDataSpeechTexts.map { speechText in
                Speeches.Speech(
                    id: speechText.uuid ?? UUID(),
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




    private func createGreetingSpeeches(language: LanguageSetting) -> [Speeches.Speech] {
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
                "よろしくお願いします",
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
                "Please treat me well",
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
                "Bitte behandle mich gut",
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
                "Por favor, trátame bien",
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
                "Lütfen beni iyi tedavi et",
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
                "S'il vous plaît, traitez-moi bien",
            ]
        }


        return greetings.map { greeting in
            createDefaultSpeech(text: greeting)
        }
    }



    private func createDefaultSpeech(text: String) -> Speeches.Speech {
        return Speeches.Speech(
            id: UUID(),
            text: text,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

}
