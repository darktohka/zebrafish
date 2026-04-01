use std::net::SocketAddr;
use std::sync::Arc;

use hickory_proto::op::{Header, Message, MessageType, OpCode, ResponseCode};
use tokio::net::{TcpListener, UdpSocket};
use tracing::{debug, error, info, warn};

use crate::doh::DohClient;

pub struct DnsServer {
    client: Arc<DohClient>,
    listen_addr_v4: String,
    listen_addr_v6: String,
    listen_port: u16,
}

impl DnsServer {
    pub fn new(client: Arc<DohClient>, listen_addr_v4: String, listen_addr_v6: String, listen_port: u16) -> Self {
        Self {
            client,
            listen_addr_v4,
            listen_addr_v6,
            listen_port,
        }
    }

    pub async fn run(self: Arc<Self>) -> Result<(), Box<dyn std::error::Error>> {
        let mut tasks = tokio::task::JoinSet::new();
        let mut listener_count = 0usize;

        // IPv4 UDP
        let addr_v4 = format!("{}:{}", self.listen_addr_v4, self.listen_port);
        match addr_v4.parse::<SocketAddr>() {
            Ok(udp_addr_v4) => match UdpSocket::bind(udp_addr_v4).await {
                Ok(udp_v4) => {
                    info!(addr = %udp_addr_v4, "Listening for DNS queries (UDP IPv4)");
                    listener_count += 1;
                    let server = self.clone();
                    tasks.spawn(async move {
                        server.serve_udp(udp_v4).await;
                    });
                }
                Err(e) => warn!(addr = %udp_addr_v4, error = %e, "Could not bind IPv4 UDP"),
            },
            Err(e) => warn!(addr = %addr_v4, error = %e, "Invalid IPv4 address"),
        }

        // IPv4 TCP
        match addr_v4.parse::<SocketAddr>() {
            Ok(tcp_addr_v4) => match TcpListener::bind(tcp_addr_v4).await {
                Ok(tcp_v4) => {
                    info!(addr = %tcp_addr_v4, "Listening for DNS queries (TCP IPv4)");
                    listener_count += 1;
                    let server = self.clone();
                    tasks.spawn(async move {
                        server.serve_tcp(tcp_v4).await;
                    });
                }
                Err(e) => warn!(addr = %tcp_addr_v4, error = %e, "Could not bind IPv4 TCP"),
            },
            Err(e) => warn!(addr = %addr_v4, error = %e, "Invalid IPv4 address"),
        }

        // IPv6 UDP
        if !self.listen_addr_v6.is_empty() {
            let addr_v6 = format!("[{}]:{}", self.listen_addr_v6, self.listen_port);
            match addr_v6.parse::<SocketAddr>() {
                Ok(udp_addr_v6) => match UdpSocket::bind(udp_addr_v6).await {
                    Ok(udp_v6) => {
                        info!(addr = %udp_addr_v6, "Listening for DNS queries (UDP IPv6)");
                        listener_count += 1;
                        let server = self.clone();
                        tasks.spawn(async move {
                            server.serve_udp(udp_v6).await;
                        });
                    }
                    Err(e) => warn!(addr = %udp_addr_v6, error = %e, "Could not bind IPv6 UDP"),
                },
                Err(e) => warn!(addr = %addr_v6, error = %e, "Invalid IPv6 address"),
            }

            // IPv6 TCP
            match addr_v6.parse::<SocketAddr>() {
                Ok(tcp_addr_v6) => match TcpListener::bind(tcp_addr_v6).await {
                    Ok(tcp_v6) => {
                        info!(addr = %tcp_addr_v6, "Listening for DNS queries (TCP IPv6)");
                        listener_count += 1;
                        let server = self.clone();
                        tasks.spawn(async move {
                            server.serve_tcp(tcp_v6).await;
                        });
                    }
                    Err(e) => warn!(addr = %tcp_addr_v6, error = %e, "Could not bind IPv6 TCP"),
                },
                Err(e) => warn!(addr = %addr_v6, error = %e, "Invalid IPv6 address"),
            }
        }

        if listener_count == 0 {
            return Err(std::io::Error::new(
                std::io::ErrorKind::AddrNotAvailable,
                "failed to initialize any DNS listener (IPv4/IPv6 UDP/TCP)",
            )
            .into());
        }

        while let Some(result) = tasks.join_next().await {
            warn!("DNS listener task exited: {:?}", result);
        }

        Err(std::io::Error::other("all DNS listener tasks exited").into())
    }

    async fn serve_udp(&self, socket: UdpSocket) {
        let socket = Arc::new(socket);
        let mut buf = vec![0u8; 4096];

        loop {
            match socket.recv_from(&mut buf).await {
                Ok((len, src)) => {
                    let query = buf[..len].to_vec();
                    let client = self.client.clone();
                    let sock = socket.clone();

                    tokio::spawn(async move {
                        match client.resolve(&query).await {
                            Ok(response) => {
                                if let Err(e) = sock.send_to(&response, src).await {
                                    error!(error = %e, "Failed to send UDP response");
                                }
                            }
                            Err(e) => {
                                error!(error = %e, "Failed to resolve query");
                                if let Some(servfail) = Self::build_servfail(&query) {
                                    let _ = sock.send_to(&servfail, src).await;
                                }
                            }
                        }
                    });
                }
                Err(e) => {
                    error!(error = %e, "UDP recv error");
                }
            }
        }
    }

    async fn serve_tcp(&self, listener: TcpListener) {
        loop {
            match listener.accept().await {
                Ok((stream, src)) => {
                    let client = self.client.clone();
                    tokio::spawn(async move {
                        if let Err(e) = Self::handle_tcp_connection(stream, client).await {
                            debug!(src = %src, error = %e, "TCP connection error");
                        }
                    });
                }
                Err(e) => {
                    error!(error = %e, "TCP accept error");
                }
            }
        }
    }

    async fn handle_tcp_connection(
        mut stream: tokio::net::TcpStream,
        client: Arc<DohClient>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};

        loop {
            // DNS over TCP: 2-byte length prefix
            let mut len_buf = [0u8; 2];
            match stream.read_exact(&mut len_buf).await {
                Ok(_) => {}
                Err(ref e) if e.kind() == std::io::ErrorKind::UnexpectedEof => break,
                Err(e) => return Err(e.into()),
            }
            let msg_len = u16::from_be_bytes(len_buf) as usize;
            if msg_len == 0 || msg_len > 65535 {
                break;
            }

            let mut query = vec![0u8; msg_len];
            stream.read_exact(&mut query).await?;

            let response = match client.resolve(&query).await {
                Ok(r) => r,
                Err(e) => {
                    error!(error = %e, "Failed to resolve TCP query");
                    match Self::build_servfail(&query) {
                        Some(r) => r,
                        None => break,
                    }
                }
            };

            let resp_len = (response.len() as u16).to_be_bytes();
            stream.write_all(&resp_len).await?;
            stream.write_all(&response).await?;
        }

        Ok(())
    }

    /// Build a SERVFAIL response for a failed query.
    fn build_servfail(query_bytes: &[u8]) -> Option<Vec<u8>> {
        let query = Message::from_vec(query_bytes).ok()?;
        let mut response = Message::new();
        let mut header = Header::new();
        header.set_id(query.id());
        header.set_message_type(MessageType::Response);
        header.set_op_code(OpCode::Query);
        header.set_response_code(ResponseCode::ServFail);
        header.set_recursion_desired(query.recursion_desired());
        header.set_recursion_available(true);
        response.set_header(header);
        response.add_queries(query.queries().to_vec());
        response.to_vec().ok()
    }
}
