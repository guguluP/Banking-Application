import Foundation

nonisolated struct CapturedBankSMS: Equatable {
    var amount: Decimal
    var isCredit: Bool
    var accountLast4: String
    var merchant: String?
    var externalRef: String?
    var bank: String
    var confidence: Double
    var occurredAt: Date = Date()
}

nonisolated struct IndianBank: Equatable {
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
    /// Compiled once. `NSRegularExpression` is immutable and safe to share across threads.
    private static func compile(_ pattern: String, _ options: NSRegularExpression.Options = [.caseInsensitive]) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }

    private static let number = #"(?:[0-9]{1,3}(?:,[0-9]{2,3})+|[0-9]+)(?:\.[0-9]{1,2})?"#
    nonisolated(unsafe) private static let otpCodeRegex = compile(#"\b\d{4,8}\b"#, [])
    nonisolated(unsafe) private static let namedMonthDateRegex = compile(#"\b(\d{1,2})[\/\-.]([A-Za-z]{3})[\/\-.](\d{2,4})\b"#)
    nonisolated(unsafe) private static let numericDateRegex = compile(#"\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b"#)
    nonisolated(unsafe) private static let amountRegexes: [NSRegularExpression] = [
        "(?:₹|Rs\\.?|INR)\\s*(\(number))",
        "(\(number))\\s*(?:₹|Rs\\.?|INR|rupees)"
    ].compactMap { compile($0) }
    nonisolated(unsafe) private static let accountLast4Regexes: [NSRegularExpression] = [
        #"(?:a/?c(?:count)?|acct|card)(?:\s*(?:no\.?|number|ending))?\s*(?:xx+|\*{2,}|x{2,})?\s*(\d{4})\b"#,
        #"(?:xx+|\*{2,}|x{2,})(\d{4})\b"#,
        #"ending\s+(\d{4})\b"#
    ].compactMap { compile($0) }
    nonisolated(unsafe) private static let externalRefRegexes: [NSRegularExpression] = [
        #"(?:UTR|RRN|UPI\s*Ref(?:erence)?(?:\s*No\.?)?|Ref(?:erence)?(?:\s*No\.?)?|IMPS\s*Ref)\s*[:\-]?\s*([A-Za-z0-9]{6,22})"#,
        #"\b((?:IMPS|NEFT|RTGS|UPI)[A-Z0-9]{8,})\b"#
    ].compactMap { compile($0) }
    nonisolated(unsafe) private static let merchantRegexes: [NSRegularExpression] = [
        #"(?:VPA|UPI\s*ID)\s*[:\-]?\s*([A-Za-z0-9.\-_]+@[A-Za-z0-9]+)"#,
        #"UPI[/\-]([A-Za-z0-9.\-_@]{2,40})"#,
        #"(?:to|at|towards|info:?)\s+([A-Za-z0-9][A-Za-z0-9@.\- ]{1,40})"#,
        #"([A-Za-z0-9.\-_]+@[A-Za-z0-9]+)"#
    ].compactMap { compile($0) }

    /// - Parameter checkOTP: pass `false` only when the caller already ran `looksLikeOTP` on this text.
    static func parse(_ text: String, now: Date = Date(), checkOTP: Bool = true) -> CapturedBankSMS? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if checkOTP, looksLikeOTP(trimmed) { return nil }
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
            confidence: confidence,
            occurredAt: occurredAt(in: trimmed, now: now)
        )
    }

    /// OTP only when the word sits next to a 4–8 digit code. A distant "Never share OTP" does not drop a debit alert.
    static func looksLikeOTP(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = ["one-time password", "one time password", "one time", "otp"]
        guard let regex = otpCodeRegex else { return false }
        let nsRange = NSRange(lower.startIndex..., in: lower)
        let codes = regex.matches(in: lower, range: nsRange).compactMap { Range($0.range, in: lower) }
        guard !codes.isEmpty else { return false }
        for keyword in keywords {
            var search = lower.startIndex..<lower.endIndex
            while let found = lower.range(of: keyword, range: search) {
                search = found.upperBound..<lower.endIndex
                guard isIsolatedToken(found, in: lower) else { continue }
                for code in codes {
                    let gap: Int
                    if code.lowerBound >= found.upperBound {
                        gap = lower.distance(from: found.upperBound, to: code.lowerBound)
                    } else if found.lowerBound >= code.upperBound {
                        gap = lower.distance(from: code.upperBound, to: found.lowerBound)
                    } else {
                        gap = 0
                    }
                    if gap <= 40 { return true }
                }
            }
        }
        return false
    }

    private static func isIsolatedToken(_ range: Range<String.Index>, in text: String) -> Bool {
        if range.lowerBound > text.startIndex {
            let before = text[text.index(before: range.lowerBound)]
            if before.isLetter || before.isNumber { return false }
        }
        if range.upperBound < text.endIndex {
            let after = text[range.upperBound]
            if after.isLetter || after.isNumber { return false }
        }
        return true
    }

    static func occurredAt(in text: String, now: Date = Date()) -> Date {
        if let regex = namedMonthDateRegex, let date = dateMatch(in: text, regex: regex, namedMonth: true) {
            return date
        }
        if let regex = numericDateRegex, let date = dateMatch(in: text, regex: regex, namedMonth: false) {
            return date
        }
        return now
    }

    private static func amount(in text: String) -> Decimal? {
        for regex in amountRegexes {
            guard let raw = firstGroup(regex, in: text, group: 1) else { continue }
            if let value = AmountParser.parse(raw), value > 0 {
                return value
            }
        }
        return nil
    }

    private static func directionIsCredit(in text: String) -> Bool? {
        let lower = text.lowercased()
        let strongCredit = ["credited", "credit of", "deposited"]
        let weakCredit = ["received", "has credit"]
        let debitWords = ["debited", "debit of", "spent", "sent", "paid", "withdrawn", "purchase", "deducted"]
        func earliest(_ words: [String]) -> String.Index? {
            words.compactMap { lower.range(of: $0)?.lowerBound }.min()
        }
        switch (earliest(strongCredit), earliest(debitWords)) {
        case let (credit?, debit?):
            return credit < debit
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return earliest(weakCredit) == nil ? nil : true
        }
    }

    private static func dateMatch(in text: String, regex: NSRegularExpression, namedMonth: Bool) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        for hit in regex.matches(in: text, range: range) {
            guard hit.numberOfRanges > 3,
                  let dayRange = Range(hit.range(at: 1), in: text),
                  let midRange = Range(hit.range(at: 2), in: text),
                  let yearRange = Range(hit.range(at: 3), in: text),
                  let day = Int(text[dayRange]),
                  (1...31).contains(day) else { continue }
            let month: Int
            if namedMonth {
                let key = String(text[midRange]).lowercased()
                let names = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
                guard let value = names[key] else { continue }
                month = value
            } else if let value = Int(text[midRange]), (1...12).contains(value) {
                month = value
            } else {
                continue
            }
            var year = Int(text[yearRange]) ?? 0
            if year < 100 { year += 2000 }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            var parts = DateComponents()
            parts.calendar = calendar
            parts.timeZone = .current
            parts.year = year
            parts.month = month
            parts.day = day
            parts.hour = 12
            if let date = calendar.date(from: parts) { return date }
        }
        return nil
    }

    private static func accountLast4(in text: String) -> String? {
        for regex in accountLast4Regexes {
            if let raw = firstGroup(regex, in: text, group: 1) {
                return String(raw.filter(\.isNumber).suffix(4))
            }
        }
        return nil
    }

    private static func externalRef(in text: String) -> String? {
        for regex in externalRefRegexes {
            if let raw = firstGroup(regex, in: text, group: 1) { return raw }
        }
        return nil
    }

    private static func merchant(in text: String) -> String? {
        for regex in merchantRegexes {
            guard let raw = firstGroup(regex, in: text, group: 1) else { continue }
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 2 { return cleaned }
        }
        return nil
    }

    private static func firstGroup(_ regex: NSRegularExpression, in text: String, group: Int) -> String? {
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
