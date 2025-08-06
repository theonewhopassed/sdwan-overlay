#include "fec_engine.h"
#include <algorithm>
#include <stdexcept>
#include <iostream>
#include <chrono>

namespace sdwan {

class FecEngine::Impl {
public:
    explicit Impl(const FecConfig& config) : config_(config) {
        switch (config.type) {
            case FecType::REED_SOLOMON:
                rs_fec_ = std::make_unique<ReedSolomonFec>(config.data_shards, config.parity_shards);
                break;
            case FecType::XOR:
                xor_fec_ = std::make_unique<XorFec>(config.data_shards, config.parity_shards);
                break;
        }
    }

    std::vector<std::vector<uint8_t>> encode(const std::vector<uint8_t>& data) {
        if (rs_fec_) {
            return rs_fec_->encode(data);
        } else if (xor_fec_) {
            return xor_fec_->encode(data);
        }
        throw std::runtime_error("No FEC implementation available");
    }

    std::vector<uint8_t> decode(const std::vector<std::vector<uint8_t>>& shards) {
        if (rs_fec_) {
            return rs_fec_->decode(shards);
        } else if (xor_fec_) {
            return xor_fec_->decode(shards);
        }
        throw std::runtime_error("No FEC implementation available");
    }

    bool can_recover(const std::vector<bool>& received_shards) const {
        if (rs_fec_) {
            return rs_fec_->can_recover(received_shards);
        } else if (xor_fec_) {
            return xor_fec_->can_recover(received_shards);
        }
        return false;
    }

    double get_overhead() const {
        return static_cast<double>(config_.parity_shards) / config_.data_shards;
    }

    double get_recovery_probability() const {
        // Simplified probability calculation
        return 1.0 - (1.0 / (config_.data_shards + config_.parity_shards));
    }

private:
    FecConfig config_;
    std::unique_ptr<ReedSolomonFec> rs_fec_;
    std::unique_ptr<XorFec> xor_fec_;
};

FecEngine::FecEngine(const FecConfig& config) : pimpl_(std::make_unique<Impl>(config)) {}
FecEngine::~FecEngine() = default;

std::vector<std::vector<uint8_t>> FecEngine::encode(const std::vector<uint8_t>& data) {
    return pimpl_->encode(data);
}

std::vector<uint8_t> FecEngine::decode(const std::vector<std::vector<uint8_t>>& shards) {
    return pimpl_->decode(shards);
}

bool FecEngine::can_recover(const std::vector<bool>& received_shards) const {
    return pimpl_->can_recover(received_shards);
}

double FecEngine::get_overhead() const {
    return pimpl_->get_overhead();
}

double FecEngine::get_recovery_probability() const {
    return pimpl_->get_recovery_probability();
}

// Reed-Solomon implementation
class ReedSolomonFec::Impl {
public:
    Impl(uint32_t data_shards, uint32_t parity_shards) 
        : data_shards_(data_shards), parity_shards_(parity_shards) {
        // TODO: Initialize Reed-Solomon library
    }

    std::vector<std::vector<uint8_t>> encode(const std::vector<uint8_t>& data) {
        // TODO: Implement Reed-Solomon encoding
        std::vector<std::vector<uint8_t>> shards;
        
        // Simulate encoding
        size_t shard_size = (data.size() + data_shards_ - 1) / data_shards_;
        
        for (uint32_t i = 0; i < data_shards_ + parity_shards_; ++i) {
            std::vector<uint8_t> shard(shard_size, 0);
            if (i < data_shards_) {
                size_t start = i * shard_size;
                size_t end = std::min(start + shard_size, data.size());
                std::copy(data.begin() + start, data.begin() + end, shard.begin());
            }
            shards.push_back(shard);
        }
        
        return shards;
    }

    std::vector<uint8_t> decode(const std::vector<std::vector<uint8_t>>& shards) {
        // TODO: Implement Reed-Solomon decoding
        std::vector<uint8_t> result;
        
        // Simulate decoding
        for (uint32_t i = 0; i < data_shards_; ++i) {
            if (i < shards.size() && !shards[i].empty()) {
                result.insert(result.end(), shards[i].begin(), shards[i].end());
            }
        }
        
        return result;
    }

    bool can_recover(const std::vector<bool>& received_shards) const {
        uint32_t received_count = std::count(received_shards.begin(), received_shards.end(), true);
        return received_count >= data_shards_;
    }

private:
    uint32_t data_shards_;
    uint32_t parity_shards_;
};

ReedSolomonFec::ReedSolomonFec(uint32_t data_shards, uint32_t parity_shards) 
    : pimpl_(std::make_unique<Impl>(data_shards, parity_shards)) {}
ReedSolomonFec::~ReedSolomonFec() = default;

std::vector<std::vector<uint8_t>> ReedSolomonFec::encode(const std::vector<uint8_t>& data) {
    return pimpl_->encode(data);
}

std::vector<uint8_t> ReedSolomonFec::decode(const std::vector<std::vector<uint8_t>>& shards) {
    return pimpl_->decode(shards);
}

bool ReedSolomonFec::can_recover(const std::vector<bool>& received_shards) const {
    return pimpl_->can_recover(received_shards);
}

// XOR-based FEC implementation
XorFec::XorFec(uint32_t data_shards, uint32_t parity_shards) 
    : data_shards_(data_shards), parity_shards_(parity_shards) {}

XorFec::~XorFec() = default;

std::vector<std::vector<uint8_t>> XorFec::encode(const std::vector<uint8_t>& data) {
    std::vector<std::vector<uint8_t>> shards;
    
    // Split data into shards
    size_t shard_size = (data.size() + data_shards_ - 1) / data_shards_;
    
    for (uint32_t i = 0; i < data_shards_; ++i) {
        std::vector<uint8_t> shard(shard_size, 0);
        size_t start = i * shard_size;
        size_t end = std::min(start + shard_size, data.size());
        std::copy(data.begin() + start, data.begin() + end, shard.begin());
        shards.push_back(shard);
    }
    
    // Generate parity shards using XOR
    for (uint32_t i = 0; i < parity_shards_; ++i) {
        std::vector<uint8_t> parity_shard(shard_size, 0);
        for (uint32_t j = 0; j < data_shards_; ++j) {
            for (size_t k = 0; k < shard_size; ++k) {
                parity_shard[k] ^= shards[j][k];
            }
        }
        shards.push_back(parity_shard);
    }
    
    return shards;
}

std::vector<uint8_t> XorFec::decode(const std::vector<std::vector<uint8_t>>& shards) {
    std::vector<uint8_t> result;
    
    // Reconstruct data from available shards
    for (uint32_t i = 0; i < data_shards_; ++i) {
        if (i < shards.size() && !shards[i].empty()) {
            result.insert(result.end(), shards[i].begin(), shards[i].end());
        }
    }
    
    return result;
}

bool XorFec::can_recover(const std::vector<bool>& received_shards) const {
    uint32_t received_data = 0;
    uint32_t received_parity = 0;
    
    for (uint32_t i = 0; i < received_shards.size(); ++i) {
        if (received_shards[i]) {
            if (i < data_shards_) {
                received_data++;
            } else {
                received_parity++;
            }
        }
    }
    
    return received_data >= data_shards_ || (received_data == data_shards_ - 1 && received_parity > 0);
}

std::vector<uint8_t> XorFec::xor_shards(const std::vector<std::vector<uint8_t>>& data_shards) {
    if (data_shards.empty()) return {};
    
    std::vector<uint8_t> result(data_shards[0].size(), 0);
    
    for (const auto& shard : data_shards) {
        for (size_t i = 0; i < result.size(); ++i) {
            result[i] ^= shard[i];
        }
    }
    
    return result;
}

} // namespace sdwan 