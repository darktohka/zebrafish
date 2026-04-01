use std::num::NonZeroUsize;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use hickory_proto::op::Message;
use lru::LruCache;

#[derive(Clone)]
struct CacheEntry {
    response: Vec<u8>,
    inserted_at: Instant,
    ttl: Duration,
}

pub struct DnsCache {
    cache: Mutex<LruCache<Vec<u8>, CacheEntry>>,
    min_ttl: u32,
    max_ttl: u32,
}

impl DnsCache {
    pub fn new(max_entries: usize, min_ttl: u32, max_ttl: u32) -> Self {
        let cap = NonZeroUsize::new(max_entries.max(1)).unwrap();
        Self {
            cache: Mutex::new(LruCache::new(cap)),
            min_ttl,
            max_ttl,
        }
    }

    /// Build a cache key from the query: (qname, qtype, qclass).
    fn cache_key(query: &Message) -> Option<Vec<u8>> {
        let q = query.queries().first()?;
        let mut key = Vec::with_capacity(64);
        // Normalize: lowercase the query name
        let name = q.name().to_lowercase().to_string();
        key.extend_from_slice(name.as_bytes());
        key.push(b'|');
        let rtype: u16 = q.query_type().into();
        key.extend_from_slice(&rtype.to_be_bytes());
        key.push(b'|');
        let rclass: u16 = q.query_class().into();
        key.extend_from_slice(&rclass.to_be_bytes());
        Some(key)
    }

    /// Look up a cached response. Returns None if not cached or expired.
    pub fn get(&self, query: &Message) -> Option<Vec<u8>> {
        let key = Self::cache_key(query)?;
        let mut cache = self.cache.lock().ok()?;
        let entry = cache.get(&key)?;

        let elapsed = entry.inserted_at.elapsed();
        if elapsed >= entry.ttl {
            // Expired — remove and return miss
            let key_clone = key.clone();
            cache.pop(&key_clone);
            return None;
        }

        // Adjust TTLs in the response to reflect remaining time
        let remaining = (entry.ttl - elapsed).as_secs() as u32;
        let mut response = entry.response.clone();
        Self::adjust_ttls(&mut response, remaining);
        Some(response)
    }

    /// Insert a response into the cache.
    pub fn put(&self, query: &Message, response: &[u8]) {
        let key = match Self::cache_key(query) {
            Some(k) => k,
            None => return,
        };

        let ttl = self.extract_min_ttl(response);
        let ttl = ttl.clamp(self.min_ttl, self.max_ttl);

        let entry = CacheEntry {
            response: response.to_vec(),
            inserted_at: Instant::now(),
            ttl: Duration::from_secs(ttl as u64),
        };

        if let Ok(mut cache) = self.cache.lock() {
            cache.put(key, entry);
        }
    }

    fn extract_min_ttl(&self, response: &[u8]) -> u32 {
        match Message::from_vec(response) {
            Ok(msg) => {
                let mut min = self.max_ttl;
                for record in msg.answers() {
                    min = min.min(record.ttl());
                }
                for record in msg.additionals() {
                    if record.record_type() != hickory_proto::rr::RecordType::OPT {
                        min = min.min(record.ttl());
                    }
                }
                if min == self.max_ttl && !msg.answers().is_empty() {
                    self.min_ttl
                } else {
                    min
                }
            }
            Err(_) => self.min_ttl,
        }
    }

    /// Best-effort adjustment of TTL fields in a raw DNS wire-format response.
    fn adjust_ttls(response: &mut [u8], remaining_ttl: u32) {
        if let Ok(mut msg) = Message::from_vec(response) {
            let ttl_bytes = remaining_ttl;
            for record in msg.answers_mut() {
                record.set_ttl(ttl_bytes);
            }
            if let Ok(bytes) = msg.to_vec() {
                if bytes.len() == response.len() {
                    response.copy_from_slice(&bytes);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use hickory_proto::op::{Header, MessageType, OpCode, Query, ResponseCode};
    use hickory_proto::rr::rdata::A;
    use hickory_proto::rr::record_data::RData;
    use hickory_proto::rr::{Name, Record, RecordType};
    use std::net::Ipv4Addr;
    use std::thread;
    use std::time::Duration;

    fn make_query(name: &str, rtype: RecordType) -> Message {
        let mut msg = Message::new();
        msg.set_id(1234);
        msg.set_message_type(MessageType::Query);
        msg.set_op_code(OpCode::Query);
        msg.set_recursion_desired(true);
        let mut q = Query::new();
        q.set_name(Name::from_utf8(name).unwrap());
        q.set_query_type(rtype);
        msg.add_query(q);
        msg
    }

    fn make_response(query: &Message, ip: Ipv4Addr, ttl: u32) -> Vec<u8> {
        let mut resp = Message::new();
        let mut header = Header::new();
        header.set_id(query.id());
        header.set_message_type(MessageType::Response);
        header.set_op_code(OpCode::Query);
        header.set_response_code(ResponseCode::NoError);
        header.set_recursion_desired(true);
        header.set_recursion_available(true);
        resp.set_header(header);
        resp.add_queries(query.queries().to_vec());

        let record = Record::from_rdata(
            query.queries()[0].name().clone(),
            ttl,
            RData::A(A(ip)),
        );
        resp.add_answer(record);
        resp.to_vec().unwrap()
    }

    #[test]
    fn test_cache_miss_on_empty() {
        let cache = DnsCache::new(100, 60, 86400);
        let query = make_query("example.com.", RecordType::A);
        assert!(cache.get(&query).is_none());
    }

    #[test]
    fn test_cache_hit_after_put() {
        let cache = DnsCache::new(100, 60, 86400);
        let query = make_query("example.com.", RecordType::A);
        let response = make_response(&query, Ipv4Addr::new(1, 2, 3, 4), 300);

        cache.put(&query, &response);
        let cached = cache.get(&query);
        assert!(cached.is_some());

        // Verify the cached response is a valid DNS message
        let msg = Message::from_vec(&cached.unwrap()).unwrap();
        assert!(!msg.answers().is_empty());
    }

    #[test]
    fn test_cache_case_insensitive() {
        let cache = DnsCache::new(100, 60, 86400);
        let query_lower = make_query("example.com.", RecordType::A);
        let query_upper = make_query("EXAMPLE.COM.", RecordType::A);
        let response = make_response(&query_lower, Ipv4Addr::new(1, 2, 3, 4), 300);

        cache.put(&query_lower, &response);
        // Should find it with different case
        assert!(cache.get(&query_upper).is_some());
    }

    #[test]
    fn test_cache_different_record_types_separate() {
        let cache = DnsCache::new(100, 60, 86400);
        let query_a = make_query("example.com.", RecordType::A);
        let query_aaaa = make_query("example.com.", RecordType::AAAA);
        let response = make_response(&query_a, Ipv4Addr::new(1, 2, 3, 4), 300);

        cache.put(&query_a, &response);
        assert!(cache.get(&query_a).is_some());
        // AAAA query for same name should miss
        assert!(cache.get(&query_aaaa).is_none());
    }

    #[test]
    fn test_cache_expiry() {
        // Use a min_ttl of 1 second so the entry expires quickly
        let cache = DnsCache::new(100, 1, 1);
        let query = make_query("expire-test.com.", RecordType::A);
        let response = make_response(&query, Ipv4Addr::new(10, 0, 0, 1), 1);

        cache.put(&query, &response);
        assert!(cache.get(&query).is_some());

        // Wait for expiry
        thread::sleep(Duration::from_millis(1100));
        assert!(cache.get(&query).is_none());
    }

    #[test]
    fn test_cache_eviction_lru() {
        let cache = DnsCache::new(2, 60, 86400);

        let q1 = make_query("one.com.", RecordType::A);
        let q2 = make_query("two.com.", RecordType::A);
        let q3 = make_query("three.com.", RecordType::A);

        let r1 = make_response(&q1, Ipv4Addr::new(1, 0, 0, 1), 300);
        let r2 = make_response(&q2, Ipv4Addr::new(2, 0, 0, 1), 300);
        let r3 = make_response(&q3, Ipv4Addr::new(3, 0, 0, 1), 300);

        cache.put(&q1, &r1);
        cache.put(&q2, &r2);
        // Both should be present
        assert!(cache.get(&q1).is_some());
        assert!(cache.get(&q2).is_some());

        // Adding a third should evict the LRU (q1 was accessed last via get above,
        // so q2's get made q1 the LRU... actually both were accessed. Let's be more precise.)
        // After get(q1) then get(q2), q1 is LRU. Adding q3 evicts q1.
        cache.put(&q3, &r3);
        // q1 was least recently used before q3 was inserted
        // Actually after get(q1), get(q2): q2 is MRU, q1 is LRU
        assert!(cache.get(&q1).is_none(), "q1 should have been evicted");
        assert!(cache.get(&q2).is_some());
        assert!(cache.get(&q3).is_some());
    }

    #[test]
    fn test_cache_ttl_clamping() {
        // min_ttl=120, max_ttl=600
        let cache = DnsCache::new(100, 120, 600);
        let query = make_query("ttl-test.com.", RecordType::A);
        // Response has TTL of 10, which is below min_ttl
        let response = make_response(&query, Ipv4Addr::new(5, 5, 5, 5), 10);

        cache.put(&query, &response);
        // Should still be cached (clamped to min_ttl=120)
        let cached = cache.get(&query);
        assert!(cached.is_some());

        let msg = Message::from_vec(&cached.unwrap()).unwrap();
        // TTL in response should be <= 120 (the clamped value)
        let answer_ttl = msg.answers()[0].ttl();
        assert!(answer_ttl <= 120);
    }

    #[test]
    fn test_cache_id_rewriting() {
        let cache = DnsCache::new(100, 60, 86400);
        let query = make_query("id-test.com.", RecordType::A);
        let response = make_response(&query, Ipv4Addr::new(1, 1, 1, 1), 300);

        cache.put(&query, &response);

        // Make a new query with a different ID
        let mut query2 = make_query("id-test.com.", RecordType::A);
        query2.set_id(9999);

        let cached = cache.get(&query2);
        assert!(cached.is_some());
        // The cached response still has the original wire bytes,
        // but the caller (DohClient) would normally rewrite the ID
    }
}
