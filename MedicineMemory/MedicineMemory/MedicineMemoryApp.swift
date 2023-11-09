//
//  MedicineMemoryApp.swift
//  MedicineMemory
//
//  Created by Quetzin Pimentel on 10/23/23.
//

import SwiftUI
import UIKit
import UserNotifications

@main
struct MedicineMemoryApp: App {
    @StateObject private var medicineData = MedicineData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicineData)
        }
    }
}

class MedicineData: ObservableObject {
    @Published var medicines: [Medicine] = []
}

struct Medicine: Identifiable {
    let id = UUID()
    var name: String
    var dosage: String
    var quantity: Int
    var expirationDate: Date
}

struct ContentView: View {
    @EnvironmentObject var medicineData: MedicineData
    @State private var showingAddMedicineView = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(medicineData.medicines) { medicine in
                    NavigationLink(destination: MedicineDetail(medicine: medicine)) {
                        Text("\(medicine.name) - \(medicine.dosage)")
                    }
                }
            }
            .navigationTitle("Medicine Reminder")
            .navigationBarItems(trailing:
                Button(action: {
                    showingAddMedicineView.toggle()
                }) {
                    Image(systemName: "plus")
                }
            )
        }
        .sheet(isPresented: $showingAddMedicineView) {
            AddMedicineView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicineData())
    }
}

struct MedicineDetail: View {
    var medicine: Medicine
    
    var body: some View {
        Form {
            Section(header: Text("Medicine Details")) {
                Text("Name: \(medicine.name)")
                Text("Dosage: \(medicine.dosage)")
                Text("Quantity: \(medicine.quantity)")
                Text("Expiration Date: \(formattedDate)")
            }
        }
        .navigationTitle("Medicine Detail")
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: medicine.expirationDate)
    }
}

struct AddMedicineView: View {
    @EnvironmentObject var medicineData: MedicineData
    @State private var name = ""
    @State private var dosage = ""
    @State private var quantity = ""
    @State private var expirationDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medicine Details")) {
                    TextField("Medicine Name", text: $name)
                    TextField("Dosage", text: $dosage)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                }
                
                Button(action: {
                    if let quantity = Int(self.quantity) {
                        let medicine = Medicine(name: name, dosage: dosage, quantity: quantity, expirationDate: expirationDate)
                        medicineData.medicines.append(medicine)
                    }
                }) {
                    Text("Add Medicine")
                }
            }
            .navigationTitle("Add Medicine")
        }
    }
}
