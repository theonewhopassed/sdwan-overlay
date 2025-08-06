#include "fec_engine.h"
#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>

int main(int argc, char* argv[]) {
    std::cout << "SD-WAN FEC Engine v0.1.0" << std::endl;
    
    // Parse command line arguments
    bool test_mode = false;
    bool benchmark_mode = false;
    bool daemon_mode = false;
    
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--test") {
            test_mode = true;
        } else if (arg == "--benchmark") {
            benchmark_mode = true;
        } else if (arg == "--daemon") {
            daemon_mode = true;
        } else if (arg == "--help" || arg == "-h") {
            std::cout << "Usage: " << argv[0] << " [OPTIONS]" << std::endl;
            std::cout << "Options:" << std::endl;
            std::cout << "  --test       Run unit tests" << std::endl;
            std::cout << "  --benchmark  Run performance benchmarks" << std::endl;
            std::cout << "  --daemon     Run in daemon mode" << std::endl;
            std::cout << "  --help, -h   Show this help message" << std::endl;
            return 0;
        }
    }
    
    if (daemon_mode) {
        std::cout << "FEC Engine starting in daemon mode..." << std::endl;
        
        // Initialize FEC engine
        sdwan::FecConfig config;
        config.type = sdwan::FecType::REED_SOLOMON;
        config.data_shards = 4;
        config.parity_shards = 2;
        
        sdwan::FecEngine engine(config);
        
        std::cout << "FEC Engine daemon started successfully" << std::endl;
        
        // Keep the daemon running
        while (true) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
        
        return 0;
    }
    
    if (test_mode) {
        std::cout << "Running FEC engine tests..." << std::endl;
        
        // Test Reed-Solomon FEC
        try {
            sdwan::FecConfig rs_config;
            rs_config.type = sdwan::FecType::REED_SOLOMON;
            rs_config.data_shards = 4;
            rs_config.parity_shards = 2;
            
            sdwan::FecEngine rs_engine(rs_config);
            
            // Test data
            std::vector<uint8_t> test_data = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
            
            // Encode
            auto encoded = rs_engine.encode(test_data);
            std::cout << "Reed-Solomon encoding successful: " << encoded.size() << " shards" << std::endl;
            
            // Decode
            auto decoded = rs_engine.decode(encoded);
            std::cout << "Reed-Solomon decoding successful: " << decoded.size() << " bytes" << std::endl;
            
            // Verify
            if (decoded == test_data) {
                std::cout << "✓ Reed-Solomon test passed" << std::endl;
            } else {
                std::cout << "✗ Reed-Solomon test failed" << std::endl;
                return 1;
            }
        } catch (const std::exception& e) {
            std::cerr << "Reed-Solomon test failed: " << e.what() << std::endl;
            return 1;
        }
        
        // Test XOR FEC
        try {
            sdwan::FecConfig xor_config;
            xor_config.type = sdwan::FecType::XOR;
            xor_config.data_shards = 3;
            xor_config.parity_shards = 1;
            
            sdwan::XorFec xor_engine(xor_config.data_shards, xor_config.parity_shards);
            
            // Test data
            std::vector<uint8_t> test_data = {1, 2, 3, 4, 5, 6};
            
            // Encode
            auto encoded = xor_engine.encode(test_data);
            std::cout << "XOR encoding successful: " << encoded.size() << " shards" << std::endl;
            
            // Decode
            auto decoded = xor_engine.decode(encoded);
            std::cout << "XOR decoding successful: " << decoded.size() << " bytes" << std::endl;
            
            // Verify
            if (decoded == test_data) {
                std::cout << "✓ XOR test passed" << std::endl;
            } else {
                std::cout << "✗ XOR test failed" << std::endl;
                return 1;
            }
        } catch (const std::exception& e) {
            std::cerr << "XOR test failed: " << e.what() << std::endl;
            return 1;
        }
        
        std::cout << "All tests passed!" << std::endl;
        return 0;
    }
    
    if (benchmark_mode) {
        std::cout << "Running FEC engine benchmarks..." << std::endl;
        
        // Benchmark Reed-Solomon
        {
            sdwan::FecConfig rs_config;
            rs_config.type = sdwan::FecType::REED_SOLOMON;
            rs_config.data_shards = 8;
            rs_config.parity_shards = 4;
            
            sdwan::FecEngine rs_engine(rs_config);
            
            // Generate test data (1MB)
            std::vector<uint8_t> test_data(1024 * 1024);
            for (size_t i = 0; i < test_data.size(); ++i) {
                test_data[i] = static_cast<uint8_t>(i % 256);
            }
            
            auto start = std::chrono::high_resolution_clock::now();
            auto encoded = rs_engine.encode(test_data);
            auto end = std::chrono::high_resolution_clock::now();
            
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            std::cout << "Reed-Solomon encode (1MB): " << duration.count() << " μs" << std::endl;
            std::cout << "Reed-Solomon overhead: " << (rs_engine.get_overhead() * 100) << "%" << std::endl;
        }
        
        // Benchmark XOR
        {
            sdwan::FecConfig xor_config;
            xor_config.type = sdwan::FecType::XOR;
            xor_config.data_shards = 4;
            xor_config.parity_shards = 1;
            
            sdwan::XorFec xor_engine(xor_config.data_shards, xor_config.parity_shards);
            
            // Generate test data (1MB)
            std::vector<uint8_t> test_data(1024 * 1024);
            for (size_t i = 0; i < test_data.size(); ++i) {
                test_data[i] = static_cast<uint8_t>(i % 256);
            }
            
            auto start = std::chrono::high_resolution_clock::now();
            auto encoded = xor_engine.encode(test_data);
            auto end = std::chrono::high_resolution_clock::now();
            
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            std::cout << "XOR encode (1MB): " << duration.count() << " μs" << std::endl;
            std::cout << "XOR overhead: " << (static_cast<double>(xor_config.parity_shards) / xor_config.data_shards * 100) << "%" << std::endl;
        }
        
        std::cout << "Benchmarks completed!" << std::endl;
        return 0;
    }
    
    // Default mode - show usage
    std::cout << "FEC Engine is running in library mode." << std::endl;
    std::cout << "Use --test for unit tests or --benchmark for performance tests." << std::endl;
    std::cout << "Use --help for more options." << std::endl;
    
    return 0;
} 