import Foundation

class MOBIReader: BookReaderProtocol {
    private struct MOBIHeader {
        var identifier: UInt32
        var headerLength: UInt32
        var mobiType: UInt32
        var textLength: UInt32
        var encoding: UInt32
        var language: UInt32
        var version: UInt32
        var uniqueId: UInt32
        var fileVersion: UInt32
        var orthographicIndex: UInt32
        var inflectionIndex: UInt32
        var indexNames: UInt32
        var indexKeys: UInt32
        var extraIndex0: UInt32
        var extraIndex1: UInt32
        var extraIndex2: UInt32
        var extraIndex3: UInt32
        var extraIndex4: UInt32
        var extraIndex5: UInt32
        var firstNonBookIndex: UInt32
        var fullNameOffset: UInt32
        var fullNameLength: UInt32
        var locale: UInt32
        var inputLanguage: UInt32
        var outputLanguage: UInt32
        var minVersion: UInt32
        var firstImageIndex: UInt32
        var huffmanRecordOffset: UInt32
        var huffmanRecordCount: UInt32
        var huffmanTableOffset: UInt32
        var exthFlags: UInt32
        var unknown1: UInt32
        var unknown2: UInt32
        var drmOffset: UInt32
        var drmCount: UInt32
        var drmSize: UInt32
        var drmFlags: UInt32
        var firstContentRecord: UInt32
        var lastContentRecord: UInt32
        var unknown3: UInt32
        var fcIndex: UInt32
        var fcCount: UInt32
        var unknown4: UInt32
        var unknown5: UInt32
        var unknown6: UInt32
        var unknown7: UInt32
        var unknown8: UInt32
        var unknown9: UInt32
        var unknown10: UInt32
        var unknown11: UInt32
        var unknown12: UInt32
        var unknown13: UInt32
        var unknown14: UInt32
        var unknown15: UInt32
        var unknown16: UInt32
        var unknown17: UInt32
        var unknown18: UInt32
        var unknown19: UInt32
        var unknown20: UInt32
    }
    
    private struct PDBHeader {
        var name: [UInt8]
        var attributes: UInt16
        var version: UInt16
        var creationDate: UInt32
        var modificationDate: UInt32
        var backupDate: UInt32
        var modificationNumber: UInt32
        var appInfoId: UInt32
        var sortInfoId: UInt32
        var type: [UInt8]
        var creator: [UInt8]
        var uniqueIdSeed: UInt32
        var nextRecordListId: UInt32
        var numberOfRecords: UInt16
    }
    
    private var header: MOBIHeader?
    private var pdbHeader: PDBHeader?
    private var records: [Data] = []
    private var exthRecords: [EXTHRecord] = []
    
    struct EXTHRecord {
        var type: UInt32
        var length: UInt32
        var data: Data
    }
    
    func read(data: Data) async throws -> BookContent {
        try parseHeader(data: data)
        try parseRecords(data: data)
        
        let content = try extractText()
        let metadata = getMetadata(data: data)
        
        return BookContent(
            title: metadata.title,
            author: metadata.author,
            chapters: parseChapters(content),
            cover: extractCover(data: data),
            metadata: metadata,
            rawContent: content
        )
    }
    
    func extractCover(data: Data) -> Data? {
        if let coverIndex = exthRecords.first(where: { $0.type == 201 }) {
            return coverIndex.data
        }
        if let coverIndex = exthRecords.first(where: { $0.type == 202 }) {
            return coverIndex.data
        }
        return nil
    }
    
    func getMetadata(data: Data) -> BookMetadata {
        var metadata = BookMetadata()
        
        for record in exthRecords {
            switch record.type {
            case 100:
                metadata.title = record.data.toString()
            case 101:
                metadata.author = record.data.toString()
            case 103:
                metadata.description = record.data.toString()
            case 105:
                metadata.language = record.data.toString()
            case 106:
                metadata.isbn = record.data.toString()
            case 107:
                metadata.publisher = record.data.toString()
            case 501:
                metadata.series = record.data.toString()
            case 502:
                metadata.seriesIndex = Int(record.data.toUInt32() ?? 0)
            default:
                break
            }
        }
        
        if metadata.title.isEmpty, let name = pdbHeader?.name.toString().trimmingCharacters(in: .controlCharacters) {
            metadata.title = name
        }
        
        return metadata
    }
    
    func getTableOfContents(data: Data) -> [BookChapter] {
        let content = try? extractText()
        return parseChapters(content ?? "")
    }
    
    private func parseHeader(data: Data) throws {
        pdbHeader = try parsePDBHeader(data: data)
        
        let mobiHeaderOffset = Int(pdbHeader!.nextRecordListId) + 8
        header = try parseMOBIHeader(data: data, offset: mobiHeaderOffset)
        
        if let exthFlags = header?.exthFlags, (exthFlags & 0x40) != 0 {
            try parseEXTH(data: data, offset: mobiHeaderOffset + 16)
        }
    }
    
    private func parsePDBHeader(data: Data) throws -> PDBHeader {
        guard data.count >= 78 else { throw MOBIError.invalidFormat }
        
        let header = PDBHeader(
            name: Array(data[0..<32]),
            attributes: data[32..<34].toUInt16(),
            version: data[34..<36].toUInt16(),
            creationDate: data[36..<40].toUInt32(),
            modificationDate: data[40..<44].toUInt32(),
            backupDate: data[44..<48].toUInt32(),
            modificationNumber: data[48..<52].toUInt32(),
            appInfoId: data[52..<56].toUInt32(),
            sortInfoId: data[56..<60].toUInt32(),
            type: Array(data[60..<64]),
            creator: Array(data[64..<68]),
            uniqueIdSeed: data[68..<72].toUInt32(),
            nextRecordListId: data[72..<76].toUInt32(),
            numberOfRecords: data[76..<78].toUInt16()
        )
        
        return header
    }
    
    private func parseMOBIHeader(data: Data, offset: Int) throws -> MOBIHeader {
        guard data.count >= offset + 264 else { throw MOBIError.invalidFormat }
        
        return MOBIHeader(
            identifier: data[offset..<offset+4].toUInt32(),
            headerLength: data[offset+4..<offset+8].toUInt32(),
            mobiType: data[offset+8..<offset+12].toUInt32(),
            textLength: data[offset+12..<offset+16].toUInt32(),
            encoding: data[offset+16..<offset+20].toUInt32(),
            language: data[offset+20..<offset+24].toUInt32(),
            version: data[offset+24..<offset+28].toUInt32(),
            uniqueId: data[offset+28..<offset+32].toUInt32(),
            fileVersion: data[offset+32..<offset+36].toUInt32(),
            orthographicIndex: data[offset+36..<offset+40].toUInt32(),
            inflectionIndex: data[offset+40..<offset+44].toUInt32(),
            indexNames: data[offset+44..<offset+48].toUInt32(),
            indexKeys: data[offset+48..<offset+52].toUInt32(),
            extraIndex0: data[offset+52..<offset+56].toUInt32(),
            extraIndex1: data[offset+56..<offset+60].toUInt32(),
            extraIndex2: data[offset+60..<offset+64].toUInt32(),
            extraIndex3: data[offset+64..<offset+68].toUInt32(),
            extraIndex4: data[offset+68..<offset+72].toUInt32(),
            extraIndex5: data[offset+72..<offset+76].toUInt32(),
            firstNonBookIndex: data[offset+76..<offset+80].toUInt32(),
            fullNameOffset: data[offset+80..<offset+84].toUInt32(),
            fullNameLength: data[offset+84..<offset+88].toUInt32(),
            locale: data[offset+88..<offset+92].toUInt32(),
            inputLanguage: data[offset+92..<offset+96].toUInt32(),
            outputLanguage: data[offset+96..<offset+100].toUInt32(),
            minVersion: data[offset+100..<offset+104].toUInt32(),
            firstImageIndex: data[offset+104..<offset+108].toUInt32(),
            huffmanRecordOffset: data[offset+108..<offset+112].toUInt32(),
            huffmanRecordCount: data[offset+112..<offset+116].toUInt32(),
            huffmanTableOffset: data[offset+116..<offset+120].toUInt32(),
            exthFlags: data[offset+120..<offset+124].toUInt32(),
            unknown1: data[offset+124..<offset+128].toUInt32(),
            unknown2: data[offset+128..<offset+132].toUInt32(),
            drmOffset: data[offset+132..<offset+136].toUInt32(),
            drmCount: data[offset+136..<offset+140].toUInt32(),
            drmSize: data[offset+140..<offset+144].toUInt32(),
            drmFlags: data[offset+144..<offset+148].toUInt32(),
            firstContentRecord: data[offset+148..<offset+152].toUInt32(),
            lastContentRecord: data[offset+152..<offset+156].toUInt32(),
            unknown3: data[offset+156..<offset+160].toUInt32(),
            fcIndex: data[offset+160..<offset+164].toUInt32(),
            fcCount: data[offset+164..<offset+168].toUInt32(),
            unknown4: data[offset+168..<offset+172].toUInt32(),
            unknown5: data[offset+172..<offset+176].toUInt32(),
            unknown6: data[offset+176..<offset+180].toUInt32(),
            unknown7: data[offset+180..<offset+184].toUInt32(),
            unknown8: data[offset+184..<offset+188].toUInt32(),
            unknown9: data[offset+188..<offset+192].toUInt32(),
            unknown10: data[offset+192..<offset+196].toUInt32(),
            unknown11: data[offset+196..<offset+200].toUInt32(),
            unknown12: data[offset+200..<offset+204].toUInt32(),
            unknown13: data[offset+204..<offset+208].toUInt32(),
            unknown14: data[offset+208..<offset+212].toUInt32(),
            unknown15: data[offset+212..<offset+216].toUInt32(),
            unknown16: data[offset+216..<offset+220].toUInt32(),
            unknown17: data[offset+220..<offset+224].toUInt32(),
            unknown18: data[offset+224..<offset+228].toUInt32(),
            unknown19: data[offset+228..<offset+232].toUInt32(),
            unknown20: data[offset+232..<offset+264].toUInt32()
        )
    }
    
    private func parseEXTH(data: Data, offset: Int) throws {
        guard data.count >= offset + 8 else { return }
        
        let exthMagic = data[offset..<offset+4].toUInt32()
        guard exthMagic == 0x45585448 else { return }
        
        let exthLength = data[offset+4..<offset+8].toUInt32()
        var currentOffset = offset + 8
        
        while currentOffset + 8 < offset + Int(exthLength) {
            let recordType = data[currentOffset..<currentOffset+4].toUInt32()
            let recordLength = data[currentOffset+4..<currentOffset+8].toUInt32()
            
            if currentOffset + Int(recordLength) <= data.count {
                let recordData = data[currentOffset+8..<currentOffset+Int(recordLength)]
                exthRecords.append(EXTHRecord(type: recordType, length: recordLength, data: recordData))
            }
            
            currentOffset += Int(recordLength)
        }
    }
    
    private func parseRecords(data: Data) throws {
        guard let pdbHeader = pdbHeader else { throw MOBIError.invalidFormat }
        
        let recordListOffset = Int(pdbHeader.nextRecordListId)
        let recordCount = Int(pdbHeader.numberOfRecords)
        
        for i in 0..<recordCount {
            let offset = recordListOffset + i * 8
            if offset + 8 <= data.count {
                let recordDataOffset = Int(data[offset..<offset+4].toUInt32())
                let recordDataLength = Int(data[offset+4..<offset+8].toUInt32())
                
                if recordDataOffset + recordDataLength <= data.count {
                    let recordData = data[recordDataOffset..<recordDataOffset+recordDataLength]
                    records.append(recordData)
                }
            }
        }
    }
    
    private func extractText() throws -> String {
        guard let header = header else { throw MOBIError.invalidFormat }
        
        let firstRecord = Int(header.firstContentRecord)
        let lastRecord = Int(header.lastContentRecord)
        
        var content = Data()
        for i in firstRecord...lastRecord {
            if i < records.count {
                content.append(records[i])
            }
        }
        
        let encoding: String.Encoding
        switch header.encoding {
        case 1252:
            encoding = .windowsCP1252
        case 65001:
            encoding = .utf8
        default:
            encoding = .ascii
        }
        
        return content.toString(encoding: encoding)
    }
    
    private func parseChapters(_ content: String) -> [BookChapter] {
        var chapters: [BookChapter] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentChapterContent = ""
        var currentChapterTitle = ""
        var offset = 0
        
        for line in lines {
            if line.hasPrefix("***") || line.hasPrefix("---") || line.hasPrefix("====") {
                if !currentChapterTitle.isEmpty {
                    chapters.append(BookChapter(
                        title: currentChapterTitle,
                        content: currentChapterContent,
                        startOffset: offset
                    ))
                    offset += currentChapterContent.count
                }
                currentChapterTitle = ""
                currentChapterContent = ""
            } else if line.count > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                if currentChapterTitle.isEmpty && !line.contains(" ") {
                    currentChapterTitle = line
                } else {
                    currentChapterContent += line + "\n"
                }
            }
        }
        
        if !currentChapterTitle.isEmpty {
            chapters.append(BookChapter(
                title: currentChapterTitle,
                content: currentChapterContent,
                startOffset: offset
            ))
        }
        
        if chapters.isEmpty {
            chapters.append(BookChapter(title: "正文", content: content))
        }
        
        return chapters
    }
}

enum MOBIError: Error, LocalizedError {
    case invalidFormat
    case drmProtected
    case unsupportedVersion
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无效的MOBI/AZW格式"
        case .drmProtected: return "书籍受DRM保护，无法阅读"
        case .unsupportedVersion: return "不支持的MOBI版本"
        }
    }
}

extension Array where Element == UInt8 {
    func toString() -> String {
        let nullIndex = firstIndex(of: 0) ?? count
        let slice = self[0..<nullIndex]
        return String(bytes: slice, encoding: .utf8) ?? String(bytes: slice, encoding: .windowsCP1252) ?? ""
    }
}

extension Data {
    func toUInt16() -> UInt16 {
        var value: UInt16 = 0
        copyBytes(to: &value, count: MemoryLayout<UInt16>.size)
        return UInt16(bigEndian: value)
    }
    
    func toUInt32() -> UInt32 {
        var value: UInt32 = 0
        copyBytes(to: &value, count: MemoryLayout<UInt32>.size)
        return UInt32(bigEndian: value)
    }
    
    func toString(encoding: String.Encoding = .utf8) -> String {
        return String(data: self, encoding: encoding) ?? String(data: self, encoding: .windowsCP1252) ?? ""
    }
}
