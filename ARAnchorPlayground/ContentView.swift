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

    enum UISignal {
        case reset
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)
            
            // Reset button.
            Button {
                viewModel.uiSignal.send(.reset)
            } label: {
                Label("Reset", systemImage: "gobackward")
                    .font(.system(.title2).weight(.medium))
                    .foregroundColor(.white)
                    .labelStyle(IconOnlyLabelStyle())
                    .frame(width: 30, height: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
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
    var originAnchor: AnchorEntity!
    var pov: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()

    // Dictionary for tracking image anchors.
    var imageAnchorToEntity: [ARImageAnchor: AnchorEntity] = [:]


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
        
        setupEntities()
    }
    

    func setupScene() {
        // Setup world tracking and image detection.
        let configuration = ARWorldTrackingConfiguration()
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]

        // Create set hold target image references.
        var set = Set<ARReferenceImage>()

        // Setup target image A.
        if let detectionImage = makeDetectionImage(named: "itp-logo.jpg",
                                                   referenceName: "IMAGE_ALPHA",
                                                   physicalWidth: 0.18415) {
            set.insert(detectionImage)
        }

        // Setup target image B.
        if let detectionImage = makeDetectionImage(named: "dino.jpg",
                                                   referenceName: "IMAGE_BETA",
                                                   physicalWidth: 0.19) {
            set.insert(detectionImage)
        }


        // Add target images to configuration.
        configuration.detectionImages = set
        configuration.maximumNumberOfTrackedImages = 2

        // Run configuration.
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
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


    // Helper method for creating a detection image.
    func makeDetectionImage(named: String, referenceName: String, physicalWidth: CGFloat) -> ARReferenceImage? {
        guard let targetImage = UIImage(named: named)?.cgImage else {
            print("❗️ Error loading target image:", named)
            return nil
        }

        let arReferenceImage  = ARReferenceImage(targetImage, orientation: .up, physicalWidth: physicalWidth)
        arReferenceImage.name = referenceName

        return arReferenceImage
    }


    // Process UI signals.
    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {
        case .reset:
            print("👇 Did press reset button")
            
            // Reset scene and all anchors.
            arView.scene.anchors.removeAll()
            subscriptions.removeAll()
            
            setupScene()
            setupEntities()
        }
    }


    // Called when an anchor is added to scene.
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Handle image anchors.
        anchors.compactMap { $0 as? ARImageAnchor }.forEach {
            // Grab reference image name.
            guard let referenceImageName = $0.referenceImage.name else { return }

            // Create anchor and place at image location.
            let anchorEntity = AnchorEntity(world: $0.transform)
            arView.scene.addAnchor(anchorEntity)
            
            // Setup logic based on reference image.
            if referenceImageName == "IMAGE_ALPHA" {
                setupEntitiesForImageAlpha(anchorEntity: anchorEntity)
            } else if referenceImageName == "IMAGE_BETA" {
                setupEntitiesForImageBeta(anchorEntity: anchorEntity)
            }
        }
    }


    // Setup method for non image anchor entities.
    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)

        // Add yellow marker to origin anchor.
        originAnchor.addChild(makeBoxMarker(color: .yellow))
        
        // Add pov entity that follows the camera.
        pov = AnchorEntity(.camera)
        arView.scene.addAnchor(pov)
    }


    // IMPORTANT: Attach to anchor entity. Called when image target is found.

    func setupEntitiesForImageAlpha(anchorEntity: AnchorEntity) {
        // Add red marker to alpha anchor.
        let marker = makeBoxMarker(color: .red)
        anchorEntity.addChild(marker)

    }

    func setupEntitiesForImageBeta(anchorEntity: AnchorEntity) {
        // Add green marker to beta anchor.
        let marker = makeBoxMarker(color: .green)
        anchorEntity.addChild(marker)

    }


    // Render loop.
    func renderLoop() {
        
    }


    // Helper method for making box to mark anchor position.
    func makeBoxMarker(color: UIColor) -> Entity {
        let boxMesh   = MeshResource.generateBox(size: 0.025, cornerRadius: 0.002)
        let material  = SimpleMaterial(color: color, isMetallic: false)
        return ModelEntity(mesh: boxMesh, materials: [material])
    }
}
