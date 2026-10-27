import SwiftUI

// Entry list for the Advanced screens. Each group lives in its own file in this folder.

struct AdvancedBankingHub: View {
    var body: some View {
        List {
            Section("Money movement") {
                NavigationLink("Scheduled & standing instructions") { ScheduledTransfersView() }
                NavigationLink("Request / split money") { RequestMoneyView() }
                NavigationLink("International wire quote") { InternationalWireView() }
                NavigationLink("Round-up savings") { RoundUpSavingsView() }
            }
            Section("Planning") {
                NavigationLink("Savings goals") { SavingsGoalsView() }
                NavigationLink("Envelopes") { EnvelopesView() }
                NavigationLink("Bill calendar") { BillCalendarView() }
                NavigationLink("Net worth") { NetWorthView() }
                NavigationLink("What-if loan") { WhatIfLoanView() }
            }
            Section("Cards & cash") {
                NavigationLink("Virtual cards") { VirtualCardsView() }
                NavigationLink("Cardless ATM") { CardlessATMView() }
                NavigationLink("Replace physical card") { CardReissueView() }
            }
            Section("Documents") {
                NavigationLink("Statements") { StatementsView() }
                NavigationLink("Tax certificates") { TaxDocumentsView() }
                NavigationLink("Document vault") { DocumentVaultView() }
                NavigationLink("e-Sign consents") { ESignView() }
            }
            Section("Trust") {
                NavigationLink("Devices") { DeviceManagementView() }
                NavigationLink("Security activity") { SecurityActivityView() }
                NavigationLink("Limits") { LimitSettingsView() }
                NavigationLink("Disputes") { DisputesInboxView() }
                NavigationLink("Family / joint access") { FamilyAccountsView() }
                NavigationLink("Offers") { MerchantOffersView() }
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Advanced")
    }
}
