//! `verify-disc` CLI -- validates PS1 disc images read-only against `game.toml`.

use std::fmt::Write as _;
use std::path::PathBuf;
use std::process::ExitCode;

use verify_disc::{verify_disc, VerifyError, VerifyReport};

const EXIT_OK: u8 = 0;
const EXIT_USAGE: u8 = 2;
const EXIT_MISMATCH: u8 = 3;

struct Args {
    config: PathBuf,
    disc: Option<PathBuf>,
    json: bool,
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => ExitCode::from(code),
        Err(msg) => {
            eprintln!("verify-disc: error: {msg}");
            ExitCode::from(EXIT_USAGE)
        }
    }
}

fn run() -> Result<u8, String> {
    let Some(args) = parse_args()? else {
        print_help();
        return Ok(EXIT_OK);
    };

    match verify_disc(&args.config, args.disc.as_deref()) {
        Ok(rep) => {
            print_report(&rep, args.json);
            Ok(EXIT_OK)
        }
        Err(VerifyError::Mismatch(rep)) => {
            print_report(&rep, args.json);
            Ok(EXIT_MISMATCH)
        }
        Err(VerifyError::UsageOrIo(msg)) => Err(msg),
    }
}

fn parse_args() -> Result<Option<Args>, String> {
    let mut config = PathBuf::from("game.toml");
    let mut disc: Option<PathBuf> = None;
    let mut json = false;

    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "-h" | "--help" => return Ok(None),
            "--json" => json = true,
            "--config" => {
                let val = it
                    .next()
                    .ok_or_else(|| "missing path after --config".to_string())?;
                config = PathBuf::from(val);
            }
            "--disc" => {
                let val = it
                    .next()
                    .ok_or_else(|| "missing path after --disc".to_string())?;
                disc = Some(PathBuf::from(val));
            }
            other if other.starts_with('-') => {
                return Err(format!("unknown option: {other} (use --help)"));
            }
            positional => {
                if disc.is_some() {
                    return Err(format!("unexpected positional argument: {positional}"));
                }
                disc = Some(PathBuf::from(positional));
            }
        }
    }

    Ok(Some(Args { config, disc, json }))
}

fn print_help() {
    println!(
        "\
Usage: verify-disc [--config <game.toml>] [--disc <path.cue|path.bin>] [--json]

Verifies size, CRC-32, MD5, and SHA-1 read-only against [prepare_disc]
in game.toml (Redump table).

Options:
  --config <path>   Path to game.toml (default: game.toml)
  --disc <path>     .cue or .bin image to check (default: [game] disc)
  --json            Print report as JSON
  -h, --help        Show this help message

Exit codes:
  0  Image verified (matches [prepare_disc])
  2  Usage, I/O, or parsing error (.toml / .cue)
  3  Size or at least one digest does not match"
    );
}

fn print_report(rep: &VerifyReport, as_json: bool) {
    if as_json {
        println!("{}", format_json(rep));
        return;
    }

    let sector_info = match rep.sectors {
        Some(n) => format!("{n} sectors x 2352 B"),
        None => "NOT a multiple of 2352 B".to_string(),
    };

    println!("Game:     {}", rep.game_id);
    println!("Image:    {}", rep.resolved_bin.display());
    println!(
        "Size:     {} bytes ({}) [{}]",
        rep.digests.size,
        sector_info,
        status_tag(rep.checks.size_ok)
    );
    println!(
        "CRC-32:   {} [{}]",
        rep.digests.crc32,
        status_tag(rep.checks.crc32_ok)
    );
    println!(
        "MD5:      {} [{}]",
        rep.digests.md5,
        status_tag(rep.checks.md5_ok)
    );
    println!(
        "SHA-1:    {} [{}]",
        rep.digests.sha1,
        status_tag(rep.checks.sha1_ok)
    );
    if !rep.checks.alignment_ok {
        println!("Revision: matched fields belong to different revisions [FAIL]");
    }
    if rep.passed {
        println!("Status:   VERIFIED");
    } else {
        println!("Status:   MISMATCH");
    }
}

fn status_tag(flag: Option<bool>) -> &'static str {
    match flag {
        Some(true) => "OK",
        Some(false) => "MISMATCH",
        None => "unlisted",
    }
}

fn format_json(rep: &VerifyReport) -> String {
    let opt_bool = |v: Option<bool>| match v {
        Some(true) => "true",
        Some(false) => "false",
        None => "null",
    };
    let sectors = rep
        .sectors
        .map_or_else(|| "null".to_string(), |s| s.to_string());
    format!(
        "{{\"ok\":{},\"game_id\":\"{}\",\"disc\":\"{}\",\"bin\":\"{}\",\
         \"size\":{},\"sectors\":{},\"crc32\":\"{}\",\"md5\":\"{}\",\"sha1\":\"{}\",\
         \"checks\":{{\"size\":{},\"crc32\":{},\"md5\":{},\"sha1\":{},\"revision\":{}}}}}",
        rep.passed,
        escape_json(&rep.game_id),
        escape_json(&rep.requested_disc.display().to_string()),
        escape_json(&rep.resolved_bin.display().to_string()),
        rep.digests.size,
        sectors,
        rep.digests.crc32,
        rep.digests.md5,
        rep.digests.sha1,
        opt_bool(rep.checks.size_ok),
        opt_bool(rep.checks.crc32_ok),
        opt_bool(rep.checks.md5_ok),
        opt_bool(rep.checks.sha1_ok),
        rep.checks.alignment_ok,
    )
}

fn escape_json(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                let _ = write!(&mut out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out
}
