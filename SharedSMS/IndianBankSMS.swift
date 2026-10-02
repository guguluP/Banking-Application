import Foundation

struct CapturedBankSMS: Equatable {
    var amount: Decimal
    var isCredit: Bool
    var accountLast4: String
    var merchant: String?
    var externalRef: String?
    var bank: String
    var confidence: Double
}

struct IndianBank: Equatable {
    var name: String
    var aliases: [String]
}

nonisolated enum IndianBankCatalog {
    static let banks: [IndianBank] = [
        bank("State Bank of India", "sbi", "sbin", "sbiinb", "state bank"),
        bank("Punjab National Bank", "pnb", "pnbbnk", "punjab national"),
        bank("Bank of Baroda", "bob", "baroda", "bank of baroda", "bobbnk"),
        bank("Canara Bank", "canara", "canbnk", "cnrbnk"),
        bank("Union Bank of India", "union bank", "ubin", "unionbk"),
        bank("Indian Bank", "indian bank", "idibn", "indbnk"),
        bank("Bank of India", "bank of india", "boibn", "bkiden"),
        bank("Central Bank of India", "central bank", "cbin"),
        bank("Indian Overseas Bank", "indian overseas", "iob", "iobbnk"),
        bank("UCO Bank", "uco bank", "ucobnk"),
        bank("Bank of Maharashtra", "bank of maharashtra", "mahb", "mahabank"),
        bank("Punjab and Sind Bank", "punjab and sind", "punjab & sind"),
        bank("HDFC Bank", "hdfc", "hdfcbk"),
        bank("ICICI Bank", "icici", "icicib"),
        bank("Axis Bank", "axis", "axisbk", "utib"),
        bank("Kotak Mahindra Bank", "kotak", "kotakb", "kkbk"),
        bank("IndusInd Bank", "indusind", "indus", "indb"),
        bank("Yes Bank", "yes bank", "yesbnk", "yesb"),
        bank("IDFC First Bank", "idfc", "idfc first", "idfb"),
        bank("Federal Bank", "federal", "fdrl", "fedbnk"),
        bank("South Indian Bank", "south indian", "sibl"),
        bank("Karnataka Bank", "karnataka bank", "karb"),
        bank("Karur Vysya Bank", "karur vysya", "kvbl", "karur"),
        bank("Tamilnad Mercantile Bank", "tmb", "tamilnad mercantile"),
        bank("City Union Bank", "city union", "ciub"),
        bank("CSB Bank", "csb", "catholic syrian"),
        bank("DCB Bank", "dcb bank"),
        bank("RBL Bank", "rbl bank", "rbl"),
        bank("Bandhan Bank", "bandhan", "bdbl"),
        bank("IDBI Bank", "idbi"),
        bank("Jammu and Kashmir Bank", "j&k bank", "jk bank", "jaka"),
        bank("Nainital Bank", "nainital"),
        bank("Dhanlaxmi Bank", "dhanlaxmi", "dlxb"),
        bank("DBS Bank", "dbs", "lakshmi vilas"),
        bank("AU Small Finance Bank", "au bank", "au small", "aubl"),
        bank("Equitas Small Finance Bank", "equitas"),
        bank("Ujjivan Small Finance Bank", "ujjivan"),
        bank("Jana Small Finance Bank", "jana bank", "jana small"),
        bank("Suryoday Small Finance Bank", "suryoday"),
        bank("ESAF Small Finance Bank", "esaf"),
        bank("Utkarsh Small Finance Bank", "utkarsh"),
        bank("Capital Small Finance Bank", "capital small"),
        bank("North East Small Finance Bank", "north east small"),
        bank("Shivalik Small Finance Bank", "shivalik"),
        bank("Unity Small Finance Bank", "unity small", "unity bank"),
        bank("Airtel Payments Bank", "airtel payments", "airtel bank"),
        bank("India Post Payments Bank", "ippb", "india post payments"),
        bank("Fino Payments Bank", "fino"),
        bank("Paytm Payments Bank", "paytm payments", "paytmb"),
        bank("Jio Payments Bank", "jio payments", "jiopb"),
        bank("NSDL Payments Bank", "nsdl payments"),
        bank("HSBC", "hsbc"),
        bank("Standard Chartered", "standard chartered", "scbl", "stan chart"),
        bank("Citibank", "citibank", "citi"),
        bank("Deutsche Bank", "deutsche"),
        bank("Barclays", "barclays"),
        bank("SBM Bank India", "sbm bank"),
        bank("Bank of America", "bank of america", "bofa"),
        bank("Saraswat Co-operative Bank", "saraswat"),
        bank("Cosmos Co-operative Bank", "cosmos"),
        bank("TJSB Sahakari Bank", "tjsb"),
        bank("SVC Co-operative Bank", "svc bank"),
        bank("Abhyudaya Co-operative Bank", "abhyudaya"),
        bank("Bharat Co-operative Bank", "bharat co-operative", "bharat cooperative"),
        bank("NKGSB Co-operative Bank", "nkgsb"),
        bank("Apna Sahakari Bank", "apna sahakari"),
        bank("Kalupur Commercial Co-operative Bank", "kalupur"),
        bank("Rajkot Nagarik Sahakari Bank", "rajkot nagarik"),
        bank("Mehsana Urban Co-operative Bank", "mehsana urban"),
        bank("Shamrao Vithal Co-operative Bank", "shamrao vithal"),
        bank("Greater Bombay Co-operative Bank", "greater bombay"),
        bank("Bombay Mercantile Co-operative Bank", "bombay mercantile"),
        bank("New India Co-operative Bank", "new india co-operative"),
        bank("Regional Rural Bank", "gramin bank", "grameen bank", "regional rural")
    ]

    static func identify(in text: String) -> String? {
        let lower = text.lowercased()
        var best: (name: String, length: Int)?
        for entry in banks {
            for alias in entry.aliases where lower.contains(alias) {
                if best == nil || alias.count > best!.length {
                    best = (entry.name, alias.count)
                }
            }
        }
        return best?.name
    }

    private static func bank(_ name: String, _ aliases: String...) -> IndianBank {
        IndianBank(name: name, aliases: aliases.map { $0.lowercased() })
    }
}

nonisolated enum IndianBankSMSGrammar {
    static func parse(_ text: String) -> CapturedBankSMS? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !looksLikeOTP(trimmed) else { return nil }
        guard let amount = amount(in: trimmed), let isCredit = directionIsCredit(in: trimmed) else { return nil }
        let known = IndianBankCatalog.identify(in: trimmed)
        let last4 = accountLast4(in: trimmed) ?? ""
        let reference = externalRef(in: trimmed)
        let confidence: Double
        if known != nil && (!last4.isEmpty || reference != nil) {
            confidence = 0.95
        } else if known != nil {
            confidence = 0.82
        } else if !last4.isEmpty || reference != nil {
            confidence = 0.74
        } else {
            confidence = 0.55
        }
        return CapturedBankSMS(
            amount: amount,
            isCredit: isCredit,
            accountLast4: last4,
            merchant: merchant(in: trimmed),
            externalRef: reference,
            bank: known ?? "Indian bank",
            confidence: confidence
        )
    }

    private static func looksLikeOTP(_ text: String) -> Bool {
        let lower = text.lowercased()
        let otpWord = lower.contains("otp") || lower.contains("one time") || lower.contains("do not share")
        return otpWord && text.range(of: #"\b\d{4,8}\b"#, options: .regularExpression) != nil
    }

    private static func amount(in text: String) -> Decimal? {
        let patterns = [
            #"(?:₹|Rs\.?|INR)\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)"#,
            #"([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)\s*(?:₹|Rs\.?|INR|rupees)"#
        ]
        for pattern in patterns {
            guard let raw = firstGroup(pattern, in: text, group: 1) else { continue }
            if let value = Decimal(string: raw.replacingOccurrences(of: ",", with: "")), value > 0 {
                return value
            }
        }
        return nil
    }

    private static func directionIsCredit(in text: String) -> Bool? {
        let lower = text.lowercased()
        if ["credited", "credit of", "received", "deposited", "has credit"].contains(where: { lower.contains($0) }) {
            return true
        }
        if ["debited", "debit of", "spent", "sent", "paid", "withdrawn", "purchase", "deducted"].contains(where: { lower.contains($0) }) {
            return false
        }
        return nil
    }

    private static func accountLast4(in text: String) -> String? {
        let patterns = [
            #"(?:a/?c(?:count)?|acct|card)(?:\s*(?:no\.?|number|ending))?\s*(?:xx+|\*{2,}|x{2,})?\s*(\d{4})\b"#,
            #"(?:xx+|\*{2,}|x{2,})(\d{4})\b"#,
            #"ending\s+(\d{4})\b"#
        ]
        for pattern in patterns {
            if let raw = firstGroup(pattern, in: text, group: 1) {
                return String(raw.filter(\.isNumber).suffix(4))
            }
        }
        return nil
    }

    private static func externalRef(in text: String) -> String? {
        let patterns = [
            #"(?:UTR|RRN|UPI\s*Ref(?:erence)?(?:\s*No\.?)?|Ref(?:erence)?(?:\s*No\.?)?|IMPS\s*Ref)\s*[:\-]?\s*([A-Za-z0-9]{6,22})"#,
            #"\b((?:IMPS|NEFT|RTGS|UPI)[A-Z0-9]{8,})\b"#
        ]
        for pattern in patterns {
            if let raw = firstGroup(pattern, in: text, group: 1) { return raw }
        }
        return nil
    }

    private static func merchant(in text: String) -> String? {
        let patterns = [
            #"(?:VPA|UPI\s*ID)\s*[:\-]?\s*([A-Za-z0-9.\-_]+@[A-Za-z0-9]+)"#,
            #"UPI[/\-]([A-Za-z0-9.\-_@]{2,40})"#,
            #"(?:to|at|towards|info:?)\s+([A-Za-z0-9][A-Za-z0-9@.\- ]{1,40})"#,
            #"([A-Za-z0-9.\-_]+@[A-Za-z0-9]+)"#
        ]
        for pattern in patterns {
            guard let raw = firstGroup(pattern, in: text, group: 1) else { continue }
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 2 { return cleaned }
        }
        return nil
    }

    private static func firstGroup(_ pattern: String, in text: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let hit = regex.firstMatch(in: text, range: range),
              hit.numberOfRanges > group,
              let slice = Range(hit.range(at: group), in: text) else { return nil }
        return String(text[slice])
    }
}

nonisolated enum SMSInbox {
    static let groupID = "group.com.piyushpatnaik.Banking-Application"

    static func append(text: String) {
        guard IndianBankSMSGrammar.parse(text) != nil else { return }
        let url = fileURL()
        let line = Data((text.replacingOccurrences(of: "\n", with: " ") + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            try? line.write(to: url, options: .atomic)
        }
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }

    static func drain() -> [String] {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return [] }
        try? FileManager.default.removeItem(at: url)
        return text.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }

    private static func fileURL() -> URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("bank-sms-inbox.txt")
    }
}
