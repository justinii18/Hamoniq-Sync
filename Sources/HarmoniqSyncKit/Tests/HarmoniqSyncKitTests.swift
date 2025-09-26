//
//  HarmoniqSyncKitTests.swift
//  HarmoniqSyncKitTests
//
//  Basic tests for HarmoniqSyncKit package
//

import XCTest
@testable import HarmoniqSyncKit

final class HarmoniqSyncKitTests: XCTestCase {
    
    func testPackageImport() throws {
        // Test that we can import the package successfully
        XCTAssertTrue(true)
    }
    
    func testConfigurationCreation() throws {
        let config = SyncConfiguration.standard
        XCTAssertEqual(config.confidenceThreshold, 0.7)
        XCTAssertEqual(config.windowSize, 1024)
        XCTAssertEqual(config.noiseGateDb, -40.0)
        XCTAssertTrue(config.enableDriftCorrection)
    }
    
    func testConfigurationValidation() throws {
        let config = SyncConfiguration.standard
        try config.validate(for: 44100.0)
        // Should not throw
    }
    
    func testInvalidConfiguration() throws {
        let invalidConfig = SyncConfiguration(
            confidenceThreshold: -1.0,  // Invalid
            windowSize: 1024
        )
        
        XCTAssertThrowsError(try invalidConfig.validate(for: 44100.0)) { error in
            XCTAssertTrue(error is SyncEngineError)
        }
    }
    
    func testAlignmentMethodEnum() throws {
        let method = AlignmentMethod.spectralFlux
        XCTAssertEqual(method.displayName, "Spectral Flux")
        XCTAssertEqual(method.rawValue, "spectral_flux")
    }
    
    func testContentTypeRecommendations() throws {
        XCTAssertEqual(AlignmentMethod.recommended(for: .music), .chroma)
        XCTAssertEqual(AlignmentMethod.recommended(for: .speech), .mfcc)
        XCTAssertEqual(AlignmentMethod.recommended(for: .unknown), .hybrid)
    }
    
    func testConfigurationPresets() throws {
        let musicConfig = SyncConfiguration.music
        XCTAssertEqual(musicConfig.windowSize, 4096)
        XCTAssertEqual(musicConfig.noiseGateDb, -50.0)
        
        let speechConfig = SyncConfiguration.speech
        XCTAssertEqual(speechConfig.windowSize, 1024)
        XCTAssertEqual(speechConfig.noiseGateDb, -35.0)
    }
    
    func testConfigurationBuilder() throws {
        let config = try SyncConfigurationBuilder()
            .confidenceThreshold(0.8)
            .windowSize(2048)
            .noiseGate(-50.0)
            .build()
        
        XCTAssertEqual(config.confidenceThreshold, 0.8)
        XCTAssertEqual(config.windowSize, 2048)
        XCTAssertEqual(config.noiseGateDb, -50.0)
    }
    
    func testAudioDecodingConfiguration() throws {
        let config = AudioDecodingConfiguration.standard
        XCTAssertEqual(config.targetSampleRate, 44100.0)
        XCTAssertTrue(config.monoMix)
        XCTAssertTrue(config.normalize)
    }
    
    func testErrorTypes() throws {
        let error = SyncEngineError.invalidInput("Test error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testProgressStages() throws {
        let progress = SyncProgress(
            stage: .analyzing,
            percentage: 50.0,
            currentOperation: "Computing features"
        )
        
        XCTAssertEqual(progress.stage, .analyzing)
        XCTAssertEqual(progress.percentage, 50.0)
        XCTAssertEqual(progress.currentOperation, "Computing features")
    }
}