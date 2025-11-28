//
//  PhotoBrowser.swift
//  Piccer
//
//  Created by Moritz Langenhan on 28.11.25.
//

import SwiftUI
import Photos
import CoreLocation

struct PhotoWithInfo {
    let image: UIImage
    let asset: PHAsset
    let date: Date?
    let location: CLLocation?
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

struct PhotoBrowser: View {
    @State private var images: [PhotoWithInfo] = []
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var isLoading: Bool = true
    @State private var dragOffset: CGSize = .zero
    @State private var showDeletePermissionAlert: Bool = false

    // Helper to detect preview mode
    var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // Helper property to check if user can delete photos
    var canDeletePhotos: Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(hex: 0xdfdfdf)
                        .ignoresSafeArea()
                    
                    let maxPull = geometry.size.width
                    
                    // ensures that offset is within [-maxPull, maxPull]
                    let clamped = max(min(dragOffset.width, maxPull), -maxPull)

                    // Widths of the small bars
                    let greenRectWidth: CGFloat = 50
                    let redRectWidth: CGFloat = 50

                    // Full screen when offset is half the screen size
                    let expansionTrigger = geometry.size.width / 2
                    
                    // scale value for full screening the rects
                    let fullCoverScaleGreen = geometry.size.width / greenRectWidth
                    let fullCoverScaleRed   = geometry.size.width / redRectWidth

                    // Slide-out offsets
                    let slideOffsetGreen: CGFloat = clamped < 0 ? 100 : 0    // move green rect right when dragging left
                    let slideOffsetRed: CGFloat = clamped > 0 ? -100 : 0   // move red rect left when dragging right

                    // --- GREEN BAR ---
                    Rectangle()
                        .fill(Color(hex: 0x058C42))
                        .frame(width: greenRectWidth, height: geometry.size.height * 2)
                        .scaleEffect(
                            x: clamped > 0
                                ? 1 + (min(clamped, expansionTrigger) / expansionTrigger) * (fullCoverScaleGreen - 1)
                                : 0,
                            y: 1,
                            anchor: .trailing
                        )
                        .offset(x: slideOffsetGreen)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .ignoresSafeArea()

                    // --- RED BAR ---
                    Rectangle()
                        .fill(Color(hex: 0x920004))
                        .frame(width: redRectWidth, height: geometry.size.height * 2)
                        .scaleEffect(
                            x: clamped < 0
                                ? 1 + (min(-clamped, expansionTrigger) / expansionTrigger) * (fullCoverScaleRed - 1)
                                : 0,
                            y: 1,
                            anchor: .leading
                        )
                        .offset(x: slideOffsetRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ignoresSafeArea()

                    VStack {
                        
                        Text("Piccer")
                            .font(.custom("Brother-Signature", size: 96))
                            .fontWeight(.semibold)
                            .padding(10)
                        
                        if isLoading {
                            ProgressView("Loading photos…")
                        } else if authorizationStatus == .denied || authorizationStatus == .restricted || authorizationStatus == .limited {
                            Text("Access to photos is limited or denied.\nPlease enable full access in Settings to delete photos.")
                                .multilineTextAlignment(.center)
                                .padding()
                        } else if let currentImage = images.first {

                            SwipableImage(
                                image: currentImage.image,
                                date: currentImage.date,
                                location: currentImage.location,
                                onSwiped: { removeFirstImage() },
                                onSwipedLeft: { deleteCurrentPhoto() },
                                dragOffset: $dragOffset
                            )
                            .padding(.top, 40)
                            .padding(.bottom, 40)
                            
                            Button("", systemImage: "star.fill", action: favoriteCurrentPhoto)
                            
                        } else {
                            Text("No more photos")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        
                    }
                }
            }
            .onAppear {
                if !isPreview {
                    requestPhotoAccessAndLoad()
                } else {
                    // Provide mock data for previews
                    images = [PhotoWithInfo(image: UIImage(systemName: "photo")!, asset: PHAsset(), date: Date(), location: nil)]
                    isLoading = false
                    authorizationStatus = .authorized
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("", systemImage: "gearshape.fill") {
                        print("Settings tapped")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("", systemImage: "star") {
                        print("Favorites tapped")
                    }
                }
            }
            .alert("Insufficient Permissions", isPresented: $showDeletePermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You need to grant full photo library access in Settings to delete photos.")
            }
        }
    }
    
    func favorise() {
        print("lol")
    }
    
    func deleteCurrentPhoto() {
        guard canDeletePhotos else {
            // Show alert if user does not have permission to delete photos
            showDeletePermissionAlert = true
            return
        }
        guard let asset = images.first?.asset else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success { removeFirstImage() }
            }
        }
    }
    
    func favoriteCurrentPhoto() {
        guard let asset = images.first?.asset else { return }
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = true
        }) { success, error in
            // Optionally update UI or give feedback
        }
    }

    func removeFirstImage() {
        if !images.isEmpty {
            images.removeFirst()
        }
    }

    func requestPhotoAccessAndLoad() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    authorizationStatus = status
                    if status == .authorized || status == .limited {
                        if status == .limited {
                            print("Photo library access is limited. You can view photos but deletion requires full access. Please update permissions in Settings.")
                        }
                        loadLatestImages()
                    } else {
                        isLoading = false
                    }
                }
            }
        } else {
            authorizationStatus = currentStatus
            if currentStatus == .authorized || currentStatus == .limited {
                if currentStatus == .limited {
                    print("Photo library access is limited. You can view photos but deletion requires full access. Please update permissions in Settings.")
                }
                loadLatestImages()
            } else {
                isLoading = false
            }
        }
    }

    func loadLatestImages(limit: Int = 25) {
        isLoading = true
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        fetchOptions.fetchLimit = limit
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        let imageManager = PHImageManager.default()
        var loaded: [PhotoWithInfo] = []
        let targetSize = CGSize(width: 800, height: 800)
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat

        assets.enumerateObjects { asset, _, _ in
            imageManager.requestImage(for: asset,
                                      targetSize: targetSize,
                                      contentMode: .aspectFit,
                                      options: requestOptions) { image, _ in
                if let image = image {
                    let photoInfo = PhotoWithInfo(image: image, asset: asset, date: asset.creationDate, location: asset.location)
                    loaded.append(photoInfo)
                }
                if loaded.count == assets.count {
                    DispatchQueue.main.async {
                        self.images = loaded
                        self.isLoading = false
                    }
                }
            }
        }
        // If there are no assets, update state immediately
        if assets.count == 0 {
            DispatchQueue.main.async {
                self.images = []
                self.isLoading = false
            }
        }
    }
}

#Preview {
    PhotoBrowser()
}
