import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private let rootEntity = Entity()
    private let mazeEntity = Entity()
    @State private var collisionCancellable: EventSubscription?

    private let trackedJoints: [HandSkeleton.JointName] = [.indexFingerTip, .wrist]
    @State private var move = true
    @State private var lastMazePos = SIMD3<Float>(0, 1.3, -1)
    @State private var progress = 0.2
    
    private let userEntity = Entity()

    var body: some View {
        RealityView { content in
            if let loadedMaze = try? await Entity(named: "maze1col6")
            {
                mazeEntity.addChild(loadedMaze)
                mazeEntity.name = "Maze"
                mazeEntity.position = SIMD3<Float>(0, 0, -1)
                rootEntity.addChild(mazeEntity)
            }

            for jointName in trackedJoints {
                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.006),
                                            materials: [SimpleMaterial(color: .red, isMetallic: false)])
                sphere.name = "\(jointName)\(HandAnchor.Chirality.right)"
                rootEntity.addChild(sphere)
            }

            
            
            userEntity.name = "hitBox"
            userEntity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.15)]))
                userEntity.components.set(PhysicsBodyComponent(
                    massProperties: .init(shape: .generateSphere(radius: 0.15), density: 1),
                    material: .default,
                    mode: .kinematic
                ))
            rootEntity.addChild(userEntity)
            
            content.add(rootEntity)
            
            _ = content.subscribe(to: CollisionEvents.Began.self) { event in
                if event.entityA.name == "hitBox" || event.entityB.name == "hitBox" {
                    move = false
                    print("Detected Collision")
                }
            }
        }
        .task {
            try? await session.run([provider])
        }
        .task {
            for await update in provider.anchorUpdates {
                let handAnchor = update.anchor
                let cameraPos = handAnchor.originFromAnchorTransform.translation

                guard let indexJoint = handAnchor.handSkeleton?.joint(.indexFingerTip),
                      let wristJoint = handAnchor.handSkeleton?.joint(.wrist)
                else { continue }

                let indexPos = (handAnchor.originFromAnchorTransform * indexJoint.anchorFromJointTransform).translation
                let wristPos = (handAnchor.originFromAnchorTransform * wristJoint.anchorFromJointTransform).translation
                userEntity.position = cameraPos

                if let indexSphere = rootEntity.findEntity(named: "indexFingerTip\(HandAnchor.Chirality.right)") {
                    indexSphere.position = indexPos
                }
                if let wristSphere = rootEntity.findEntity(named: "wrist\(HandAnchor.Chirality.right)") {
                    wristSphere.position = wristPos
                }

                let deltaX = indexPos.x - wristPos.x
                let rotationDeadzone: Float = 0.1
                let rotationSensitivity: Float = 0.1
                let maxRotationSpeed: Float = 0.01

                if abs(deltaX) > rotationDeadzone && move{
                    lastMazePos = mazeEntity.position
                    let angle = max(-maxRotationSpeed, min(rotationSensitivity * deltaX, maxRotationSpeed))
                    let rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
                    let pivot = userEntity.position
                    let offset = mazeEntity.position - pivot
                    let rotatedOffset = rotation.act(offset)
                    mazeEntity.position = pivot + rotatedOffset
                    mazeEntity.orientation *= rotation
                }else if(!move){
                    mazeEntity.position = lastMazePos
                }

                let deltaY = indexPos.y - wristPos.y
                                let translationDeadzone: Float = 0.05
                                let topSensitivity: Float = 0.3
                                let bottomSensitivity: Float = 0.6
                                let maxTranslationSpeed: Float = 0.02

                if abs(deltaY) > translationDeadzone && move{
                    lastMazePos = mazeEntity.position
                    let direction: Float = deltaY > 0 ? -1 : 1
                    let amount: Float
                    if direction == -1 {
                        amount = direction * min(abs(deltaY) * topSensitivity, maxTranslationSpeed)
                    } else{
                        amount = direction * min(abs(deltaY) * bottomSensitivity, maxTranslationSpeed)
                    }
                    mazeEntity.position.z += amount
                }else if(!move){
                    mazeEntity.position = lastMazePos
                }
                
                move = true
            }
        }
        .overlay{
            VStack{
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                    .padding(.top, 40)
                    .padding(.horizontal, 30)
                Spacer()
            }
        }
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }
}
