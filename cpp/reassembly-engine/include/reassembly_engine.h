#pragma once

#include <vector>
#include <memory>
#include <string>
#include <chrono>
#include <unordered_map>
#include <queue>

namespace sdwan {

// Configuration for reassembly engine
struct ReassemblyConfig {
    uint32_t max_buffer_size = 1024 * 1024;  // 1MB
    uint32_t max_packet_age_ms = 5000;        // 5 seconds
    uint32_t jitter_buffer_size = 1000;       // 1000 packets
    bool enable_reordering = true;
    bool enable_jitter_buffering = true;
    std::string tun_interface = "sdwan0";
    std::string tap_interface = "sdwan1";
};

// Packet structure for reassembly
struct Packet {
    uint64_t sequence_number;
    uint64_t timestamp;
    std::vector<uint8_t> data;
    std::string source_ip;
    std::string dest_ip;
    uint16_t source_port;
    uint16_t dest_port;
    uint8_t protocol;
    uint8_t priority;
};

// Jitter buffer entry
struct JitterBufferEntry {
    Packet packet;
    std::chrono::steady_clock::time_point arrival_time;
    bool is_ready;
};

// Main reassembly engine class
class ReassemblyEngine {
public:
    explicit ReassemblyEngine(const ReassemblyConfig& config);
    ~ReassemblyEngine();

    // Process incoming packet
    bool process_packet(const Packet& packet);

    // Get reassembled packet (if ready)
    std::vector<Packet> get_reassembled_packets();

    // Flush jitter buffer
    void flush_buffer();

    // Get statistics
    struct Statistics {
        uint64_t packets_received;
        uint64_t packets_reassembled;
        uint64_t packets_dropped;
        uint64_t reordering_events;
        double average_jitter_ms;
        double packet_loss_rate;
    };

    Statistics get_statistics() const;

    // Start/stop the engine
    bool start();
    void stop();

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;
};

// TUN/TAP interface manager
class TunTapManager {
public:
    explicit TunTapManager(const std::string& interface_name, bool is_tun = true);
    ~TunTapManager();

    // Open/close interface
    bool open_interface();
    void close_interface();

    // Read/write packets
    int read_packet(std::vector<uint8_t>& data);
    int write_packet(const std::vector<uint8_t>& data);

    // Get interface status
    bool is_open() const;
    std::string get_interface_name() const;

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;
};

// Packet reordering engine
class PacketReorderer {
public:
    explicit PacketReorderer(uint32_t max_buffer_size, uint32_t max_age_ms);
    ~PacketReorderer();

    // Add packet to reorder buffer
    bool add_packet(const Packet& packet);

    // Get next packet in order
    std::optional<Packet> get_next_packet();

    // Get statistics
    struct ReorderStats {
        uint64_t packets_reordered;
        uint64_t packets_dropped;
        uint64_t max_reorder_distance;
        double average_reorder_delay_ms;
    };

    ReorderStats get_stats() const;

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;
};

// Jitter buffer implementation
class JitterBuffer {
public:
    explicit JitterBuffer(uint32_t buffer_size, uint32_t max_age_ms);
    ~JitterBuffer();

    // Add packet to jitter buffer
    bool add_packet(const Packet& packet);

    // Get packets ready for processing
    std::vector<Packet> get_ready_packets();

    // Get statistics
    struct JitterStats {
        uint64_t packets_buffered;
        uint64_t packets_ready;
        uint64_t packets_dropped;
        double average_jitter_ms;
        double max_jitter_ms;
    };

    JitterStats get_stats() const;

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;
};

} // namespace sdwan 