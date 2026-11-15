//! Resolución de la pista de datos desde un archivo .cue o .bin (solo lectura).

use std::fs;
use std::path::{Path, PathBuf};

/// Resuelve la ruta de la pista de datos a partir de un `.cue` o `.bin`.
/// Solo abre archivos en modo lectura.
pub fn resolve_disc_image(disc_path: &Path) -> Result<PathBuf, String> {
    if !disc_path.is_file() {
        return Err(format!("no existe la imagen de disco: {}", disc_path.display()));
    }

    let ext = disc_path
        .extension()
        .and_then(|s| s.to_str())
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default();

    match ext.as_str() {
        "cue" => resolve_cue_data_bin(disc_path),
        "chd" => Err(format!(
            "formato .chd no soportado directamente por verify-disc ({}): \
             usa un par .cue/.bin o `psxrecomp_cli.py verify-disc`",
            disc_path.display()
        )),
        _ => Ok(disc_path.to_path_buf()),
    }
}

fn resolve_cue_data_bin(cue_path: &Path) -> Result<PathBuf, String> {
    let text = fs::read_to_string(cue_path)
        .map_err(|e| format!("no se pudo leer {}: {e}", cue_path.display()))?;
    let rel_bin = parse_track1_binary(&text).ok_or_else(|| {
        format!(
            "el archivo .cue no contiene una pista BINARY válida: {}",
            cue_path.display()
        )
    })?;

    resolve_relative_insensitive(cue_path, &rel_bin)
}

/// Extrae el nombre de archivo de la pista 1 (o primer `FILE ... BINARY`).
pub fn parse_track1_binary(cue_text: &str) -> Option<String> {
    let mut first_binary: Option<String> = None;
    let mut current_binary: Option<String> = None;

    for raw_line in cue_text.lines() {
        let line = raw_line.trim().trim_start_matches('\u{feff}');
        if line.is_empty() || starts_with_keyword(line, "REM") {
            continue;
        }
        if let Some((filename, kind)) = parse_file_directive(line) {
            if kind.eq_ignore_ascii_case("BINARY") {
                current_binary = Some(filename.clone());
                if first_binary.is_none() {
                    first_binary = Some(filename);
                }
            } else {
                current_binary = None;
            }
            continue;
        }
        if let Some(track_num) = parse_track_number(line) {
            if track_num == 1 {
                if let Some(file) = current_binary {
                    return Some(file);
                }
            }
        }
    }

    first_binary
}

fn starts_with_keyword(line: &str, kw: &str) -> bool {
    let Some(rest) = line.get(..kw.len()) else {
        return false;
    };
    if !rest.eq_ignore_ascii_case(kw) {
        return false;
    }
    line.as_bytes()
        .get(kw.len())
        .is_some_and(|b| b.is_ascii_whitespace())
}

fn parse_file_directive(line: &str) -> Option<(String, String)> {
    if !starts_with_keyword(line, "FILE") {
        return None;
    }
    let rest = line[4..].trim_start();
    if let Some(after_quote) = rest.strip_prefix('"') {
        let end_quote = after_quote.find('"')?;
        let filename = after_quote[..end_quote].to_string();
        let kind = after_quote[end_quote + 1..].trim().to_string();
        return (!filename.is_empty() && !kind.is_empty()).then_some((filename, kind));
    }

    let mut parts = rest.split_whitespace();
    let filename = parts.next()?.to_string();
    let kind = parts.next()?.to_string();
    Some((filename, kind))
}

fn parse_track_number(line: &str) -> Option<u32> {
    if !starts_with_keyword(line, "TRACK") {
        return None;
    }
    let mut parts = line.split_whitespace();
    let _kw = parts.next()?;
    let num_str = parts.next()?;
    num_str.parse::<u32>().ok()
}

fn resolve_relative_insensitive(cue_path: &Path, raw_name: &str) -> Result<PathBuf, String> {
    let normalized = raw_name.replace('\\', "/");
    let candidate = {
        let p = Path::new(&normalized);
        if p.is_absolute() {
            p.to_path_buf()
        } else {
            cue_path
                .parent()
                .unwrap_or_else(|| Path::new("."))
                .join(p)
        }
    };

    if candidate.is_file() {
        return Ok(candidate);
    }

    if let (Some(parent), Some(file_name)) = (candidate.parent(), candidate.file_name()) {
        if parent.is_dir() {
            let want = file_name.to_string_lossy();
            if let Ok(entries) = fs::read_dir(parent) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_file()
                        && entry.file_name().to_string_lossy().eq_ignore_ascii_case(&want)
                    {
                        return Ok(path);
                    }
                }
            }
        }
    }

    Err(format!(
        "el .cue referencia un .bin inexistente: {}",
        candidate.display()
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_dir(tag: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("reloj")
            .as_nanos();
        let dir = std::env::temp_dir().join(format!(
            "verify_disc_cue_{tag}_{}_{}",
            std::process::id(),
            nanos
        ));
        fs::create_dir_all(&dir).expect("crear temp dir");
        dir
    }

    #[test]
    fn parsea_cue_con_comillas_y_crlf() {
        let cue = "FILE \"Crash Bandicoot 2 (USA).bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n";
        assert_eq!(
            parse_track1_binary(cue).as_deref(),
            Some("Crash Bandicoot 2 (USA).bin")
        );
    }

    #[test]
    fn parsea_cue_sin_comillas_y_rem() {
        let cue = "REM Comentario\nFILE track01.bin BINARY\n  TRACK 01 MODE2/2352\n";
        assert_eq!(parse_track1_binary(cue).as_deref(), Some("track01.bin"));
    }

    #[test]
    fn resuelve_bin_relativo_e_insensible_a_mayusculas() {
        let dir = temp_dir("case");
        let bin = dir.join("Juego.BIN");
        fs::write(&bin, b"hola").expect("escribir bin");
        let cue = dir.join("juego.cue");
        fs::write(&cue, "FILE \"juego.bin\" BINARY\n  TRACK 01 MODE2/2352\n").expect("escribir cue");

        let resolved = resolve_disc_image(&cue).expect("debe resolver");
        assert_eq!(resolved.file_name().unwrap().to_str().unwrap(), "Juego.BIN");
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn rechaza_chd_con_mensaje_claro() {
        let dir = temp_dir("chd");
        let chd = dir.join("disco.chd");
        fs::write(&chd, b"MComprHD").expect("escribir chd dummy");
        let err = resolve_disc_image(&chd).expect_err("chd no soportado");
        assert!(err.contains(".chd"), "error inesperado: {err}");
        let _ = fs::remove_dir_all(&dir);
    }
}
