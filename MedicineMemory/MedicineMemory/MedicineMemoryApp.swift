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
    @StateObject private var medicineData = MedicineData.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicineData)
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        if granted {
                            print("Notifications permission granted")
                        } else {
                            print("Notifications permission denied")
                        }
                    }
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                }
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static var shared = NotificationDelegate()

    // Implement methods for handling notifications, if needed

    // This method is called when the app receives a notification while in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Handle foreground notification presentation here
        completionHandler([.alert, .sound])
    }

    // This method is called when the user interacts with a notification (e.g., taps on it)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle user interaction with notification here
        if let medicine = MedicineData.shared.medicines.first(where: { $0.id.uuidString == response.notification.request.identifier }) {
            MedicineData.shared.takeMedicine(medicine: medicine) // Subtract pillsPerDose from quantity
        }

        completionHandler()
    }
}

class MedicineData: ObservableObject {
    static var shared = MedicineData()

    @Published var medicines: [Medicine] = []

    func takeMedicine(medicine: Medicine) {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            var updatedMedicine = medicines[index]
            updatedMedicine.takeMedicine()
            medicines[index] = updatedMedicine

            // Print statements for debugging
            print("Before: Quantity for \(medicine.name): \(medicine.quantity)")
            print("After: Quantity for \(updatedMedicine.name): \(updatedMedicine.quantity)")

            // Reschedule the notification after updating the quantity
            scheduleNotification(for: updatedMedicine)
        }
    }

    // Function to schedule a notification for a given medicine
    func scheduleNotification(for medicine: Medicine) {
        let content = UNMutableNotificationContent()
        content.title = "Time to take \(medicine.name)"
        content.body = "Don't forget to take your \(medicine.dosage)"

        // Set the trigger based on the medicine's timePerDose
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: medicine.timePerDose)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // Create a unique identifier for the notification based on the medicine's ID
        let identifier = medicine.id.uuidString

        // Remove the existing notification for the medicine, if any
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        // Create the notification request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully")
            }
        }
    }
}

struct Medicine: Identifiable {
    var id = UUID()
    var name: String
    var dosage: String
    var quantity: Int
    var expirationDate: Date
    var pillsPerDose: Int
    var selectedDaysOfWeek: Set<Int>
    var timePerDose: Date

    mutating func takeMedicine() {
        if quantity >= pillsPerDose {
            quantity -= pillsPerDose
        } else {
            quantity = 0
        }
    }
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
                .onDelete(perform: deleteMedicine)
            }
            .navigationTitle("Medicine Memory")
            .navigationBarItems(
                trailing: HStack {
                    EditButton()
                    Button(action: {
                        showingAddMedicineView.toggle()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            )
        }
        .sheet(isPresented: $showingAddMedicineView) {
            AddMedicineView()
        }
    }

    func deleteMedicine(at offsets: IndexSet) {
        medicineData.medicines.remove(atOffsets: offsets)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicineData.shared)
    }
}

struct MedicineDetail: View {
    var medicine: Medicine

    var body: some View {
        Form {
            Section(header: Text("\(medicine.name) Details")) {
                Text("Name: \(medicine.name)")
                Text("Dosage: \(medicine.dosage)")
                Text("Quantity: \(medicine.quantity)")
                Text("Expiration Date: \(formattedDate)")
                Text("Pills Per Dose: \(medicine.pillsPerDose)")
                Text("Days Per Dose: \(formattedDaysOfWeek)")
                Text("Time Per Dose: \(formattedTime)")
            }
        }
        .navigationTitle("Medicine Details")
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: medicine.expirationDate)
    }

    private var formattedDaysOfWeek: String {
        let daysOfWeek = medicine.selectedDaysOfWeek
            .map { DateFormatter().weekdaySymbols[$0] }
            .joined(separator: ", ")
        return daysOfWeek.isEmpty ? "Not set" : daysOfWeek
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: medicine.timePerDose)
    }
}

struct AddMedicineView: View {
    @EnvironmentObject var medicineData: MedicineData
    @State private var name = ""
    @State private var dosage = ""
    @State private var quantity = ""
    @State private var expirationDate = Date()
    @State private var pillsPerDose = ""
    @State private var selectedDaysOfWeek: Set<Int> = []
    @State private var timePerDose = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medicine Details")) {
                    TextField("Medicine Name", text: $name)
                    TextField("Dosage", text: $dosage)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    TextField("Pills Per Dose", text: $pillsPerDose)
                        .keyboardType(.numberPad)
                }

                Section(header: Text("Days Per Dose")) {
                    List(0..<7, id: \.self) { index in
                        Button(action: {
                            if selectedDaysOfWeek.contains(index) {
                                selectedDaysOfWeek.remove(index)
                            } else {
                                selectedDaysOfWeek.insert(index)
                            }
                        }) {
                            HStack {
                                Text(DateFormatter().weekdaySymbols[index])
                                Spacer()
                                if selectedDaysOfWeek.contains(index) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Time Per Dose")) {
                    DatePicker("Time Per Dose", selection: $timePerDose, displayedComponents: .hourAndMinute)
                }

                Button(action: {
                    if let quantity = Int(self.quantity),
                       let pillsPerDose = Int(self.pillsPerDose) {

                        let medicine = Medicine(
                            name: name,
                            dosage: dosage,
                            quantity: quantity,
                            expirationDate: expirationDate,
                            pillsPerDose: pillsPerDose,
                            selectedDaysOfWeek: selectedDaysOfWeek,
                            timePerDose: timePerDose
                        )
                        medicineData.medicines.append(medicine)

                        // Schedule notification for the added medicine
                        scheduleNotification(for: medicine)
                    }
                }) {
                    Text("Add Medicine")
                }
            }
            .navigationTitle("Add Medicine")
        }
    }

    // Function to schedule a notification for a given medicine
    func scheduleNotification(for medicine: Medicine) {
        let content = UNMutableNotificationContent()
        content.title = "Time to take \(medicine.name)"
        content.body = "Don't forget to take your \(medicine.dosage)"

        // Set the trigger based on the medicine's timePerDose
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: medicine.timePerDose)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // Create a unique identifier for the notification based on the medicine's ID
        let identifier = medicine.id.uuidString

        // Remove the existing notification for the medicine, if any
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        // Create the notification request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully")
            }
        }
    }
}
