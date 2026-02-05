import Foundation
import SwiftUI
import Combine

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var cities: [City] = []
    @Published var weather: WeatherResponse?
    @Published var errorMessage: String?
    @Published var isOffline = false
    @Published var lastUpdateString: String = ""
    
    private let service = WeatherService()
    
    func search() async {
        guard !searchText.isEmpty else { return }
        self.weather = nil
        self.errorMessage = nil
        
        do {
            let results = try await service.searchCity(name: searchText)
            self.cities = results
            if results.isEmpty { self.errorMessage = "City not found" }
        } catch {
            self.errorMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    func loadWeather(for city: City) async {
        do {
            let data = try await service.fetchWeather(lat: city.latitude, lon: city.longitude)
            self.weather = data
            self.isOffline = false
            self.errorMessage = nil
            
            let now = Date()
            updateTimeString(date: now)
            saveToCache(data, date: now)
        } catch {
            print("Network failed, checking cache...")
            loadFromCache()
        }
    }
    
    private func updateTimeString(date: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.lastUpdateString = "Updated: \(formatter.string(from: date))"
    }
    
    
    private func saveToCache(_ data: WeatherResponse, date: Date) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cachedWeather")
            UserDefaults.standard.set(date, forKey: "cachedDate")
        }
    }
    
    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: "cachedWeather"),
           let decoded = try? JSONDecoder().decode(WeatherResponse.self, from: data) {
            self.weather = decoded
            self.isOffline = true
            
            if let date = UserDefaults.standard.object(forKey: "cachedDate") as? Date {
                updateTimeString(date: date)
            } else {
                self.lastUpdateString = "Unknown update time"
            }
        } else {
            self.errorMessage = "No internet & no cache found."
        }
    }
}
