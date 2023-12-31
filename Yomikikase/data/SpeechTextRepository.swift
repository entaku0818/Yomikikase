//
//  SpeechTextRepository.swift
//  Yomikikase
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

    func fetchAllSpeechText() -> [Speeches.Speech] {
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
            let greetings = createGreetingSpeeches()
            speeches.append(contentsOf: greetings)

            return speeches
        } catch let error as NSError {
            print("FetchRequest error: \(error), \(error.userInfo)")
            return []
        }
    }


    private func createGreetingSpeeches() -> [Speeches.Speech] {
        let greetings = [
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
