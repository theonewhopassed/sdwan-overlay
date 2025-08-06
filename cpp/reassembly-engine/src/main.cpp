#include "reassembly_engine.h"
#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>

int main(int argc, char* argv[]) {
    std::cout << "SD-WAN Reassembly Engine v0.1.0" << std::endl;
    
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
        std::cout << "Reassembly Engine starting in daemon mode..." << std::endl;
        
        // Initialize reassembly engine
        sdwan::ReassemblyConfig config;
        config.buffer_size = 1000;
        config.jitter_buffer_size = 500;
        config.max_age_ms = 1000;
        
        sdwan::ReassemblyEngine engine(config);
        
        std::cout << "Reassembly Engine daemon started successfully" << std::endl;
        
        // Keep the daemon running
        while (true) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
        
        return 0;
    }
    
    if (test_mode) {
        std::cout << "Running reassembly engine tests..." << std::endl;
        
        // Test ReassemblyEngine
        try {
            sdwan::ReassemblyConfig config;
            config.max_buffer_size = 1024 * 1024;  // 1MB
            config.max_packet_age_ms = 5000;        // 5 seconds
            config.jitter_buffer_size = 1000;       // 1000 packets
            config.enable_reordering = true;
            config.enable_jitter_buffering = true;
            
            sdwan::ReassemblyEngine engine(config);
            
            // Test packet processing
            sdwan::Packet test_packet;
            test_packet.sequence_number = 1;
            test_packet.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count();
            test_packet.data = {1, 2, 3, 4, 5, 6};
            test_packet.source_ip = "192.168.1.100";
            test_packet.dest_ip = "192.168.1.200";
            test_packet.source_port = 12345;
            test_packet.dest_port = 54321;
            test_packet.protocol = 6; // TCP
            test_packet.priority = 1;
            
            bool result = engine.process_packet(test_packet);
            if (result) {
                std::cout << "✓ Packet processing test passed" << std::endl;
            } else {
                std::cout << "✗ Packet processing test failed" << std::endl;
                return 1;
            }
            
            // Test statistics
            auto stats = engine.get_statistics();
            std::cout << "Statistics: " << stats.packets_received << " packets received" << std::endl;
            
        } catch (const std::exception& e) {
            std::cerr << "Reassembly engine test failed: " << e.what() << std::endl;
            return 1;
        }
        
        // Test PacketReorderer
        try {
            sdwan::PacketReorderer reorderer(1024, 5000);
            
            sdwan::Packet packet1;
            packet1.sequence_number = 2;
            packet1.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count();
            packet1.data = {1, 2, 3};
            
            sdwan::Packet packet2;
            packet2.sequence_number = 1;
            packet2.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count();
            packet2.data = {4, 5, 6};
            
            // Add packets out of order
            reorderer.add_packet(packet1);
            reorderer.add_packet(packet2);
            
            // Get packets in order
            auto packet = reorderer.get_next_packet();
            if (packet && packet->sequence_number == 1) {
                std::cout << "✓ Packet reordering test passed" << std::endl;
            } else {
                std::cout << "✗ Packet reordering test failed" << std::endl;
                return 1;
            }
            
        } catch (const std::exception& e) {
            std::cerr << "Packet reordering test failed: " << e.what() << std::endl;
            return 1;
        }
        
        // Test JitterBuffer
        try {
            sdwan::JitterBuffer jitter_buffer(100, 5000);
            
            sdwan::Packet packet;
            packet.sequence_number = 1;
            packet.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count();
            packet.data = {1, 2, 3, 4, 5};
            
            bool result = jitter_buffer.add_packet(packet);
            if (result) {
                std::cout << "✓ Jitter buffer test passed" << std::endl;
            } else {
                std::cout << "✗ Jitter buffer test failed" << std::endl;
                return 1;
            }
            
        } catch (const std::exception& e) {
            std::cerr << "Jitter buffer test failed: " << e.what() << std::endl;
            return 1;
        }
        
        std::cout << "All tests passed!" << std::endl;
        return 0;
    }
    
    if (benchmark_mode) {
        std::cout << "Running reassembly engine benchmarks..." << std::endl;
        
        // Benchmark ReassemblyEngine
        {
            sdwan::ReassemblyConfig config;
            config.max_buffer_size = 1024 * 1024;
            config.max_packet_age_ms = 5000;
            config.jitter_buffer_size = 1000;
            config.enable_reordering = true;
            config.enable_jitter_buffering = true;
            
            sdwan::ReassemblyEngine engine(config);
            
            // Generate test packets
            std::vector<sdwan::Packet> test_packets;
            for (int i = 0; i < 1000; ++i) {
                sdwan::Packet packet;
                packet.sequence_number = i;
                packet.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now().time_since_epoch()).count();
                packet.data.resize(1000);
                for (size_t j = 0; j < packet.data.size(); ++j) {
                    packet.data[j] = static_cast<uint8_t>((i + j) % 256);
                }
                test_packets.push_back(packet);
            }
            
            auto start = std::chrono::high_resolution_clock::now();
            
            // Process packets
            for (const auto& packet : test_packets) {
                engine.process_packet(packet);
            }
            
            auto end = std::chrono::high_resolution_clock::now();
            
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            std::cout << "ReassemblyEngine process (1000 packets): " << duration.count() << " μs" << std::endl;
            
            auto stats = engine.get_statistics();
            std::cout << "Packets received: " << stats.packets_received << std::endl;
            std::cout << "Packets reassembled: " << stats.packets_reassembled << std::endl;
            std::cout << "Packets dropped: " << stats.packets_dropped << std::endl;
        }
        
        // Benchmark PacketReorderer
        {
            sdwan::PacketReorderer reorderer(1024 * 1024, 5000);
            
            auto start = std::chrono::high_resolution_clock::now();
            
            // Add packets out of order
            for (int i = 1000; i >= 0; --i) {
                sdwan::Packet packet;
                packet.sequence_number = i;
                packet.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now().time_since_epoch()).count();
                packet.data.resize(100);
                reorderer.add_packet(packet);
            }
            
            auto end = std::chrono::high_resolution_clock::now();
            
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            std::cout << "PacketReorderer add (1000 packets): " << duration.count() << " μs" << std::endl;
            
            auto stats = reorderer.get_stats();
            std::cout << "Packets reordered: " << stats.packets_reordered << std::endl;
            std::cout << "Packets dropped: " << stats.packets_dropped << std::endl;
        }
        
        // Benchmark JitterBuffer
        {
            sdwan::JitterBuffer jitter_buffer(1000, 5000);
            
            auto start = std::chrono::high_resolution_clock::now();
            
            // Add packets
            for (int i = 0; i < 1000; ++i) {
                sdwan::Packet packet;
                packet.sequence_number = i;
                packet.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now().time_since_epoch()).count();
                packet.data.resize(100);
                jitter_buffer.add_packet(packet);
            }
            
            auto end = std::chrono::high_resolution_clock::now();
            
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
            std::cout << "JitterBuffer add (1000 packets): " << duration.count() << " μs" << std::endl;
            
            auto stats = jitter_buffer.get_stats();
            std::cout << "Packets buffered: " << stats.packets_buffered << std::endl;
            std::cout << "Packets ready: " << stats.packets_ready << std::endl;
            std::cout << "Packets dropped: " << stats.packets_dropped << std::endl;
        }
        
        std::cout << "Benchmarks completed!" << std::endl;
        return 0;
    }
    
    // Default mode - show usage
    std::cout << "Reassembly Engine is running in library mode." << std::endl;
    std::cout << "Use --test for unit tests or --benchmark for performance tests." << std::endl;
    std::cout << "Use --help for more options." << std::endl;
    
    return 0;
} 