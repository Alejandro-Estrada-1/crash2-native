//! Verificador de imagen de disco PS1 contra la tabla Redump en `game.toml`.

pub mod cue;
pub mod digest;
pub mod toml;

use std::path::{Path, PathBuf};

use cue::resolve_disc_image;
use digest::{compute_file_digests, DiscDigests};
use toml::{load_game_toml, GameTomlConfig};

pub const PS1_RAW_SECTOR_BYTES: u64 = 2352;

/// Resultado detallado de verificación.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifyReport {
    pub config_path: PathBuf,
    pub requested_disc: PathBuf,
    pub resolved_bin: PathBuf,
    pub game_id: String,
    pub digests: DiscDigests,
    pub sectors: Option<u64>,
    pub checks: FieldChecks,
    pub passed: bool,
}

/// Estado por campo frente a `[prepare_disc]`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldChecks {
    pub size_ok: Option<bool>,
    pub crc32_ok: Option<bool>,
    pub md5_ok: Option<bool>,
    pub sha1_ok: Option<bool>,
    pub alignment_ok: bool,
}

/// Tipo de error para mapear códigos de salida (`2` uso/IO, `3` discrepancia).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VerifyError {
    UsageOrIo(String),
    Mismatch(Box<VerifyReport>),
}

/// Verifica la imagen indicada en `disc_override` o en `[game] disc` de `config_path`.
pub fn verify_disc(config_path: &Path, disc_override: Option<&Path>) -> Result<VerifyReport, VerifyError> {
    if !config_path.is_file() {
        return Err(VerifyError::UsageOrIo(format!(
            "no existe el archivo de configuración: {}",
            config_path.display()
        )));
    }

    let cfg = load_game_toml(config_path).map_err(VerifyError::UsageOrIo)?;
    ensure_redump_table_present(&cfg)?;

    let project_root = config_path.parent().unwrap_or_else(|| Path::new("."));
    let requested = match disc_override {
        Some(p) => p.to_path_buf(),
        None => {
            let rel = cfg.game_disc.as_deref().ok_or_else(|| {
                VerifyError::UsageOrIo(
                    "falta `--disc` y `game.toml` no define `[game] disc`".to_string(),
                )
            })?;
            resolve_from_root(project_root, rel)
        }
    };

    let resolved_bin = resolve_disc_image(&requested).map_err(VerifyError::UsageOrIo)?;
    let digests = compute_file_digests(&resolved_bin).map_err(|e| {
        VerifyError::UsageOrIo(format!(
            "error al leer {}: {e}",
            resolved_bin.display()
        ))
    })?;

    let report = evaluate_report(config_path, requested, resolved_bin, &cfg, digests);
    if report.passed {
        Ok(report)
    } else {
        Err(VerifyError::Mismatch(Box::new(report)))
    }
}

fn resolve_from_root(project_root: &Path, rel: &str) -> PathBuf {
    let p = Path::new(rel);
    if p.is_absolute() || project_root.as_os_str().is_empty() {
        p.to_path_buf()
    } else {
        project_root.join(p)
    }
}

fn ensure_redump_table_present(cfg: &GameTomlConfig) -> Result<(), VerifyError> {
    if cfg.known_sizes.is_empty()
        && cfg.known_crc32.is_empty()
        && cfg.known_md5.is_empty()
        && cfg.known_sha1.is_empty()
    {
        return Err(VerifyError::UsageOrIo(
            "`game.toml` no declara ningún valor en `[prepare_disc] known_*`".to_string(),
        ));
    }
    Ok(())
}

fn evaluate_report(
    config_path: &Path,
    requested: PathBuf,
    resolved_bin: PathBuf,
    cfg: &GameTomlConfig,
    digests: DiscDigests,
) -> VerifyReport {
    #[allow(clippy::manual_is_multiple_of)]
    let sectors = (digests.size % PS1_RAW_SECTOR_BYTES == 0)
        .then_some(digests.size / PS1_RAW_SECTOR_BYTES);

    let size_ok = (!cfg.known_sizes.is_empty()).then(|| cfg.known_sizes.contains(&digests.size));
    let crc32_ok = (!cfg.known_crc32.is_empty()).then(|| cfg.known_crc32.contains(&digests.crc32));
    let md5_ok = (!cfg.known_md5.is_empty()).then(|| cfg.known_md5.contains(&digests.md5));
    let sha1_ok = (!cfg.known_sha1.is_empty()).then(|| cfg.known_sha1.contains(&digests.sha1));
    let alignment_ok = aligned_revision_matches(cfg, &digests);

    let passed = [size_ok, crc32_ok, md5_ok, sha1_ok]
        .into_iter()
        .flatten()
        .all(|ok| ok)
        && alignment_ok;

    VerifyReport {
        config_path: config_path.to_path_buf(),
        requested_disc: requested,
        resolved_bin,
        game_id: cfg
            .game_id
            .clone()
            .unwrap_or_else(|| "desconocido".to_string()),
        digests,
        sectors,
        checks: FieldChecks {
            size_ok,
            crc32_ok,
            md5_ok,
            sha1_ok,
            alignment_ok,
        },
        passed,
    }
}

/// Si todas las listas declaradas tienen la misma longitud `N > 1`, exige que
/// la coincidencia corresponda a la misma revisión `i` en todas las listas.
fn aligned_revision_matches(cfg: &GameTomlConfig, digests: &DiscDigests) -> bool {
    let lens = [
        cfg.known_sizes.len(),
        cfg.known_crc32.len(),
        cfg.known_md5.len(),
        cfg.known_sha1.len(),
    ];
    let non_zero: Vec<usize> = lens.into_iter().filter(|&n| n > 0).collect();
    let Some(&n) = non_zero.first() else {
        return true;
    };
    if n <= 1 || !non_zero.iter().all(|&x| x == n) {
        return true;
    }

    (0..n).any(|i| {
        let ok_size = cfg.known_sizes.is_empty() || cfg.known_sizes[i] == digests.size;
        let ok_crc = cfg.known_crc32.is_empty() || cfg.known_crc32[i] == digests.crc32;
        let ok_md5 = cfg.known_md5.is_empty() || cfg.known_md5[i] == digests.md5;
        let ok_sha1 = cfg.known_sha1.is_empty() || cfg.known_sha1[i] == digests.sha1;
        ok_size && ok_crc && ok_md5 && ok_sha1
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn make_temp_dir(tag: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("reloj")
            .as_nanos();
        let dir = std::env::temp_dir().join(format!(
            "verify_disc_lib_{tag}_{}_{}",
            std::process::id(),
            nanos
        ));
        fs::create_dir_all(&dir).expect("crear temp dir");
        dir
    }

    #[test]
    fn acepta_imagen_sintetica_via_cue_y_redump() {
        let dir = make_temp_dir("ok");
        let bin = dir.join("test.bin");
        let payload = vec![0xA5u8; 2352];
        fs::write(&bin, &payload).expect("escribir bin");
        let d = compute_file_digests(&bin).expect("digests");

        let cue = dir.join("test.cue");
        fs::write(&cue, "FILE \"test.bin\" BINARY\n  TRACK 01 MODE2/2352\n").expect("escribir cue");

        let toml = dir.join("game.toml");
        fs::write(
            &toml,
            format!(
                "[game]\nid = \"SCUS-94154\"\ndisc = \"test.cue\"\n\n\
                 [prepare_disc]\nknown_sizes = [{}]\nknown_md5 = [\"{}\"]\n\
                 known_sha1 = [\"{}\"]\nknown_crc32 = [\"{}\"]\n",
                d.size, d.md5, d.sha1, d.crc32
            ),
        )
        .expect("escribir game.toml");

        let rep = verify_disc(&toml, None).expect("debe pasar");
        assert!(rep.passed);
        assert_eq!(rep.sectors, Some(1));
        assert_eq!(rep.checks.crc32_ok, Some(true));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn rechaza_crc32_alterado_aunque_md5_y_sha1_coincidan() {
        let dir = make_temp_dir("bad_crc");
        let bin = dir.join("test.bin");
        fs::write(&bin, b"123456789").expect("escribir bin");
        let d = compute_file_digests(&bin).expect("digests");

        let toml = dir.join("game.toml");
        fs::write(
            &toml,
            format!(
                "[game]\ndisc = \"test.bin\"\n\n[prepare_disc]\n\
                 known_sizes = [{}]\nknown_md5 = [\"{}\"]\n\
                 known_sha1 = [\"{}\"]\nknown_crc32 = [\"00000000\"]\n",
                d.size, d.md5, d.sha1
            ),
        )
        .expect("escribir game.toml");

        match verify_disc(&toml, None) {
            Err(VerifyError::Mismatch(rep)) => {
                assert!(!rep.passed);
                assert_eq!(rep.checks.size_ok, Some(true));
                assert_eq!(rep.checks.md5_ok, Some(true));
                assert_eq!(rep.checks.sha1_ok, Some(true));
                assert_eq!(rep.checks.crc32_ok, Some(false));
            }
            other => panic!("se esperaba Mismatch, obtenido: {other:?}"),
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn rechaza_mezcla_cruzada_de_revisiones() {
        let dir = make_temp_dir("cross_rev");
        let bin = dir.join("rev0.bin");
        fs::write(&bin, b"rev0").expect("escribir bin");
        let d = compute_file_digests(&bin).expect("digests");

        let toml = dir.join("game.toml");
        fs::write(
            &toml,
            format!(
                "[game]\ndisc = \"rev0.bin\"\n\n[prepare_disc]\n\
                 known_sizes = [{}, 999]\n\
                 known_crc32 = [\"{}\", \"ffffffff\"]\n\
                 known_md5 = [\"00000000000000000000000000000000\", \"{}\"]\n",
                d.size, d.crc32, d.md5
            ),
        )
        .expect("escribir game.toml");

        match verify_disc(&toml, None) {
            Err(VerifyError::Mismatch(rep)) => assert!(!rep.checks.alignment_ok),
            other => panic!("se esperaba Mismatch por mezcla cruzada: {other:?}"),
        }
        let _ = fs::remove_dir_all(&dir);
    }
}
