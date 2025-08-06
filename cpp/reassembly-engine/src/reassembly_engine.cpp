#include "reassembly_engine.h"
#include <algorithm>
#include <stdexcept>
#include <iostream>
#include <chrono>
#include <optional>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/if_tun.h>
#include <net/if.h>

namespace sdwan {

// ReassemblyEngine implementation
class ReassemblyEngine::Impl {
public:
    explicit Impl(const ReassemblyConfig& config) : config_(config) {
        if (config.enable_reordering) {
            reorderer_ = std::make_unique<PacketReorderer>(
                config.max_buffer_size, config.max_packet_age_ms);
        }
        
        if (config.enable_jitter_buffering) {
            jitter_buffer_ = std::make_unique<JitterBuffer>(
                config.jitter_buffer_size, config.max_packet_age_ms);
        }
        
        tun_manager_ = std::make_unique<TunTapManager>(config.tun_interface, true);
        tap_manager_ = std::make_unique<TunTapManager>(config.tap_interface, false);
    }

    bool process_packet(const Packet& packet) {
        stats_.packets_received++;
        
        // Add to jitter buffer if enabled
        if (jitter_buffer_) {
            if (!jitter_buffer_->add_packet(packet)) {
                stats_.packets_dropped++;
                return false;
            }
        }
        
        // Add to reorderer if enabled
        if (reorderer_) {
            if (!reorderer_->add_packet(packet)) {
                stats_.packets_dropped++;
                return false;
            }
        }
        
        return true;
    }

    std::vector<Packet> get_reassembled_packets() {
        std::vector<Packet> result;
        
        // Get packets from jitter buffer
        if (jitter_buffer_) {
            auto jitter_packets = jitter_buffer_->get_ready_packets();
            result.insert(result.end(), jitter_packets.begin(), jitter_packets.end());
        }
        
        // Get packets from reorderer
        if (reorderer_) {
            while (auto packet = reorderer_->get_next_packet()) {
                result.push_back(*packet);
            }
        }
        
        stats_.packets_reassembled += result.size();
        return result;
    }

    void flush_buffer() {
        if (jitter_buffer_) {
            auto packets = jitter_buffer_->get_ready_packets();
            stats_.packets_reassembled += packets.size();
        }
        
        if (reorderer_) {
            while (auto packet = reorderer_->get_next_packet()) {
                stats_.packets_reassembled++;
            }
        }
    }

    ReassemblyEngine::Statistics get_statistics() const {
        return stats_;
    }

    bool start() {
        if (!tun_manager_->open_interface()) {
            std::cerr << "Failed to open TUN interface" << std::endl;
            return false;
        }
        
        if (!tap_manager_->open_interface()) {
            std::cerr << "Failed to open TAP interface" << std::endl;
            return false;
        }
        
        return true;
    }

    void stop() {
        tun_manager_->close_interface();
        tap_manager_->close_interface();
    }

private:
    ReassemblyConfig config_;
    std::unique_ptr<PacketReorderer> reorderer_;
    std::unique_ptr<JitterBuffer> jitter_buffer_;
    std::unique_ptr<TunTapManager> tun_manager_;
    std::unique_ptr<TunTapManager> tap_manager_;
    ReassemblyEngine::Statistics stats_;
};

ReassemblyEngine::ReassemblyEngine(const ReassemblyConfig& config) 
    : pimpl_(std::make_unique<Impl>(config)) {}

ReassemblyEngine::~ReassemblyEngine() = default;

bool ReassemblyEngine::process_packet(const Packet& packet) {
    return pimpl_->process_packet(packet);
}

std::vector<Packet> ReassemblyEngine::get_reassembled_packets() {
    return pimpl_->get_reassembled_packets();
}

void ReassemblyEngine::flush_buffer() {
    pimpl_->flush_buffer();
}

ReassemblyEngine::Statistics ReassemblyEngine::get_statistics() const {
    return pimpl_->get_statistics();
}

bool ReassemblyEngine::start() {
    return pimpl_->start();
}

void ReassemblyEngine::stop() {
    pimpl_->stop();
}

// TunTapManager implementation
class TunTapManager::Impl {
public:
    Impl(const std::string& interface_name, bool is_tun) 
        : interface_name_(interface_name), is_tun_(is_tun), fd_(-1) {}

    bool open_interface() {
        // TODO: Implement actual TUN/TAP interface creation
        // For now, just simulate the interface
        fd_ = 1; // Simulate open file descriptor
        return true;
    }

    void close_interface() {
        if (fd_ >= 0) {
            // TODO: Implement actual close
            fd_ = -1;
        }
    }

    int read_packet(std::vector<uint8_t>& data) {
        if (fd_ < 0) return -1;
        
        // TODO: Implement actual packet reading
        // For now, return empty data
        data.clear();
        return 0;
    }

    int write_packet(const std::vector<uint8_t>& data) {
        if (fd_ < 0) return -1;
        
        // TODO: Implement actual packet writing
        return data.size();
    }

    bool is_open() const {
        return fd_ >= 0;
    }

    std::string get_interface_name() const {
        return interface_name_;
    }

private:
    std::string interface_name_;
    bool is_tun_;
    int fd_;
};

TunTapManager::TunTapManager(const std::string& interface_name, bool is_tun)
    : pimpl_(std::make_unique<Impl>(interface_name, is_tun)) {}

TunTapManager::~TunTapManager() = default;

bool TunTapManager::open_interface() {
    return pimpl_->open_interface();
}

void TunTapManager::close_interface() {
    pimpl_->close_interface();
}

int TunTapManager::read_packet(std::vector<uint8_t>& data) {
    return pimpl_->read_packet(data);
}

int TunTapManager::write_packet(const std::vector<uint8_t>& data) {
    return pimpl_->write_packet(data);
}

bool TunTapManager::is_open() const {
    return pimpl_->is_open();
}

std::string TunTapManager::get_interface_name() const {
    return pimpl_->get_interface_name();
}

// PacketReorderer implementation
class PacketReorderer::Impl {
public:
    Impl(uint32_t max_buffer_size, uint32_t max_age_ms)
        : max_buffer_size_(max_buffer_size), max_age_ms_(max_age_ms) {}

    bool add_packet(const Packet& packet) {
        auto now = std::chrono::steady_clock::now();
        
        // Check if packet is too old
        if (packet.timestamp + max_age_ms_ < 
            std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count()) {
            stats_.packets_dropped++;
            return false;
        }
        
        // Add to buffer
        buffer_[packet.sequence_number] = packet;
        
        // Remove old packets if buffer is full
        if (buffer_.size() > max_buffer_size_) {
            auto oldest = buffer_.begin();
            buffer_.erase(oldest);
            stats_.packets_dropped++;
        }
        
        return true;
    }

    std::optional<Packet> get_next_packet() {
        if (buffer_.empty()) return std::nullopt;
        
        auto it = buffer_.begin();
        auto packet = it->second;
        buffer_.erase(it);
        
        stats_.packets_reordered++;
        return packet;
    }

    ReorderStats get_stats() const {
        return stats_;
    }

private:
    uint32_t max_buffer_size_;
    uint32_t max_age_ms_;
    std::map<uint64_t, Packet> buffer_;
    ReorderStats stats_;
};

PacketReorderer::PacketReorderer(uint32_t max_buffer_size, uint32_t max_age_ms)
    : pimpl_(std::make_unique<Impl>(max_buffer_size, max_age_ms)) {}

PacketReorderer::~PacketReorderer() = default;

bool PacketReorderer::add_packet(const Packet& packet) {
    return pimpl_->add_packet(packet);
}

std::optional<Packet> PacketReorderer::get_next_packet() {
    return pimpl_->get_next_packet();
}

PacketReorderer::ReorderStats PacketReorderer::get_stats() const {
    return pimpl_->get_stats();
}

// JitterBuffer implementation
class JitterBuffer::Impl {
public:
    Impl(uint32_t buffer_size, uint32_t max_age_ms)
        : buffer_size_(buffer_size), max_age_ms_(max_age_ms) {}

    bool add_packet(const Packet& packet) {
        auto now = std::chrono::steady_clock::now();
        
        // Check if packet is too old
        if (packet.timestamp + max_age_ms_ < 
            std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count()) {
            stats_.packets_dropped++;
            return false;
        }
        
        // Add to buffer
        JitterBufferEntry entry{packet, now, false};
        buffer_.push(entry);
        
        // Remove old packets if buffer is full
        if (buffer_.size() > buffer_size_) {
            buffer_.pop();
            stats_.packets_dropped++;
        }
        
        stats_.packets_buffered++;
        return true;
    }

    std::vector<Packet> get_ready_packets() {
        std::vector<Packet> result;
        auto now = std::chrono::steady_clock::now();
        
        while (!buffer_.empty()) {
            auto& entry = buffer_.front();
            
            // Check if packet is ready (age > average jitter)
            auto age = std::chrono::duration_cast<std::chrono::milliseconds>(
                now - entry.arrival_time).count();
            
            if (age > 10) { // Simple jitter threshold
                result.push_back(entry.packet);
                stats_.packets_ready++;
            } else {
                break;
            }
            
            buffer_.pop();
        }
        
        return result;
    }

    JitterStats get_stats() const {
        return stats_;
    }

private:
    uint32_t buffer_size_;
    uint32_t max_age_ms_;
    std::queue<JitterBufferEntry> buffer_;
    JitterStats stats_;
};

JitterBuffer::JitterBuffer(uint32_t buffer_size, uint32_t max_age_ms)
    : pimpl_(std::make_unique<Impl>(buffer_size, max_age_ms)) {}

JitterBuffer::~JitterBuffer() = default;

bool JitterBuffer::add_packet(const Packet& packet) {
    return pimpl_->add_packet(packet);
}

std::vector<Packet> JitterBuffer::get_ready_packets() {
    return pimpl_->get_ready_packets();
}

JitterBuffer::JitterStats JitterBuffer::get_stats() const {
    return pimpl_->get_stats();
}

} // namespace sdwan 