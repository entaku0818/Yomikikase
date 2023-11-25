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

        // 作成日順にソートするためのソート記述子を作成
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let coreDataSpeechTexts = try managedContext.fetch(fetchRequest)

            // 結果が空の場合はデフォルト値を追加
            if coreDataSpeechTexts.isEmpty {
                return createGreetingSpeeches()
            }

            // SpeechTextからSpeeches.Speechに変換
            return coreDataSpeechTexts.map { speechText in
                Speeches.Speech(
                    id: speechText.uuid ?? UUID(),
                    text: speechText.text ?? "",
                    createdAt: speechText.createdAt ?? Date(),
                    updatedAt: speechText.updatedAt ?? Date()
                )
            }
        } catch let error {
            print(error.localizedDescription)
            return createGreetingSpeeches()
        }
    }


    private func createGreetingSpeeches() -> [Speeches.Speech] {
        let greetings = [
            "おはようございます",
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
            "こんにちは、いい天気ですね",
            "今日は寒いですね",
            "暑い日が続きますね",
            "良い一日を",
            "元気ですか",
            "最近どうですか",
            "久しぶりですね",
            "お元気そうで何よりです",
            "お疲れさまです",
            "いい週末を",
            "気をつけて",
            "頑張ってください",
            "お大事に",
            "忙しいですか",
            "早く良くなりますように",
            "ご無沙汰しています",
            "おめでとうございます",
            "残念ですね",
            "それは良かった"
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
