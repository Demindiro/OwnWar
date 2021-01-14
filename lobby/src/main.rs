use std::collections::HashMap;
use std::convert::TryFrom;
use std::mem::size_of;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, UdpSocket};
use std::time::{Duration, Instant};

macro_rules! debug {
	($($x:tt)*) => {
		{
			#[cfg(debug_assertions)]
			{
				print!("[DEBUG] ");
				println!($($x)*);
			}
			#[cfg(not(debug_assertions))]
			{
				($($x)*);
			}
		}
	}
}

struct ServerInfo {
	name: Box<str>,
	map: Box<str>,
	max_players: u8,
	description: Box<str>,
	last_ping: Instant,
	manager_port: u16,
}

#[repr(u8)]
enum MessageType {
	GetServerList = 0,
	RegisterServer = 1,
	RemoveServer = 2,
	Ping = 3,
	ServerInfo = 4,
	PunchHole = 5,
}

impl TryFrom<u8> for MessageType {
	type Error = ();

	fn try_from(value: u8) -> Result<Self, Self::Error> {
		use MessageType::*;
		Ok(match value {
			0 => GetServerList,
			1 => RegisterServer,
			2 => RemoveServer,
			3 => Ping,
			4 => ServerInfo,
			5 => PunchHole,
			_ => return Err(()),
		})
	}
}

fn main() {
	let socket = UdpSocket::bind("0.0.0.0:39984").unwrap();
	let mut rcv = [0; 4096];
	let mut list = HashMap::<SocketAddr, ServerInfo>::new();
	let mut time_start = Instant::now();
	loop {
		let (size, addr) = socket.recv_from(&mut rcv).unwrap();
		// Remove first so we don't send stale entries
		let now = Instant::now();
		if now - time_start >= Duration::new(60, 0) {
			let mut remove_addrs = Vec::new();
			for (addr, info) in list.iter() {
				if now - info.last_ping >= Duration::new(60, 0) {
					remove_addrs.push(*addr);
				}
			}
			for addr in remove_addrs {
				println!("Removed {}", addr);
				list.remove(&addr);
			}
			time_start = now;
		}
		debug!("Request from {} - {} bytes", addr, size);
		if let Some(rsp) = parse_packet(&mut list, addr, &rcv[..size], &socket) {
			debug!("Sending response - {} bytes", rsp.len());
			socket.send_to(&rsp, addr).unwrap();
		}
	}
}

fn parse_packet(
	list: &mut HashMap<SocketAddr, ServerInfo>,
	addr: SocketAddr,
	buf: &[u8],
	send_socket: &UdpSocket,
) -> Option<Box<[u8]>> {
	if buf.len() < 1 {
		debug!("invalid packet size {}", buf.len());
		return None;
	}
	let typ = MessageType::try_from(buf[0])
		.or_else(|_| {
			debug!("invalid packet type: {}", buf[1]);
			Err(())
		})
		.ok()?;
	match typ {
		MessageType::GetServerList => {
			debug!("list servers");
			let mut rsp = Vec::new();
			rsp.push(buf[0]);
			// 239 entries is the safe upper bound right now
			// 2 ^ 16 / (16 + 2 + 1 + 255) = ~239.18
			for (ad, info) in list.iter().take(239) {
				encode_addr(*ad, &mut rsp);
				rsp.push(info.name.len() as u8);
				rsp.extend(info.name.as_bytes());
			}
			Some(rsp.into_boxed_slice())
		}
		MessageType::RegisterServer => {
			debug!("register server");
			let mut rsp = Vec::new();
			rsp.push(buf[0]);
			let buf = &buf[1..];
			let port = decode_u16(&buf[..2])
				.or_else(|_| {
					debug!("invalid packet size {}", buf.len());
					Err(())
				})
				.ok()?;
			let buf = &buf[2..];
			let name = decode_str::<u8>(buf)
				.or_else(|_| {
					debug!("Failed to decode name");
					Err(())
				})
				.ok()?;
			let buf = &buf[1 + name.len()..];
			let map = decode_str::<u8>(buf)
				.or_else(|_| {
					debug!("Failed to decode map");
					Err(())
				})
				.ok()?;
			let buf = &buf[1 + map.len()..];
			let max_players = *buf.get(0).or_else(|| {
				debug!("Invalid packet size {}", buf.len());
				None
			})?;
			let buf = &buf[1..];
			let descr = decode_str::<u16>(buf)
				.or_else(|_| {
					debug!("Failed to decode description");
					Err(())
				})
				.ok()?;
			let for_addr = SocketAddr::new(addr.ip(), port);
			list.insert(
				for_addr,
				ServerInfo {
					last_ping: Instant::now(),
					name: String::from(name).into_boxed_str(),
					map: String::from(map).into_boxed_str(),
					max_players,
					description: String::from(descr).into_boxed_str(),
					manager_port: addr.port(),
				},
			);
			println!(
				"{} registered a server - port {} name '{}', map '{}', max players {}, description '{}'",
				addr, for_addr.port(), name, map, max_players, descr
			);
			rsp.push(0); // OK = 0
			Some(rsp.into_boxed_slice())
		}
		MessageType::RemoveServer => {
			debug!("remove server");
			let port = decode_u16(buf)
				.or_else(|_| {
					debug!("invalid packet size {}", buf.len());
					Err(())
				})
				.ok()?;
			let addr = &SocketAddr::new(addr.ip(), port);
			println!("Removed server {}", addr);
			list.remove(addr);
			None
		}
		MessageType::Ping => {
			debug!("ping");
			let port = decode_u16(&buf[1..])
				.or_else(|_| {
					debug!("invalid packet size {}", buf.len());
					Err(())
				})
				.ok()?;
			if let Some(e) = list.get_mut(&SocketAddr::new(addr.ip(), port)) {
				e.last_ping = Instant::now();
			}
			None
		}
		MessageType::ServerInfo => {
			debug!("info");
			let mut rsp = Vec::new();
			rsp.push(buf[0]);
			let (addr, buf) = decode_addr(&buf[1..]).ok()?;
			list.get(&addr).and_then(|info| {
				rsp.push(info.max_players);
				rsp.push(info.map.len() as u8);
				rsp.extend(info.map.as_bytes());
				rsp.extend(&(info.description.len() as u16).to_le_bytes());
				rsp.extend(info.description.as_bytes());
				Some(())
			})?;
			Some(rsp.into_boxed_slice())
		}
		MessageType::PunchHole => {
			debug!("punch hole");
			let mut pkt = Vec::new();
			pkt.push(buf[0]);
			let (server_addr, buf) = decode_addr(&buf[1..]).ok()?;
			pkt.extend(&server_addr.port().to_le_bytes());
			encode_addr(addr, &mut pkt);
			let info = list.get(&server_addr).or_else(|| {
				debug!("invalid entry - {}", addr);
				None
			})?;
			let manager_addr = SocketAddr::new(server_addr.ip(), info.manager_port);
			send_socket.send_to(pkt.as_slice(), manager_addr);
			None
		}
	}
}

trait FromLeBytes {
	fn from_le_bytes(slice: &[u8]) -> Self;
}

impl FromLeBytes for u8 {
	fn from_le_bytes(slice: &[u8]) -> Self {
		Self::from_le_bytes(<[u8; size_of::<Self>()]>::try_from(slice).unwrap())
	}
}

impl FromLeBytes for u16 {
	fn from_le_bytes(slice: &[u8]) -> Self {
		Self::from_le_bytes(<[u8; size_of::<Self>()]>::try_from(slice).unwrap())
	}
}

fn decode_str<T: FromLeBytes + Into<usize>>(buf: &[u8]) -> Result<&str, ()> {
	if buf.len() < size_of::<T>() {
		debug!("missing length or length too short");
		return Err(());
	}
	let (len_bytes, rest) = buf.split_at(size_of::<T>());
	let len = T::from_le_bytes(len_bytes).into();
	if rest.len() < len {
		debug!("length {} is larger than buffer size {}", len, buf.len());
		return Err(());
	}
	std::str::from_utf8(&rest[..len]).map_err(|e| debug!("invalid utf8 string as name {:?}", e))
}

fn decode_u16(buf: &[u8]) -> Result<u16, ()> {
	if let Ok(array) = <[u8; 2]>::try_from(buf) {
		Ok(u16::from_le_bytes(array))
	} else {
		Err(())
	}
}

fn decode_addr(buf: &[u8]) -> Result<(SocketAddr, &[u8]), ()> {
	let addr_type = if let Some(v) = buf.get(0) {
		*v
	} else {
		return Err(());
	};
	let buf = &buf[1..];
	let (addr, buf) = if addr_type == 0 {
		if buf.len() < 6 {
			debug!("Invalid packet size {}", buf.len());
			return Err(());
		}
		(
			IpAddr::V4(Ipv4Addr::new(buf[0], buf[1], buf[2], buf[3])),
			&buf[4..],
		)
	} else {
		if buf.len() < 18 {
			debug!("Invalid packet size {}", buf.len());
			return Err(());
		}
		let mut s = [0; 8];
		for (i, n) in s.iter_mut().enumerate() {
			*n = decode_u16(&buf[i * 2..i * 2 + 1]).unwrap();
		}
		(
			IpAddr::V6(Ipv6Addr::new(
				s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7],
			)),
			&buf[16..],
		)
	};
	Ok((
		SocketAddr::new(addr, decode_u16(&buf[..2]).unwrap()),
		&buf[2..],
	))
}

fn encode_addr(addr: SocketAddr, buf: &mut Vec<u8>) {
	match addr.ip() {
		IpAddr::V4(v) => {
			buf.push(0);
			buf.extend(&v.octets()[..])
		}
		IpAddr::V6(v) => {
			buf.push(1);
			for s in &v.segments() {
				buf.extend(&s.to_le_bytes())
			}
		}
	}
	buf.extend(&addr.port().to_le_bytes());
}
