//
//  SwipableImage.swift
//  Piccer
//
//  Created by Moritz Langenhan on 28.11.25.
//

import SwiftUI
import CoreLocation
import MapKit
import UIKit

struct SwipableImage: View {
    let image: UIImage
    let date: Date?
    let location: CLLocation?
    let onSwiped: () -> Void
    let onSwipedLeft: (() -> Void)? // Moved from property with default value to parameter without default inline
    @Binding var dragOffset: CGSize
    @State private var locationDescription: String? = nil

    init(image: UIImage,
         date: Date? = nil,
         location: CLLocation? = nil,
         onSwiped: @escaping () -> Void,
         onSwipedLeft: (() -> Void)? = nil,
         dragOffset: Binding<CGSize>) {
        self.image = image
        self.date = date
        self.location = location
        self.onSwiped = onSwiped
        self.onSwipedLeft = onSwipedLeft
        self._dragOffset = dragOffset
    }

    var body: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(18)
                .shadow(radius: 10)
                .padding(40)
            if let date = date {
                Text(Self.dateFormatter.string(from: date))
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
            if let location = location {
                if let locationDescription = locationDescription {
                    Text(locationDescription)
                        .font(.subheadline)
                        .foregroundColor(.black)
                } else {
                    Text("Loading location…")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 30)
        .offset(dragOffset)
        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation
                }
                .onEnded { _ in
                    var didSwipe = false
                    if dragOffset.width < -150 {
                        if let onSwipedLeft = onSwipedLeft {
                            onSwipedLeft()
                            didSwipe = true
                        } else {
                            onSwiped()
                            didSwipe = true
                        }
                    } else if dragOffset.width > 150 || abs(dragOffset.height) > 150 {
                        onSwiped()
                        didSwipe = true
                    }
                    if didSwipe {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    withAnimation {
                        dragOffset = .zero
                    }
                }
        )
        .onAppear {
            if let location = location, locationDescription == nil {
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemark = placemarks?.first {
                        let name = placemark.name ?? placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "Unknown Location"
                        locationDescription = name
                    } else {
                        locationDescription = "Unknown Location"
                    }
                }
            }
        }
        .onChange(of: location) { newLocation in
            locationDescription = nil
            if let location = newLocation {
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemark = placemarks?.first {
                        let name = placemark.name ?? placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "Unknown Location"
                        locationDescription = name
                    } else {
                        locationDescription = "Unknown Location"
                    }
                }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
