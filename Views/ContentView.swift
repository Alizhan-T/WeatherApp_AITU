import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = WeatherViewModel()
    
    @State private var isCelsius = true
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter city (e.g. Almaty)", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .submitLabel(.search) // Кнопка "Search" на клавиатуре
                        .onSubmit {
                            Task { await viewModel.search() }
                        }
                    
                    Button(action: {
                        Task { await viewModel.search() }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                if viewModel.weather == nil && !viewModel.cities.isEmpty {
                    List(viewModel.cities) { city in
                        Button(action: {
                            Task { await viewModel.loadWeather(for: city) }
                        }) {
                            VStack(alignment: .leading) {
                                Text(city.name).font(.headline)
                                Text(city.country ?? "Unknown Country")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                if let weather = viewModel.weather {
                    ScrollView {
                        VStack(spacing: 20) {
                            
                            if viewModel.isOffline {
                                Text("OFFLINE MODE - Showing cached data")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                            
                            Picker("Unit", selection: $isCelsius) {
                                Text("°C").tag(true)
                                Text("°F").tag(false)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                            .padding(.top)
                            
                            VStack {
                                Image(systemName: getWeatherIcon(code: weather.current_weather.weathercode))
                                    .resizable()
                                    .renderingMode(.original)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                
                                let temp = weather.current_weather.temperature
                                let displayTemp = isCelsius ? temp : (temp * 9/5 + 32)
                                
                                Text("\(Int(round(displayTemp)))°\(isCelsius ? "C" : "F")")
                                    .font(.system(size: 70, weight: .bold))
                                
                                Text(String(format: "Wind: %.1f km/h", weather.current_weather.windspeed))
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            
                            Divider()
                            
                            Text("7-Day Forecast")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading)
                            
                            ForEach(0..<weather.daily.time.count, id: \.self) { index in
                                HStack {
                                    Text(weather.daily.time[index])
                                        .frame(width: 120, alignment: .leading)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(.orange)
                                    
                                    Spacer()
                                    
                                    let maxC = weather.daily.temperature_2m_max[index]
                                    let maxDisplay = isCelsius ? maxC : (maxC * 9/5 + 32)
                                    
                                    Text("\(Int(round(maxDisplay)))°")
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .frame(width: 40)
                                    
                                    let minC = weather.daily.temperature_2m_min[index]
                                    let minDisplay = isCelsius ? minC : (minC * 9/5 + 32)
                                    
                                    Text("\(Int(round(minDisplay)))°")
                                        .foregroundColor(.gray)
                                        .frame(width: 40)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Weather App")
        }
    }
    
    func getWeatherIcon(code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "smoke.fill"
        case 51...67: return "cloud.rain.fill"
        case 71...77: return "snow"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
