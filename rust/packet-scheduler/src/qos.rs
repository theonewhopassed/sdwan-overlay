use crate::config::{QosRule, MatchCriteria, QosAction};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PacketInfo {
    pub source_ip: String,
    pub dest_ip: String,
    pub protocol: String,
    pub source_port: Option<u16>,
    pub dest_port: Option<u16>,
    pub dscp: Option<u8>,
    pub priority: u8,
}

pub struct QosEngine {
    rules: Vec<QosRule>,
}

impl QosEngine {
    pub fn new(rules: Vec<QosRule>) -> Self {
        Self { rules }
    }
    
    pub fn classify_packet(&self, packet: &PacketInfo) -> Option<&QosRule> {
        for rule in &self.rules {
            if self.matches_rule(packet, rule) {
                return Some(rule);
            }
        }
        None
    }
    
    fn matches_rule(&self, packet: &PacketInfo, rule: &QosRule) -> bool {
        let criteria = &rule.match_criteria;
        
        // Check source IP
        if let Some(ref source_ip) = criteria.source_ip {
            if packet.source_ip != *source_ip {
                return false;
            }
        }
        
        // Check destination IP
        if let Some(ref dest_ip) = criteria.dest_ip {
            if packet.dest_ip != *dest_ip {
                return false;
            }
        }
        
        // Check protocol
        if let Some(ref protocol) = criteria.protocol {
            if packet.protocol != *protocol {
                return false;
            }
        }
        
        // Check port range
        if let Some(ref port_range) = criteria.port_range {
            if let Some(dest_port) = packet.dest_port {
                if dest_port < port_range.start || dest_port > port_range.end {
                    return false;
                }
            }
        }
        
        // Check DSCP
        if let Some(dscp) = criteria.dscp {
            if let Some(packet_dscp) = packet.dscp {
                if packet_dscp != dscp {
                    return false;
                }
            }
        }
        
        true
    }
    
    pub fn get_priority(&self, packet: &PacketInfo) -> u8 {
        if let Some(rule) = self.classify_packet(packet) {
            rule.priority
        } else {
            5 // Default priority
        }
    }
    
    pub fn get_link_preference(&self, packet: &PacketInfo) -> Vec<String> {
        if let Some(rule) = self.classify_packet(packet) {
            rule.action.link_preference.clone()
        } else {
            vec![] // No preference
        }
    }
    
    pub fn get_bandwidth_limit(&self, packet: &PacketInfo) -> Option<u64> {
        if let Some(rule) = self.classify_packet(packet) {
            rule.action.bandwidth_limit
        } else {
            None
        }
    }
    
    pub fn get_latency_threshold(&self, packet: &PacketInfo) -> Option<u64> {
        if let Some(rule) = self.classify_packet(packet) {
            rule.action.latency_threshold
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{MatchCriteria, QosAction, PortRange};
    
    #[test]
    fn test_qos_classification() {
        let rules = vec![
            QosRule {
                name: "voip".to_string(),
                priority: 7,
                match_criteria: MatchCriteria {
                    source_ip: Some("192.168.1.100".to_string()),
                    dest_ip: None,
                    protocol: Some("UDP".to_string()),
                    port_range: Some(PortRange { start: 10000, end: 20000 }),
                    dscp: Some(46),
                },
                action: QosAction {
                    link_preference: vec!["eth0".to_string()],
                    bandwidth_limit: Some(1000000),
                    latency_threshold: Some(20),
                },
            },
        ];
        
        let qos_engine = QosEngine::new(rules);
        
        let packet = PacketInfo {
            source_ip: "192.168.1.100".to_string(),
            dest_ip: "192.168.1.200".to_string(),
            protocol: "UDP".to_string(),
            source_port: Some(12345),
            dest_port: Some(15000),
            dscp: Some(46),
            priority: 5,
        };
        
        assert!(qos_engine.classify_packet(&packet).is_some());
        assert_eq!(qos_engine.get_priority(&packet), 7);
    }
    
    #[test]
    fn test_qos_no_match() {
        let rules = vec![
            QosRule {
                name: "voip".to_string(),
                priority: 7,
                match_criteria: MatchCriteria {
                    source_ip: Some("192.168.1.100".to_string()),
                    dest_ip: None,
                    protocol: Some("UDP".to_string()),
                    port_range: None,
                    dscp: None,
                },
                action: QosAction {
                    link_preference: vec![],
                    bandwidth_limit: None,
                    latency_threshold: None,
                },
            },
        ];
        
        let qos_engine = QosEngine::new(rules);
        
        let packet = PacketInfo {
            source_ip: "192.168.1.101".to_string(), // Different IP
            dest_ip: "192.168.1.200".to_string(),
            protocol: "UDP".to_string(),
            source_port: Some(12345),
            dest_port: Some(15000),
            dscp: None,
            priority: 5,
        };
        
        assert!(qos_engine.classify_packet(&packet).is_none());
        assert_eq!(qos_engine.get_priority(&packet), 5); // Default priority
    }
} 