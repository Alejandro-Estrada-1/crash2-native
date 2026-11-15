//! Cálculo en una sola pasada de tamaño, CRC-32, MD5 y SHA-1.

use std::fmt::Write as _;
use std::fs::File;
use std::io::{self, BufReader, Read};
use std::path::Path;

const READ_BUFFER_SIZE: usize = 1024 * 1024;
const IEEE_CRC32_POLY: u32 = 0xEDB8_8320;

/// Resultados de integridad de una pista de datos.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiscDigests {
    pub size: u64,
    pub crc32: String,
    pub md5: String,
    pub sha1: String,
}

/// Calcula tamaño, CRC-32 (IEEE 802.3), MD5 y SHA-1 leyendo `path` solo una vez.
pub fn compute_file_digests(path: &Path) -> io::Result<DiscDigests> {
    let file = File::open(path)?;
    let mut reader = BufReader::with_capacity(READ_BUFFER_SIZE, file);
    let mut buf = vec![0u8; READ_BUFFER_SIZE];

    let mut crc = Crc32::new();
    let mut md5 = Md5::new();
    let mut sha1 = Sha1::new();
    let mut size: u64 = 0;

    loop {
        let n = reader.read(&mut buf)?;
        if n == 0 {
            break;
        }
        let chunk = &buf[..n];
        size += n as u64;
        crc.update(chunk);
        md5.update(chunk);
        sha1.update(chunk);
    }

    Ok(DiscDigests {
        size,
        crc32: format!("{:08x}", crc.finalize()),
        md5: to_hex(&md5.finalize()),
        sha1: to_hex(&sha1.finalize()),
    })
}

fn to_hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        let _ = write!(&mut out, "{:02x}", b);
    }
    out
}

/// Acumulador CRC-32 IEEE 802.3 con tabla precalculada en compilación.
pub struct Crc32 {
    state: u32,
}

const CRC32_TABLE: [u32; 256] = {
    let mut table = [0u32; 256];
    let mut i = 0;
    while i < 256 {
        let mut c = i as u32;
        let mut k = 0;
        while k < 8 {
            c = if c & 1 != 0 {
                (c >> 1) ^ IEEE_CRC32_POLY
            } else {
                c >> 1
            };
            k += 1;
        }
        table[i] = c;
        i += 1;
    }
    table
};

impl Crc32 {
    pub fn new() -> Self {
        Self { state: !0u32 }
    }

    pub fn update(&mut self, data: &[u8]) {
        for &b in data {
            let idx = ((self.state as u8) ^ b) as usize;
            self.state = (self.state >> 8) ^ CRC32_TABLE[idx];
        }
    }

    pub fn finalize(self) -> u32 {
        !self.state
    }
}

impl Default for Crc32 {
    fn default() -> Self {
        Self::new()
    }
}

/// Acumulador MD5 según RFC 1321.
pub struct Md5 {
    state: [u32; 4],
    len_bytes: u64,
    buf: [u8; 64],
    buf_len: usize,
}

const MD5_SHIFTS: [u32; 64] = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9,
    14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15,
    21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
];

const MD5_K: [u32; 64] = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
];

impl Md5 {
    pub fn new() -> Self {
        Self {
            state: [0x6745_2301, 0xefcd_ab89, 0x98ba_dcfe, 0x1032_5476],
            len_bytes: 0,
            buf: [0u8; 64],
            buf_len: 0,
        }
    }

    pub fn update(&mut self, mut data: &[u8]) {
        self.len_bytes = self.len_bytes.wrapping_add(data.len() as u64);

        if self.buf_len > 0 {
            let take = (64 - self.buf_len).min(data.len());
            self.buf[self.buf_len..self.buf_len + take].copy_from_slice(&data[..take]);
            self.buf_len += take;
            data = &data[take..];
            if self.buf_len == 64 {
                let block = self.buf;
                self.compress(&block);
                self.buf_len = 0;
            }
        }

        while data.len() >= 64 {
            let (block, rest) = data.split_at(64);
            self.compress(block.try_into().expect("bloque MD5 de 64 bytes"));
            data = rest;
        }

        if !data.is_empty() {
            self.buf[..data.len()].copy_from_slice(data);
            self.buf_len = data.len();
        }
    }

    pub fn finalize(mut self) -> [u8; 16] {
        let bit_len = self.len_bytes.wrapping_mul(8);
        self.update(&[0x80]);
        if self.buf_len > 56 {
            let pad = 64 - self.buf_len;
            let zeros = [0u8; 64];
            self.update(&zeros[..pad]);
        }
        let pad_zeros = 56 - self.buf_len;
        let zeros = [0u8; 56];
        self.update(&zeros[..pad_zeros]);
        self.update(&bit_len.to_le_bytes());

        let mut out = [0u8; 16];
        for (i, &w) in self.state.iter().enumerate() {
            out[i * 4..i * 4 + 4].copy_from_slice(&w.to_le_bytes());
        }
        out
    }

    fn compress(&mut self, block: &[u8; 64]) {
        let mut m = [0u32; 16];
        for (i, word) in m.iter_mut().enumerate() {
            let off = i * 4;
            *word = u32::from_le_bytes([block[off], block[off + 1], block[off + 2], block[off + 3]]);
        }

        let [mut a, mut b, mut c, mut d] = self.state;
        for i in 0..64 {
            let (f, g) = match i {
                0..=15 => ((b & c) | ((!b) & d), i),
                16..=31 => ((d & b) | ((!d) & c), (5 * i + 1) % 16),
                32..=47 => (b ^ c ^ d, (3 * i + 5) % 16),
                _ => (c ^ (b | (!d)), (7 * i) % 16),
            };
            let temp = d;
            d = c;
            c = b;
            let sum = a
                .wrapping_add(f)
                .wrapping_add(MD5_K[i])
                .wrapping_add(m[g]);
            b = b.wrapping_add(sum.rotate_left(MD5_SHIFTS[i]));
            a = temp;
        }

        self.state[0] = self.state[0].wrapping_add(a);
        self.state[1] = self.state[1].wrapping_add(b);
        self.state[2] = self.state[2].wrapping_add(c);
        self.state[3] = self.state[3].wrapping_add(d);
    }
}

impl Default for Md5 {
    fn default() -> Self {
        Self::new()
    }
}

/// Acumulador SHA-1 según FIPS 180-4.
pub struct Sha1 {
    state: [u32; 5],
    len_bytes: u64,
    buf: [u8; 64],
    buf_len: usize,
}

impl Sha1 {
    pub fn new() -> Self {
        Self {
            state: [
                0x6745_2301,
                0xefcd_ab89,
                0x98ba_dcfe,
                0x1032_5476,
                0xc3d2_e1f0,
            ],
            len_bytes: 0,
            buf: [0u8; 64],
            buf_len: 0,
        }
    }

    pub fn update(&mut self, mut data: &[u8]) {
        self.len_bytes = self.len_bytes.wrapping_add(data.len() as u64);

        if self.buf_len > 0 {
            let take = (64 - self.buf_len).min(data.len());
            self.buf[self.buf_len..self.buf_len + take].copy_from_slice(&data[..take]);
            self.buf_len += take;
            data = &data[take..];
            if self.buf_len == 64 {
                let block = self.buf;
                self.compress(&block);
                self.buf_len = 0;
            }
        }

        while data.len() >= 64 {
            let (block, rest) = data.split_at(64);
            self.compress(block.try_into().expect("bloque SHA-1 de 64 bytes"));
            data = rest;
        }

        if !data.is_empty() {
            self.buf[..data.len()].copy_from_slice(data);
            self.buf_len = data.len();
        }
    }

    pub fn finalize(mut self) -> [u8; 20] {
        let bit_len = self.len_bytes.wrapping_mul(8);
        self.update(&[0x80]);
        if self.buf_len > 56 {
            let pad = 64 - self.buf_len;
            let zeros = [0u8; 64];
            self.update(&zeros[..pad]);
        }
        let pad_zeros = 56 - self.buf_len;
        let zeros = [0u8; 56];
        self.update(&zeros[..pad_zeros]);
        self.update(&bit_len.to_be_bytes());

        let mut out = [0u8; 20];
        for (i, &w) in self.state.iter().enumerate() {
            out[i * 4..i * 4 + 4].copy_from_slice(&w.to_be_bytes());
        }
        out
    }

    fn compress(&mut self, block: &[u8; 64]) {
        let mut w = [0u32; 80];
        for (i, slot) in w.iter_mut().take(16).enumerate() {
            let off = i * 4;
            *slot = u32::from_be_bytes([block[off], block[off + 1], block[off + 2], block[off + 3]]);
        }
        for i in 16..80 {
            w[i] = (w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]).rotate_left(1);
        }

        let [mut a, mut b, mut c, mut d, mut e] = self.state;
        for (i, &wi) in w.iter().enumerate() {
            let (f, k) = match i {
                0..=19 => ((b & c) | ((!b) & d), 0x5a82_7999),
                20..=39 => (b ^ c ^ d, 0x6ed9_eba1),
                40..=59 => ((b & c) | (b & d) | (c & d), 0x8f1b_bcdc),
                _ => (b ^ c ^ d, 0xca62_c1d6),
            };
            let temp = a
                .rotate_left(5)
                .wrapping_add(f)
                .wrapping_add(e)
                .wrapping_add(k)
                .wrapping_add(wi);
            e = d;
            d = c;
            c = b.rotate_left(30);
            b = a;
            a = temp;
        }

        self.state[0] = self.state[0].wrapping_add(a);
        self.state[1] = self.state[1].wrapping_add(b);
        self.state[2] = self.state[2].wrapping_add(c);
        self.state[3] = self.state[3].wrapping_add(d);
        self.state[4] = self.state[4].wrapping_add(e);
    }
}

impl Default for Sha1 {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn crc32_hex(data: &[u8]) -> String {
        let mut h = Crc32::new();
        h.update(data);
        format!("{:08x}", h.finalize())
    }

    fn md5_hex(data: &[u8]) -> String {
        let mut h = Md5::new();
        h.update(data);
        to_hex(&h.finalize())
    }

    fn sha1_hex(data: &[u8]) -> String {
        let mut h = Sha1::new();
        h.update(data);
        to_hex(&h.finalize())
    }

    #[test]
    fn crc32_vectores_estandar() {
        assert_eq!(crc32_hex(b""), "00000000");
        assert_eq!(crc32_hex(b"123456789"), "cbf43926");
    }

    #[test]
    fn md5_vectores_rfc1321() {
        assert_eq!(md5_hex(b""), "d41d8cd98f00b204e9800998ecf8427e");
        assert_eq!(md5_hex(b"abc"), "900150983cd24fb0d6963f7d28e17f72");
        assert_eq!(md5_hex(b"message digest"), "f96b697d7cb7938d525a2f31aaf161d0");
        assert_eq!(
            md5_hex(b"abcdefghijklmnopqrstuvwxyz"),
            "c3fcd3d76192e4007dfb496cca67e13b"
        );
        // Caso límite de relleno (56 bytes -> obliga un bloque extra).
        let msg56 = b"01234567890123456789012345678901234567890123456789012345";
        assert_eq!(msg56.len(), 56);
        assert_eq!(md5_hex(msg56), "8af270b2847610e742b0791b53648c09");
        assert_eq!(
            md5_hex(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"),
            "d174ab98d277d9f5a5611c2c9f419d9f"
        );
        assert_eq!(
            md5_hex(&b"1234567890".repeat(8)),
            "57edf4a22be3c955ac49da2e2107b67a"
        );
    }

    #[test]
    fn sha1_vectores_fips180() {
        assert_eq!(sha1_hex(b""), "da39a3ee5e6b4b0d3255bfef95601890afd80709");
        assert_eq!(sha1_hex(b"abc"), "a9993e364706816aba3e25717850c26c9cd0d89d");
        assert_eq!(
            sha1_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
            "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
        );
    }

    #[test]
    fn streaming_en_fragmentos_irregulares() {
        let mut h_md5 = Md5::new();
        let mut h_sha1 = Sha1::new();
        let mut h_crc = Crc32::new();
        let data = b"Crash Bandicoot 2 - Cortex Strikes Back (USA) ".repeat(17);
        for chunk in data.chunks(13) {
            h_md5.update(chunk);
            h_sha1.update(chunk);
            h_crc.update(chunk);
        }
        assert_eq!(to_hex(&h_md5.finalize()), md5_hex(&data));
        assert_eq!(to_hex(&h_sha1.finalize()), sha1_hex(&data));
        assert_eq!(format!("{:08x}", h_crc.finalize()), crc32_hex(&data));
    }
}
