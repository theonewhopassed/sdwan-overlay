#pragma once

#include <vector>
#include <memory>
#include <cstdint>
#include <string>

namespace sdwan {

enum class FecType {
    REED_SOLOMON,
    XOR
};

struct FecConfig {
    FecType type = FecType::REED_SOLOMON;
    uint32_t data_shards = 4;
    uint32_t parity_shards = 2;
    uint32_t block_size = 4096;
    bool enable_optimization = true;
};

class FecEngine {
public:
    explicit FecEngine(const FecConfig& config);
    ~FecEngine();

    // Encode data with FEC
    std::vector<std::vector<uint8_t>> encode(const std::vector<uint8_t>& data);
    
    // Decode data and recover missing packets
    std::vector<uint8_t> decode(const std::vector<std::vector<uint8_t>>& shards);
    
    // Check if data can be recovered
    bool can_recover(const std::vector<bool>& received_shards) const;
    
    // Get FEC overhead
    double get_overhead() const;
    
    // Get recovery probability
    double get_recovery_probability() const;

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;
};

// Reed-Solomon implementation
class ReedSolomonFec {
public:
    ReedSolomonFec(uint32_t data_shards, uint32_t parity_shards);
    ~ReedSolomonFec();

    std::vector<std::vector<uint8_t>> encode(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decode(const std::vector<std::vector<uint8_t>>& shards);
    bool can_recover(const std::vector<bool>& received_shards) const;

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;
};

// XOR-based FEC implementation
class XorFec {
public:
    XorFec(uint32_t data_shards, uint32_t parity_shards);
    ~XorFec();

    std::vector<std::vector<uint8_t>> encode(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decode(const std::vector<std::vector<uint8_t>>& shards);
    bool can_recover(const std::vector<bool>& received_shards) const;

private:
    uint32_t data_shards_;
    uint32_t parity_shards_;
    
    std::vector<uint8_t> xor_shards(const std::vector<std::vector<uint8_t>>& data_shards);
};

} // namespace sdwan 