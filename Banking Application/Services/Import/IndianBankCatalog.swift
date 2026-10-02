import Foundation

/// Scheduled commercial banks, payments banks, small finance banks, and the
/// larger urban co-operative banks that send customer SMS in India.
/// Matching is on the bank name or the sender fragment that appears in the
/// message. Regional rural banks are matched by "gramin" / "grameen".
struct IndianBank: Equatable {
    var name: String
    var aliases: [String]
}

enum IndianBankCatalog {
    static let banks: [IndianBank] = [
        // Public sector
        bank("State Bank of India", "sbi", "sbin", "sbiinb", "state bank"),
        bank("Punjab National Bank", "pnb", "pnbbnk", "punjab national"),
        bank("Bank of Baroda", "bob", "baroda", "bank of baroda", "bobbnk"),
        bank("Canara Bank", "canara", "canbnk", "cnrbnk"),
        bank("Union Bank of India", "union bank", "ubin", "unionbk"),
        bank("Indian Bank", "indian bank", "idibn", "indbnk"),
        bank("Bank of India", "bank of india", "boibn", "bkiden"),
        bank("Central Bank of India", "central bank", "cbin", "cbi"),
        bank("Indian Overseas Bank", "indian overseas", "iob", "iobbnk"),
        bank("UCO Bank", "uco bank", "ucobnk", "uco"),
        bank("Bank of Maharashtra", "bank of maharashtra", "mahb", "mahabank"),
        bank("Punjab and Sind Bank", "punjab and sind", "punjab & sind", "psb"),
        // Private
        bank("HDFC Bank", "hdfc", "hdfcbk"),
        bank("ICICI Bank", "icici", "icicib"),
        bank("Axis Bank", "axis", "axisbk", "utib"),
        bank("Kotak Mahindra Bank", "kotak", "kotakb", "kkbk"),
        bank("IndusInd Bank", "indusind", "indus", "indb"),
        bank("Yes Bank", "yes bank", "yesbnk", "yesb"),
        bank("IDFC First Bank", "idfc", "idfc first", "idfb"),
        bank("Federal Bank", "federal", "fdrl", "fedbnk"),
        bank("South Indian Bank", "south indian", "sibl", "sib"),
        bank("Karnataka Bank", "karnataka bank", "karb"),
        bank("Karur Vysya Bank", "karur vysya", "kvbl", "karur"),
        bank("Tamilnad Mercantile Bank", "tmb", "tamilnad mercantile"),
        bank("City Union Bank", "city union", "ciub", "cub"),
        bank("CSB Bank", "csb", "catholic syrian"),
        bank("DCB Bank", "dcb"),
        bank("RBL Bank", "rbl"),
        bank("Bandhan Bank", "bandhan", "bdbl"),
        bank("IDBI Bank", "idbi"),
        bank("Jammu and Kashmir Bank", "j&k bank", "jk bank", "jaka"),
        bank("Nainital Bank", "nainital"),
        bank("Dhanlaxmi Bank", "dhanlaxmi", "dhanlaxmi", "dlxb"),
        bank("DBS Bank", "dbs", "lakshmi vilas"),
        bank("Tamil Nadu Grama Bank", "tamil nadu grama"),
        // Small finance
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
        // Payments banks
        bank("Airtel Payments Bank", "airtel payments", "airtel bank"),
        bank("India Post Payments Bank", "ippb", "india post payments"),
        bank("Fino Payments Bank", "fino"),
        bank("Paytm Payments Bank", "paytm payments", "paytmb"),
        bank("Jio Payments Bank", "jio payments", "jiopb"),
        bank("NSDL Payments Bank", "nsdl payments"),
        // Foreign banks with Indian retail SMS
        bank("HSBC", "hsbc"),
        bank("Standard Chartered", "standard chartered", "scbl", "stan chart"),
        bank("Citibank", "citibank", "citi"),
        bank("Deutsche Bank", "deutsche"),
        bank("Barclays", "barclays"),
        bank("SBM Bank India", "sbm bank"),
        bank("Bank of America", "bank of america", "bofa"),
        // Urban co-operative banks that customers commonly import
        bank("Saraswat Co-operative Bank", "saraswat"),
        bank("Cosmos Co-operative Bank", "cosmos"),
        bank("TJSB Sahakari Bank", "tjsb"),
        bank("SVC Co-operative Bank", "svc bank", "svc co"),
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
        bank("Punjab and Maharashtra Co-operative Bank", "pmc bank"),
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

enum IndianBankSMSGrammar {
    /// Shared debit/credit grammar used by Indian bank SMS, whatever the sender.
    static func parse(_ text: String, now: Date) -> RawBankEvent? {
        guard let amount = amount(in: text), let direction = direction(in: text) else { return nil }
        let bank = IndianBankCatalog.identify(in: text) ?? "Indian bank"
        let last4 = accountLast4(in: text) ?? ""
        let reference = externalRef(in: text)
        let known = IndianBankCatalog.identify(in: text) != nil
        let confidence: Double
        if known && (!last4.isEmpty || reference != nil) {
            confidence = 0.95
        } else if known {
            confidence = 0.82
        } else if !last4.isEmpty || reference != nil {
            confidence = 0.74
        } else {
            confidence = 0.55
        }
        return RawBankEvent(
            amount: amount,
            direction: direction,
            accountLast4: last4,
            merchant: merchant(in: text),
            externalRef: reference,
            occurredAt: now,
            bank: bank,
            source: .smsImport,
            confidence: confidence
        )
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

    private static func direction(in text: String) -> ImportDirection? {
        let lower = text.lowercased()
        let credit = ["credited", "credit of", "received", "deposited", "has credit"]
        let debit = ["debited", "debit of", "spent", "sent", "paid", "withdrawn", "purchase", "deducted"]
        if credit.contains(where: { lower.contains($0) }) { return .credit }
        if debit.contains(where: { lower.contains($0) }) { return .debit }
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
            if let raw = firstGroup(pattern, in: text, group: 1) {
                return raw
            }
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
            if cleaned.count >= 2, !cleaned.lowercased().hasPrefix("your ") {
                return cleaned
            }
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
