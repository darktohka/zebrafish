use std::fs::OpenOptions;
use std::io::{self, Write};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct QueryLogEntry {
    pub timestamp: String,
    pub client_ip: String,
    pub client_port: u16,
    pub protocol: String,
    pub query_id: u16,
    pub qname: String,
    pub qtype: String,
    pub qclass: String,
    pub response_code: String,
    pub answer_count: u16,
    pub authority_count: u16,
    pub additional_count: u16,
    pub query_size: usize,
    pub response_size: usize,
    pub cached: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub upstream_status: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub upstream_latency_ms: Option<u64>,
    pub total_latency_ms: u64,
    pub pid: u32,
}

pub struct QueryLogger {
    enabled: bool,
    writer: Mutex<Box<dyn Write + Send + 'static>>,
    pid: u32,
}

impl QueryLogger {
    pub fn disabled() -> Self {
        Self {
            enabled: false,
            writer: Mutex::new(Box::new(io::sink())),
            pid: 0,
        }
    }

    pub fn new(output: Option<String>) -> io::Result<Self> {
        let writer: Box<dyn Write + Send + 'static> = match output {
            None => Box::new(io::stdout()),
            Some(ref p) if p.is_empty() || p == "-" => Box::new(io::stdout()),
            Some(ref path) => {
                let file = OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(path)?;
                Box::new(file)
            }
        };

        Ok(Self {
            enabled: true,
            writer: Mutex::new(writer),
            pid: std::process::id(),
        })
    }

    pub fn log_entry(&self, entry: &QueryLogEntry) {
        if !self.enabled {
            return;
        }
        if let Ok(writer) = &mut self.writer.lock() {
            if let Ok(json) = serde_json::to_string(entry) {
                let _ = writeln!(writer, "{json}");
            }
        }
    }

    pub fn log(
        &self,
        client_ip: &str,
        client_port: u16,
        protocol: &str,
        query_bytes: &[u8],
        response_bytes: &[u8],
        cached: bool,
        upstream_status: Option<u16>,
        upstream_latency_ms: Option<u64>,
        total_latency_ms: u64,
    ) {
        if !self.enabled {
            return;
        }

        let query_msg = hickory_proto::op::Message::from_vec(query_bytes).ok();
        let resp_msg = hickory_proto::op::Message::from_vec(response_bytes).ok();

        let query = query_msg.as_ref().and_then(|m| m.queries().first());

        let entry = QueryLogEntry {
            timestamp: rfc3339(),
            client_ip: client_ip.to_string(),
            client_port,
            protocol: protocol.to_string(),
            query_id: query_msg.as_ref().map(|m| m.id()).unwrap_or(0),
            qname: query
                .map(|q| q.name().to_string())
                .unwrap_or_default(),
            qtype: query
                .map(|q| q.query_type().to_string())
                .unwrap_or_default(),
            qclass: query
                .map(|q| q.query_class().to_string())
                .unwrap_or_default(),
            response_code: resp_msg
                .as_ref()
                .map(|m| format!("{0}", m.response_code()))
                .unwrap_or_default(),
            answer_count: resp_msg.as_ref().map(|m| m.answers().len() as u16).unwrap_or(0),
            authority_count: resp_msg
                .as_ref()
                .map(|m| m.name_servers().len() as u16)
                .unwrap_or(0),
            additional_count: resp_msg
                .as_ref()
                .map(|m| m.additionals().len() as u16)
                .unwrap_or(0),
            query_size: query_bytes.len(),
            response_size: response_bytes.len(),
            cached,
            upstream_status,
            upstream_latency_ms,
            total_latency_ms,
            pid: self.pid,
        };

        self.log_entry(&entry);
    }
}

fn rfc3339() -> String {
    let d = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    let total_secs = d.as_secs();
    let millis = d.subsec_millis();

    let (y, m, d) = days_to_date(total_secs / 86400);
    let t = total_secs % 86400;
    let h = t / 3600;
    let mi = (t % 3600) / 60;
    let s = t % 60;

    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}.{:03}Z", y, m, d, h, mi, s, millis)
}

fn days_to_date(days: u64) -> (i32, u32, u32) {
    let z = days as i64 + 719468;
    let era = (if z >= 0 { z } else { z - 146096 }) / 146097;
    let doe = (z - era * 146097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era as u64 * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    (y as i32, m as u32, d as u32)
}
