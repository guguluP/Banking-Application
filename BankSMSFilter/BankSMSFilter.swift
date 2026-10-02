import IdentityLookup

final class BankSMSFilter: ILMessageFilterExtension, ILMessageFilterQueryHandling {
    func handle(_ queryRequest: ILMessageFilterQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterQueryResponse) -> Void) {
        if let body = queryRequest.messageBody {
            SMSInbox.append(text: body)
        }
        let response = ILMessageFilterQueryResponse()
        response.action = .none
        completion(response)
    }
}
