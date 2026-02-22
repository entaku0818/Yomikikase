import Foundation
import ZIPFoundation

struct EPUBTextExtractor {

    enum EPUBError: Error, LocalizedError {
        case invalidEPUB
        case containerNotFound
        case opfNotFound
        case noContent

        var errorDescription: String? {
            switch self {
            case .invalidEPUB: return "無効なEPUBファイルです"
            case .containerNotFound: return "EPUBのコンテナ情報が見つかりません"
            case .opfNotFound: return "EPUBのパッケージ情報が見つかりません"
            case .noContent: return "EPUBにテキストコンテンツが見つかりません"
            }
        }
    }

    static func extract(from url: URL) throws -> String {
        let archive = try Archive(url: url, accessMode: .read)

        // 1. Read META-INF/container.xml
        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw EPUBError.containerNotFound
        }

        var containerData = Data()
        try archive.extract(containerEntry) { containerData.append($0) }

        // 2. Parse container.xml → OPF file path
        let opfPath = try ContainerXMLParser.parseOPFPath(from: containerData)

        // 3. Read OPF file
        guard let opfEntry = archive[opfPath] else {
            throw EPUBError.opfNotFound
        }

        var opfData = Data()
        try archive.extract(opfEntry) { opfData.append($0) }

        // 4. Parse OPF → spine XHTML file paths (relative to OPF dir)
        let opfBasePath = (opfPath as NSString).deletingLastPathComponent
        let relativeHrefs = try OPFParser.parseSpineHrefs(from: opfData)

        // 5. Extract text from each XHTML file in spine order
        var texts: [String] = []
        for href in relativeHrefs {
            // Build the full path inside the archive
            let fullPath = opfBasePath.isEmpty ? href : "\(opfBasePath)/\(href)"
            let entry = archive[fullPath] ?? archive[href]
            guard let entry else { continue }

            var itemData = Data()
            try archive.extract(entry) { itemData.append($0) }

            let encoding: String.Encoding = String(data: itemData, encoding: .utf8) != nil ? .utf8 : .isoLatin1
            if let html = String(data: itemData, encoding: encoding) {
                let text = HTMLTextExtractor.extract(from: html)
                if !text.isEmpty {
                    texts.append(text)
                }
            }
        }

        if texts.isEmpty {
            throw EPUBError.noContent
        }

        return texts.joined(separator: "\n\n")
    }
}

// MARK: - container.xml parser
private class ContainerXMLParser: NSObject, XMLParserDelegate {
    private var opfPath: String?

    static func parseOPFPath(from data: Data) throws -> String {
        let parser = ContainerXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        guard let path = parser.opfPath else {
            throw EPUBTextExtractor.EPUBError.containerNotFound
        }
        return path
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        if elementName == "rootfile", let path = attributes["full-path"] {
            opfPath = path
        }
    }
}

// MARK: - OPF parser
private class OPFParser: NSObject, XMLParserDelegate {
    private var manifestItems: [String: String] = [:]   // id → href
    private var spineIdrefs: [String] = []
    private var inManifest = false
    private var inSpine = false

    static func parseSpineHrefs(from data: Data) throws -> [String] {
        let parser = OPFParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.spineIdrefs.compactMap { parser.manifestItems[$0] }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        switch elementName {
        case "manifest": inManifest = true
        case "spine": inSpine = true
        case "item" where inManifest:
            if let id = attributes["id"], let href = attributes["href"] {
                // Skip CSS, images, fonts — only keep XHTML/HTML
                let mt = attributes["media-type"] ?? ""
                if mt.contains("html") || mt.contains("xhtml") || href.hasSuffix(".xhtml") || href.hasSuffix(".html") || href.hasSuffix(".htm") {
                    manifestItems[id] = href
                }
            }
        case "itemref" where inSpine:
            if let idref = attributes["idref"] {
                spineIdrefs.append(idref)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "manifest" { inManifest = false }
        if elementName == "spine" { inSpine = false }
    }
}
