import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = WeatherViewModel()
    @State private var unit: TemperatureUnit = .celsius

    private let quickCities = ["Almaty", "Astana", "Tokyo", "London", "New York"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if viewModel.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading forecast...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                }

                if viewModel.weather == nil && !viewModel.cities.isEmpty {
                    cityResultsList
                } else if let weather = viewModel.weather, let current = weather.current {
                    weatherDetailScroll(weather: weather, current: current)
                } else if !viewModel.isLoading {
                    emptyStateView
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("Weather")
            .task {
                viewModel.restoreLastCachedIfAvailable()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            TextField("Search city (e.g. Almaty, Tokyo)", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            Button {
                Task { await viewModel.search() }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isLoading)
            .accessibilityLabel("Search city")
        }
        .padding()
    }

    private var cityResultsList: some View {
        List(viewModel.cities) { city in
            Button {
                Task { await viewModel.loadWeather(for: city) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(city.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(city.displaySubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.multicolor)
            Text("Check Live Weather")
                .font(.title2.bold())
            Text("Search any city worldwide for live conditions and a 7-day Open-Meteo forecast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCities, id: \.self) { city in
                        Button(city) {
                            viewModel.searchText = city
                            Task { await viewModel.search() }
                        }
                        .buttonStyle(.bordered)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }

    private func weatherDetailScroll(weather: WeatherResponse, current: CurrentData) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if viewModel.isOffline {
                    Label("OFFLINE MODE — Showing cached forecast", systemImage: "wifi.slash")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }

                if let city = viewModel.selectedCity {
                    VStack(spacing: 4) {
                        Text(city.name)
                            .font(.largeTitle.bold())
                        Text(city.displaySubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.lastUpdateString.isEmpty {
                    Text(viewModel.lastUpdateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Temperature Unit", selection: $unit) {
                    ForEach(TemperatureUnit.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                VStack(spacing: 10) {
                    Image(systemName: WeatherCondition.symbol(for: current.weather_code))
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 108, height: 108)

                    Text(unit.formattedTemperature(current.temperature_2m))
                        .font(.system(size: 68, weight: .bold, design: .rounded))

                    Text(WeatherCondition.description(for: current.weather_code))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 28) {
                        metricBadge(
                            icon: "wind",
                            label: "Wind",
                            value: unit.formattedWind(kmh: current.wind_speed_10m)
                        )
                        metricBadge(
                            icon: "humidity.fill",
                            label: "Humidity",
                            value: "\(current.relative_humidity_2m)%"
                        )
                    }
                    .padding(.top, 6)
                }
                .padding()

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("7-Day Forecast")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(weather.daily.forecastDays) { day in
                        HStack {
                            Text(day.formattedDate)
                                .frame(width: 112, alignment: .leading)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Image(systemName: WeatherCondition.symbol(for: day.weatherCode))
                                .renderingMode(.original)
                                .font(.title3)

                            Spacer()

                            Text(unit.formattedTemperature(day.maxCelsius))
                                .fontWeight(.bold)
                                .frame(width: 48, alignment: .trailing)

                            Text(unit.formattedTemperature(day.minCelsius))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func metricBadge(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.title3)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 110)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
