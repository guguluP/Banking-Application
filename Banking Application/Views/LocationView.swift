import SwiftUI
import MapKit

struct LocationView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.2963, longitude: 85.8248),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var locations: [BankLocation] = [
        BankLocation(id: "loc_001", name: "Bhubaneswar Main Branch", locationType: .branch, address: Address(street: "123 Janpath Rd", city: "Bhubaneswar", state: "OD", postalCode: "751001", country: "India"), phoneNumber: "+91 674 5551234", services: [.cashDeposit, .cashWithdrawal, .checkDeposit, .billPayment], latitude: 20.2963, longitude: 85.8248, hours: ["Mon-Fri": "9:00 AM - 5:00 PM", "Sat": "9:00 AM - 1:00 PM", "Sun": "Closed"], isOpenNow: true, distance: nil),
        BankLocation(id: "loc_002", name: "Cuttack ATM", locationType: .atm, address: Address(street: "456 Link Rd", city: "Cuttack", state: "OD", postalCode: "753001", country: "India"), phoneNumber: "+91 671 5555678", services: [.cashWithdrawal, .checkDeposit], latitude: 20.4627, longitude: 85.8960, hours: ["Mon-Sun": "24 Hours"], isOpenNow: true, distance: nil),
        BankLocation(id: "loc_003", name: "Puri Branch", locationType: .atmAndBranch, address: Address(street: "789 Marine Dr", city: "Puri", state: "OD", postalCode: "751002", country: "India"), phoneNumber: "+91 675 5559012", services: [.cashDeposit, .cashWithdrawal, .checkDeposit, .billPayment, .foreignExchange], latitude: 19.8135, longitude: 85.8329, hours: ["Mon-Sat": "10:00 AM - 8:00 PM", "Sun": "11:00 AM - 6:00 PM"], isOpenNow: true, distance: nil)
    ]
    @State private var selectedLocation: BankLocation?
    @State private var showingLocationDetail = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Map(position: $position) {
                        ForEach(locations) { location in
                            Annotation(location.name, coordinate: location.coordinate) {
                                LocationAnnotationView(location: location)
                            }
                        }
                    }
                    .frame(height: 300)
                    .cornerRadius(AppTheme.CornerRadius.medium)
                    .padding(.horizontal)
                    .shadow(color: AppShadows.medium.color, radius: AppShadows.medium.radius, x: AppShadows.medium.x, y: AppShadows.medium.y)
                    
                    GlassCard {
                        SearchBar(text: $searchText)
                    }
                    .padding()
                    
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(filteredLocations) { location in
                            LocationRow(location: location)
                                .onTapGesture {
                                    selectedLocation = location
                                    showingLocationDetail = true
                                }
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("ATM & Branch Locator")
            .sheet(isPresented: $showingLocationDetail) {
                if let location = selectedLocation {
                    LocationDetailView(location: location)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    var filteredLocations: [BankLocation] {
        if searchText.isEmpty {
            return locations
        } else {
            return locations.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.city.localizedCaseInsensitiveContains(searchText) ||
                $0.address.state.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct LocationAnnotationView: View {
    let location: BankLocation
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: locationIcon)
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(locationColor)
                .cornerRadius(AppTheme.CornerRadius.pill)
                .shadow(color: AppShadows.small.color, radius: AppShadows.small.radius, x: AppShadows.small.x, y: AppShadows.small.y)
            
            Text(location.name)
                .font(.caption2)
                .padding(4)
                .background(Color(UIColor.systemBackground).opacity(0.8))
                .cornerRadius(4)
        }
    }
    
    private var locationIcon: String {
        switch location.locationType {
        case .atm: return "creditcard.fill"
        case .branch: return "building.columns.fill"
        case .atmAndBranch: return "building.2.fill"
        }
    }
    
    private var locationColor: Color {
        switch location.locationType {
        case .atm: return .blue
        case .branch: return .green
        case .atmAndBranch: return .purple
        }
    }
}

struct LocationRow: View {
    let location: BankLocation
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: locationIcon)
                        .foregroundColor(locationColor)
                        .frame(width: 30, height: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name)
                            .font(.headline)
                        
                        Text(location.address.street)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                            Text("\(location.address.city), \(location.address.state)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    StatusPill(isOpen: location.isOpenNow)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(location.services, id: \.self) { service in
                            Text(service.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.bankPrimary.opacity(0.1))
                                .cornerRadius(AppTheme.CornerRadius.pill)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var locationIcon: String {
        switch location.locationType {
        case .atm: return "creditcard.fill"
        case .branch: return "building.columns.fill"
        case .atmAndBranch: return "building.2.fill"
        }
    }
    
    private var locationColor: Color {
        switch location.locationType {
        case .atm: return .blue
        case .branch: return .green
        case .atmAndBranch: return .purple
        }
    }
}

struct StatusPill: View {
    let isOpen: Bool
    
    var body: some View {
        Text(isOpen ? "Open" : "Closed")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isOpen ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(isOpen ? .green : .red)
            .cornerRadius(AppTheme.CornerRadius.pill)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search locations", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(AppTheme.CornerRadius.pill)
    }
}

struct LocationDetailView: View {
    let location: BankLocation
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Name", value: location.name)
                            InfoRow(label: "Type", value: location.locationType.rawValue)
                            InfoRow(label: "Address", value: "\(location.address.street), \(location.address.city)")
                            InfoRow(label: "Phone", value: location.phoneNumber)
                            InfoRow(label: "Hours", value: location.formattedHours)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Services")
                                .font(.headline)
                            
                            ForEach(location.services, id: \.self) { service in
                                HStack(spacing: 8) {
                                    Image(systemName: serviceIcon(service))
                                        .foregroundColor(Color.bankPrimary)
                                    Text(service.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
                .padding(.vertical)
            }
            .navigationTitle(location.name)
            .toolbar {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close location details")
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    private func serviceIcon(_ service: ServiceType) -> String {
        switch service {
        case .cashDeposit: return "banknote"
        case .cashWithdrawal: return "indianrupee.sign"
        case .checkDeposit: return "doc.on.clipboard"
        case .billPayment: return "indianrupee"
        case .foreignExchange: return "creditcard"
        case .notary: return "doc.text"
        case .safeDepositBox: return "lock.fill"
        }
    }
    
    private func openInMaps() {
        let mapItem = MKMapItem(location: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), address: nil)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

struct LocationView_Previews: PreviewProvider {
    static var previews: some View {
        LocationView()
    }
}