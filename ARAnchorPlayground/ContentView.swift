//
//  ContentView.swift
//  ARAnchorPlayground
//
//  Created by Nien Lam on 10/13/21.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    let uiSignal = PassthroughSubject<UISignal, Never>()
    
    // Variable for tracking ambient light intensity.
    @Published var ambientIntensity: Double = 0

    enum UISignal {
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView, ARSessionDelegate {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var subscriptions = Set<AnyCancellable>()
    
    // Dictionary for tracking image anchors.
    var imageAnchorToEntity: [ARImageAnchor: AnchorEntity] = [:]
    
    // Example box entity.
    var boxEntity: ModelEntity!

    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
    }
    
    func setupScene() {
        // Setup world tracking and image detection.
        let configuration = ARImageTrackingConfiguration()
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]

        let targetImage    = "itp-logo.jpg"
        let physicalWidth  = 0.1524
        
        if let refImage = UIImage(named: targetImage)?.cgImage {

            let arReferenceImage = ARReferenceImage(refImage, orientation: .up, physicalWidth: physicalWidth)

            // Assign name to image reference.
            arReferenceImage.name = "Image Alpha"

            var set = Set<ARReferenceImage>()
            set.insert(arReferenceImage)
            configuration.trackingImages = set
        } else {
            print("❗️ Error loading target image")
        }
        

        arView.session.run(configuration)
        
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            self.renderLoop()
        }.store(in: &subscriptions)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)

        // Set session delegate.
        arView.session.delegate = self
    }
    
    // Hide/Show active tetromino.
    func processUISignal(_ signal: ViewModel.UISignal) {
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARImageAnchor }.forEach {

            if let imageName = $0.referenceImage.name {
                // Extract name when image anchor is detected / set.
                print(imageName)
            }

            // Create anchor from image.
            let anchorEntity = AnchorEntity(anchor: $0)
            
            // Track image anchors added to scene.
            imageAnchorToEntity[$0] = anchorEntity
            
            // Add anchor to scene.
            arView.scene.addAnchor(anchorEntity)
            
            // Call setup method for entities.
            // IMPORTANT: Play USDZ animations after entity is added to the scene.
            setupEntities(anchorEntity: anchorEntity)
        }
    }


    func setupEntities(anchorEntity: AnchorEntity) {
        // Checker material.
        var checkerMaterial = PhysicallyBasedMaterial()
        let texture = PhysicallyBasedMaterial.Texture.init(try! .load(named: "checker.png"))
        checkerMaterial.baseColor.texture = texture

        // Setup example box entity.
        let boxMesh = MeshResource.generateBox(size: [0.1, 0.1, 0.1], cornerRadius: 0.0)
        boxEntity = ModelEntity(mesh: boxMesh, materials: [checkerMaterial])

        // Position and add box entity to anchor.
        boxEntity.position.y = 0.05
        anchorEntity.addChild(boxEntity)
    }
    

    func renderLoop() {
        // Spin boxEntity if available.
        if let box = boxEntity {
            box.orientation *= simd_quatf(angle: 0.02, axis: [0, 1, 0])
        }
    }
}
