//! CLI `verify-disc` — valida imágenes PS1 en modo solo lectura contra `game.toml`.

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
                    .ok_or_else(|| "falta la ruta después de --config".to_string())?;
                config = PathBuf::from(val);
            }
            "--disc" => {
                let val = it
                    .next()
                    .ok_or_else(|| "falta la ruta después de --disc".to_string())?;
                disc = Some(PathBuf::from(val));
            }
            other if other.starts_with('-') => {
                return Err(format!("opción desconocida: {other} (usa --help)"));
            }
            positional => {
                if disc.is_some() {
                    return Err(format!("argumento posicional inesperado: {positional}"));
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
Uso: verify-disc [--config <game.toml>] [--disc <ruta.cue|ruta.bin>] [--json]

Verifica tamaño, CRC-32, MD5 y SHA-1 en modo solo lectura contra [prepare_disc]
en game.toml (tabla Redump).

Opciones:
  --config <ruta>   Ruta a game.toml (por defecto: game.toml)
  --disc <ruta>     Imagen .cue o .bin a comprobar (por defecto: [game] disc)
  --json            Imprime el resultado en JSON
  -h, --help        Muestra esta ayuda

Códigos de salida:
  0  Imagen verificada (coincide con [prepare_disc])
  2  Error de uso, lectura o formato (.toml / .cue)
  3  Los hashes o el tamaño no coinciden"
    );
}

fn print_report(rep: &VerifyReport, as_json: bool) {
    if as_json {
        println!("{}", format_json(rep));
        return;
    }

    let sector_info = match rep.sectors {
        Some(n) => format!("{n} sectores x 2352 B"),
        None => "NO múltiplo de 2352 B".to_string(),
    };

    println!("Juego:   {}", rep.game_id);
    println!("Imagen:  {}", rep.resolved_bin.display());
    println!(
        "Tamaño:  {} bytes ({}) [{}]",
        rep.digests.size,
        sector_info,
        status_tag(rep.checks.size_ok)
    );
    println!(
        "CRC-32:  {} [{}]",
        rep.digests.crc32,
        status_tag(rep.checks.crc32_ok)
    );
    println!(
        "MD5:     {} [{}]",
        rep.digests.md5,
        status_tag(rep.checks.md5_ok)
    );
    println!(
        "SHA-1:   {} [{}]",
        rep.digests.sha1,
        status_tag(rep.checks.sha1_ok)
    );
    if !rep.checks.alignment_ok {
        println!("Revisión: los campos pertenecen a revisiones distintas [FALLO]");
    }
    if rep.passed {
        println!("Estado:  VERIFICADO");
    } else {
        println!("Estado:  NO COINCIDE");
    }
}

fn status_tag(flag: Option<bool>) -> &'static str {
    match flag {
        Some(true) => "OK",
        Some(false) => "NO COINCIDE",
        None => "sin declarar",
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
