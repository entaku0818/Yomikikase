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

    @discardableResult
    func insert(title: String, text: String, languageSetting: LanguageSetting, fileType: String? = nil, imagePath: String? = nil, ttsMode: String? = nil) -> UUID {
        let newUUID = UUID()
        if let speechText = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? SpeechText {

            speechText.uuid = newUUID
            speechText.title = title
            speechText.text = text
            speechText.languageSetting = languageSetting.rawValue
            speechText.fileType = fileType
            speechText.imagePath = imagePath
            speechText.ttsMode = ttsMode
            speechText.createdAt = Date()
            speechText.updatedAt = Date()

            do {
                try managedContext.save()
            } catch {
                errorLog(error.localizedDescription)
            }
        }
        return newUUID
    }

    func fetchAllSpeechText(language: LanguageSetting) -> [Speeches.Speech] {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        // 削除されていないアイテムのみ取得（言語フィルタなし - 全言語統一）
        fetchRequest.predicate = NSPredicate(format: "deletedAt == nil")
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let coreDataSpeechTexts = try managedContext.fetch(fetchRequest)

            // SpeechTextからSpeeches.Speechに変換
            let speeches = coreDataSpeechTexts.map { speechText in
                Speeches.Speech(
                    id: speechText.uuid ?? UUID(), title: speechText.title ?? "",
                    text: speechText.text ?? "", isDefault: false,
                    createdAt: speechText.createdAt ?? Date(),
                    updatedAt: speechText.updatedAt ?? Date(),
                    fileType: speechText.fileType,
                    imagePath: speechText.imagePath
                )
            }

            return speeches
        } catch let error as NSError {
            errorLog("FetchRequest error: \(error), \(error.userInfo)")
            return []
        }
    }

    func fetchDeletedSpeechText(language: LanguageSetting) -> [Speeches.Speech] {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        // 削除済みアイテムを取得（言語フィルタなし - 全言語統一）
        fetchRequest.predicate = NSPredicate(format: "deletedAt != nil")
        let sortDescriptor = NSSortDescriptor(key: "deletedAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let coreDataSpeechTexts = try managedContext.fetch(fetchRequest)

            return coreDataSpeechTexts.map { speechText in
                Speeches.Speech(
                    id: speechText.uuid ?? UUID(),
                    title: speechText.title ?? "",
                    text: speechText.text ?? "",
                    isDefault: false,
                    createdAt: speechText.createdAt ?? Date(),
                    updatedAt: speechText.updatedAt ?? Date(),
                    deletedAt: speechText.deletedAt,
                    fileType: speechText.fileType,
                    imagePath: speechText.imagePath
                )
            }
        } catch let error as NSError {
            errorLog("FetchRequest error: \(error), \(error.userInfo)")
            return []
        }
    }


    func updateSpeechText(id: UUID, title: String, text: String, ttsMode: String? = nil) {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)

        do {
            let fetchedItems = try managedContext.fetch(fetchRequest)
            if let itemToUpdate = fetchedItems.first {
                itemToUpdate.title = title
                itemToUpdate.text = text
                if let ttsMode = ttsMode {
                    itemToUpdate.ttsMode = ttsMode
                }
                itemToUpdate.updatedAt = Date()
                try managedContext.save()
            }
        } catch {
            errorLog("Update error: \(error.localizedDescription)")
        }
    }

    func fetchTTSMode(id: UUID) -> String? {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)

        do {
            let fetchedItems = try managedContext.fetch(fetchRequest)
            return fetchedItems.first?.ttsMode
        } catch {
            errorLog("Fetch TTS mode error: \(error.localizedDescription)")
            return nil
        }
    }

    func delete(id: UUID) {
        // ソフトデリート: deletedAtを設定
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)

        do {
            let fetchedItems = try managedContext.fetch(fetchRequest)
            if let itemToDelete = fetchedItems.first {
                itemToDelete.deletedAt = Date()
                try managedContext.save()
            }
        } catch {
            errorLog("Delete error: \(error.localizedDescription)")
        }
    }

    func restore(id: UUID) {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)

        do {
            let fetchedItems = try managedContext.fetch(fetchRequest)
            if let itemToRestore = fetchedItems.first {
                itemToRestore.deletedAt = nil
                try managedContext.save()
            }
        } catch {
            errorLog("Restore error: \(error.localizedDescription)")
        }
    }

    func permanentlyDelete(id: UUID) {
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)

        do {
            let fetchedItems = try managedContext.fetch(fetchRequest)
            if let itemToDelete = fetchedItems.first {
                managedContext.delete(itemToDelete)
                try managedContext.save()
            }
        } catch {
            errorLog("Permanent delete error: \(error.localizedDescription)")
        }
    }

    func cleanupOldDeletedItems() {
        // 7日以上前に削除されたアイテムを完全削除
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let fetchRequest: NSFetchRequest<SpeechText> = SpeechText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deletedAt != nil AND deletedAt < %@", sevenDaysAgo as NSDate)

        do {
            let itemsToDelete = try managedContext.fetch(fetchRequest)
            for item in itemsToDelete {
                managedContext.delete(item)
            }
            if !itemsToDelete.isEmpty {
                try managedContext.save()
                infoLog("Cleaned up \(itemsToDelete.count) old deleted items")
            }
        } catch {
            errorLog("Cleanup error: \(error.localizedDescription)")
        }
    }

}
