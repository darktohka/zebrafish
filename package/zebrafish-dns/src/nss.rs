//! NSS (Name Service Switch) module for zebrafish-dns.
//!
//! This shared library hooks into the system's libc resolver via NSS,
//! redirecting DNS lookups through the local zebrafish-dns server.
//!
//! Install as: /lib/libnss_zebrafish.so.2
//! Configure in /etc/nsswitch.conf:
//!   hosts: zebrafish files dns

use std::ffi::CStr;
use std::net::{IpAddr, SocketAddr, UdpSocket};
use std::ptr;
use std::time::Duration;

use hickory_proto::op::{Message, MessageType, OpCode, Query};
use hickory_proto::rr::rdata::{A, AAAA};
use hickory_proto::rr::record_data::RData;
use hickory_proto::rr::{Name, RecordType};

/// NSS status codes matching glibc's nss_status enum.
#[repr(i32)]
#[allow(dead_code)]
pub enum NssStatus {
    TryAgain = -2,
    Unavail = -1,
    NotFound = 0,
    Success = 1,
}

/// Address family constants.
const AF_INET: i32 = 2;
const AF_INET6: i32 = 10;

/// gaih_addrtuple used by glibc's _gethostbyname4_r.
#[repr(C)]
#[allow(dead_code)]
pub struct GaiAddrTuple {
    next: *mut GaiAddrTuple,
    name: *const libc::c_char,
    family: i32,
    addr: [u8; 16],
    scopeid: u32,
}

const DNS_SERVER: &str = "127.0.0.1:53";
const QUERY_TIMEOUT: Duration = Duration::from_secs(3);

/// Perform a DNS query to the local zebrafish-dns server.
fn query_local_dns(name: &str, record_type: RecordType) -> Option<Vec<IpAddr>> {
    let dns_name = Name::from_utf8(name).ok()?;
    let mut query = Query::new();
    query.set_name(dns_name);
    query.set_query_type(record_type);

    let mut msg = Message::new();
    msg.set_id(rand_id());
    msg.set_message_type(MessageType::Query);
    msg.set_op_code(OpCode::Query);
    msg.set_recursion_desired(true);
    msg.add_query(query);

    let wire = msg.to_vec().ok()?;

    let addr: SocketAddr = DNS_SERVER.parse().ok()?;
    let socket = UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.set_read_timeout(Some(QUERY_TIMEOUT)).ok()?;
    socket.set_write_timeout(Some(QUERY_TIMEOUT)).ok()?;
    socket.send_to(&wire, addr).ok()?;

    let mut buf = vec![0u8; 4096];
    let len = socket.recv(&mut buf).ok()?;
    let response = Message::from_vec(&buf[..len]).ok()?;

    let mut addrs = Vec::new();
    for record in response.answers() {
        match record.data() {
            RData::A(A(ipv4)) => {
                if record_type == RecordType::A {
                    addrs.push(IpAddr::V4(*ipv4));
                }
            }
            RData::AAAA(AAAA(ipv6)) => {
                if record_type == RecordType::AAAA {
                    addrs.push(IpAddr::V6(*ipv6));
                }
            }
            _ => {}
        }
    }

    if addrs.is_empty() {
        None
    } else {
        Some(addrs)
    }
}

fn rand_id() -> u16 {
    // Simple non-cryptographic ID from system time
    let t = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    ((t.subsec_nanos() ^ (t.as_secs() as u32)) & 0xFFFF) as u16
}

/// NSS entry point: _nss_zebrafish_gethostbyname4_r
///
/// This is the modern NSS interface used by getaddrinfo().
#[no_mangle]
pub unsafe extern "C" fn _nss_zebrafish_gethostbyname4_r(
    name: *const libc::c_char,
    pat: *mut *mut GaiAddrTuple,
    buffer: *mut libc::c_char,
    buflen: libc::size_t,
    errnop: *mut libc::c_int,
    h_errnop: *mut libc::c_int,
    _ttlp: *mut i32,
) -> NssStatus {
    if name.is_null() || pat.is_null() || buffer.is_null() {
        return NssStatus::Unavail;
    }

    let hostname = match CStr::from_ptr(name).to_str() {
        Ok(s) => s,
        Err(_) => return NssStatus::Unavail,
    };

    // Don't intercept "localhost" or similar
    if hostname == "localhost" || hostname == "localhost.localdomain" {
        return NssStatus::NotFound;
    }

    let mut all_addrs = Vec::new();

    if let Some(addrs) = query_local_dns(hostname, RecordType::A) {
        all_addrs.extend(addrs);
    }
    if let Some(addrs) = query_local_dns(hostname, RecordType::AAAA) {
        all_addrs.extend(addrs);
    }

    if all_addrs.is_empty() {
        *errnop = libc::ENOENT;
        *h_errnop = 1; // HOST_NOT_FOUND
        return NssStatus::NotFound;
    }

    // Check buffer space
    let needed = all_addrs.len() * std::mem::size_of::<GaiAddrTuple>();
    if needed > buflen {
        *errnop = libc::ERANGE;
        *h_errnop = 3; // NETDB_INTERNAL
        return NssStatus::TryAgain;
    }

    let tuples = buffer as *mut GaiAddrTuple;

    for (i, addr) in all_addrs.iter().enumerate() {
        let tuple = &mut *tuples.add(i);
        tuple.next = if i + 1 < all_addrs.len() {
            tuples.add(i + 1)
        } else {
            ptr::null_mut()
        };
        tuple.name = name;
        tuple.scopeid = 0;

        match addr {
            IpAddr::V4(v4) => {
                tuple.family = AF_INET;
                tuple.addr = [0u8; 16];
                tuple.addr[..4].copy_from_slice(&v4.octets());
            }
            IpAddr::V6(v6) => {
                tuple.family = AF_INET6;
                tuple.addr = v6.octets();
            }
        }
    }

    *pat = tuples;
    NssStatus::Success
}

/// NSS entry point: _nss_zebrafish_gethostbyname3_r
///
/// Older glibc interface for gethostbyname_r with AF hint.
#[no_mangle]
pub unsafe extern "C" fn _nss_zebrafish_gethostbyname3_r(
    name: *const libc::c_char,
    af: libc::c_int,
    result: *mut libc::hostent,
    buffer: *mut libc::c_char,
    buflen: libc::size_t,
    errnop: *mut libc::c_int,
    h_errnop: *mut libc::c_int,
    _ttlp: *mut i32,
    _canonp: *mut *mut libc::c_char,
) -> NssStatus {
    _nss_zebrafish_gethostbyname_r(name, af, result, buffer, buflen, errnop, h_errnop)
}

/// NSS entry point: _nss_zebrafish_gethostbyname2_r
#[no_mangle]
pub unsafe extern "C" fn _nss_zebrafish_gethostbyname2_r(
    name: *const libc::c_char,
    af: libc::c_int,
    result: *mut libc::hostent,
    buffer: *mut libc::c_char,
    buflen: libc::size_t,
    errnop: *mut libc::c_int,
    h_errnop: *mut libc::c_int,
) -> NssStatus {
    _nss_zebrafish_gethostbyname_r(name, af, result, buffer, buflen, errnop, h_errnop)
}

/// Core implementation for gethostbyname variants.
#[no_mangle]
pub unsafe extern "C" fn _nss_zebrafish_gethostbyname_r(
    name: *const libc::c_char,
    af: libc::c_int,
    result: *mut libc::hostent,
    buffer: *mut libc::c_char,
    buflen: libc::size_t,
    errnop: *mut libc::c_int,
    h_errnop: *mut libc::c_int,
) -> NssStatus {
    if name.is_null() || result.is_null() || buffer.is_null() {
        return NssStatus::Unavail;
    }

    let hostname = match CStr::from_ptr(name).to_str() {
        Ok(s) => s,
        Err(_) => return NssStatus::Unavail,
    };

    if hostname == "localhost" || hostname == "localhost.localdomain" {
        return NssStatus::NotFound;
    }

    let record_type = match af {
        AF_INET => RecordType::A,
        AF_INET6 => RecordType::AAAA,
        _ => return NssStatus::NotFound,
    };

    let addrs = match query_local_dns(hostname, record_type) {
        Some(a) if !a.is_empty() => a,
        _ => {
            *errnop = libc::ENOENT;
            *h_errnop = 1; // HOST_NOT_FOUND
            return NssStatus::NotFound;
        }
    };

    let addr_size = if af == AF_INET { 4usize } else { 16usize };

    // Calculate buffer space needed:
    // - hostname string + null
    // - address data (addr_size * count)
    // - pointer array (count + 1 null terminator) * pointer size
    // - alias null pointer
    let name_len = hostname.len() + 1;
    let needed = name_len
        + addr_size * addrs.len()
        + (addrs.len() + 1) * std::mem::size_of::<*mut libc::c_char>()
        + std::mem::size_of::<*mut libc::c_char>();

    if needed > buflen {
        *errnop = libc::ERANGE;
        *h_errnop = 3; // NETDB_INTERNAL
        return NssStatus::TryAgain;
    }

    let buf = buffer as *mut u8;
    let mut offset = 0usize;

    // Write hostname
    let h_name = buf.add(offset) as *mut libc::c_char;
    ptr::copy_nonoverlapping(hostname.as_ptr(), buf.add(offset), hostname.len());
    *buf.add(offset + hostname.len()) = 0;
    offset += name_len;

    // Write address data
    let addr_data_start = offset;
    for addr in &addrs {
        match addr {
            IpAddr::V4(v4) => {
                ptr::copy_nonoverlapping(v4.octets().as_ptr(), buf.add(offset), 4);
                offset += 4;
            }
            IpAddr::V6(v6) => {
                ptr::copy_nonoverlapping(v6.octets().as_ptr(), buf.add(offset), 16);
                offset += 16;
            }
        }
    }

    // Write address pointer list
    // Align offset
    let align = std::mem::align_of::<*mut libc::c_char>();
    offset = (offset + align - 1) & !(align - 1);

    let h_addr_list = buf.add(offset) as *mut *mut libc::c_char;
    for i in 0..addrs.len() {
        *h_addr_list.add(i) = buf.add(addr_data_start + i * addr_size) as *mut libc::c_char;
    }
    *h_addr_list.add(addrs.len()) = ptr::null_mut();
    offset += (addrs.len() + 1) * std::mem::size_of::<*mut libc::c_char>();

    // Write empty aliases
    let h_aliases = buf.add(offset) as *mut *mut libc::c_char;
    *h_aliases = ptr::null_mut();

    // Fill hostent
    (*result).h_name = h_name;
    (*result).h_aliases = h_aliases;
    (*result).h_addrtype = af;
    (*result).h_length = addr_size as i32;
    (*result).h_addr_list = h_addr_list;

    NssStatus::Success
}
