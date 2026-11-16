//! Minimal `game.toml` parser for `[game]` and `[prepare_disc]`.

use std::fs;
use std::path::Path;

/// Redump values and paths loaded from `game.toml`.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct GameTomlConfig {
    pub game_id: Option<String>,
    pub game_name: Option<String>,
    pub game_disc: Option<String>,
    pub known_sizes: Vec<u64>,
    pub known_crc32: Vec<String>,
    pub known_md5: Vec<String>,
    pub known_sha1: Vec<String>,
}

/// Loads and parses `game.toml`.
pub fn load_game_toml(path: &Path) -> Result<GameTomlConfig, String> {
    let text = fs::read_to_string(path)
        .map_err(|e| format!("failed to read {}: {e}", path.display()))?;
    parse_game_toml(&text)
}

/// Parses the TOML content of `game.toml`.
pub fn parse_game_toml(text: &str) -> Result<GameTomlConfig, String> {
    let mut cfg = GameTomlConfig::default();
    let mut section = String::new();
    let mut pending_key: Option<String> = None;
    let mut pending_val = String::new();

    for (line_idx, raw_line) in text.lines().enumerate() {
        let cleaned = strip_comment(raw_line.trim_start_matches('\u{feff}')).trim();
        if cleaned.is_empty() && pending_key.is_none() {
            continue;
        }

        if let Some(key) = pending_key.take() {
            if !cleaned.is_empty() {
                pending_val.push(' ');
                pending_val.push_str(cleaned);
            }
            if brackets_balanced(&pending_val) {
                assign_key(&mut cfg, &section, &key, &pending_val, line_idx + 1)?;
                pending_val.clear();
            } else {
                pending_key = Some(key);
            }
            continue;
        }

        if cleaned.starts_with('[') && cleaned.ends_with(']') {
            section = cleaned[1..cleaned.len() - 1].trim().to_string();
            continue;
        }

        let Some((k, v)) = cleaned.split_once('=') else {
            return Err(format!("invalid TOML line {}: {}", line_idx + 1, cleaned));
        };
        let key = k.trim().to_string();
        let val = v.trim();
        if val.starts_with('[') && !brackets_balanced(val) {
            pending_key = Some(key);
            pending_val = val.to_string();
        } else {
            assign_key(&mut cfg, &section, &key, val, line_idx + 1)?;
        }
    }

    if let Some(key) = pending_key {
        return Err(format!("unclosed array for key `{key}` in TOML"));
    }

    Ok(cfg)
}

fn assign_key(
    cfg: &mut GameTomlConfig,
    section: &str,
    key: &str,
    val: &str,
    line_no: usize,
) -> Result<(), String> {
    match (section, key) {
        ("game", "id") => cfg.game_id = Some(parse_string(val, line_no)?),
        ("game", "name") => cfg.game_name = Some(parse_string(val, line_no)?),
        ("game", "disc") => cfg.game_disc = Some(parse_string(val, line_no)?),
        ("prepare_disc", "known_sizes") => cfg.known_sizes = parse_u64_array(val, line_no)?,
        ("prepare_disc", "known_crc32") => cfg.known_crc32 = parse_hex_array(val, line_no)?,
        ("prepare_disc", "known_md5") => cfg.known_md5 = parse_hex_array(val, line_no)?,
        ("prepare_disc", "known_sha1") => cfg.known_sha1 = parse_hex_array(val, line_no)?,
        _ => {}
    }
    Ok(())
}

/// Strips `# ...` comments while respecting single- and double-quoted strings.
fn strip_comment(line: &str) -> &str {
    let mut in_double = false;
    let mut in_single = false;
    let mut escaped = false;

    for (idx, ch) in line.char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        if in_double {
            match ch {
                '\\' => escaped = true,
                '"' => in_double = false,
                _ => {}
            }
            continue;
        }
        if in_single {
            if ch == '\'' {
                in_single = false;
            }
            continue;
        }
        match ch {
            '"' => in_double = true,
            '\'' => in_single = true,
            '#' => return &line[..idx],
            _ => {}
        }
    }
    line
}

fn brackets_balanced(val: &str) -> bool {
    let mut depth = 0i32;
    let mut in_double = false;
    let mut in_single = false;
    let mut escaped = false;

    for ch in val.chars() {
        if escaped {
            escaped = false;
            continue;
        }
        if in_double {
            match ch {
                '\\' => escaped = true,
                '"' => in_double = false,
                _ => {}
            }
            continue;
        }
        if in_single {
            if ch == '\'' {
                in_single = false;
            }
            continue;
        }
        match ch {
            '"' => in_double = true,
            '\'' => in_single = true,
            '[' => depth += 1,
            ']' => depth -= 1,
            _ => {}
        }
    }
    depth == 0
}

fn parse_string(raw: &str, line_no: usize) -> Result<String, String> {
    let s = raw.trim();
    if let Some(inner) = s.strip_prefix('"').and_then(|x| x.strip_suffix('"')) {
        let mut out = String::with_capacity(inner.len());
        let mut chars = inner.chars();
        while let Some(c) = chars.next() {
            if c != '\\' {
                out.push(c);
                continue;
            }
            match chars.next() {
                Some('"') => out.push('"'),
                Some('\\') => out.push('\\'),
                Some('n') => out.push('\n'),
                Some('r') => out.push('\r'),
                Some('t') => out.push('\t'),
                Some(other) => {
                    return Err(format!("unknown escape \\{other} on line {line_no}"));
                }
                None => return Err(format!("incomplete escape on line {line_no}")),
            }
        }
        return Ok(out);
    }
    if let Some(inner) = s.strip_prefix('\'').and_then(|x| x.strip_suffix('\'')) {
        return Ok(inner.to_string());
    }
    Err(format!("expected TOML string on line {line_no}: {raw}"))
}

fn split_array_items(raw: &str, line_no: usize) -> Result<Vec<String>, String> {
    let s = raw.trim();
    let inner = s
        .strip_prefix('[')
        .and_then(|x| x.strip_suffix(']'))
        .ok_or_else(|| format!("expected array `[...]` on line {line_no}: {raw}"))?;

    let mut items = Vec::new();
    let mut start = 0usize;
    let mut in_double = false;
    let mut in_single = false;
    let mut escaped = false;

    for (idx, ch) in inner.char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        if in_double {
            match ch {
                '\\' => escaped = true,
                '"' => in_double = false,
                _ => {}
            }
            continue;
        }
        if in_single {
            if ch == '\'' {
                in_single = false;
            }
            continue;
        }
        match ch {
            '"' => in_double = true,
            '\'' => in_single = true,
            ',' => {
                let item = inner[start..idx].trim();
                if !item.is_empty() {
                    items.push(item.to_string());
                }
                start = idx + 1;
            }
            _ => {}
        }
    }

    let tail = inner[start..].trim();
    if !tail.is_empty() {
        items.push(tail.to_string());
    }
    Ok(items)
}

fn parse_u64_array(raw: &str, line_no: usize) -> Result<Vec<u64>, String> {
    let items = split_array_items(raw, line_no)?;
    let mut out = Vec::with_capacity(items.len());
    for item in items {
        let cleaned = item.replace('_', "");
        let parsed = cleaned
            .parse::<u64>()
            .map_err(|_| format!("invalid integer `{item}` near line {line_no}"))?;
        out.push(parsed);
    }
    Ok(out)
}

fn parse_hex_array(raw: &str, line_no: usize) -> Result<Vec<String>, String> {
    let items = split_array_items(raw, line_no)?;
    let mut out = Vec::with_capacity(items.len());
    for item in items {
        let val = parse_string(&item, line_no)?.trim().to_ascii_lowercase();
        out.push(val);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_crash2_game_toml_format() {
        let sample = r#"
[game]
name = "crash2-native"
id = "SCUS-94154"
disc = "disc/Crash Bandicoot 2 - Cortex Strikes Back (USA).cue"

[prepare_disc]
known_sizes = [192_814_608]
known_md5 = [
  "3C31B5E038F025098A2FDFA70C8213F2", # inline comment
]
known_sha1 = [
  "3d37fe4288a83b01f1a0edbf78e76e0fede6bc22",
]
known_crc32 = ["395c0916"]
"#;
        let cfg = parse_game_toml(sample).expect("valid parse");
        assert_eq!(cfg.game_id.as_deref(), Some("SCUS-94154"));
        assert_eq!(
            cfg.game_disc.as_deref(),
            Some("disc/Crash Bandicoot 2 - Cortex Strikes Back (USA).cue")
        );
        assert_eq!(cfg.known_sizes, vec![192_814_608]);
        assert_eq!(cfg.known_md5, vec!["3c31b5e038f025098a2fdfa70c8213f2"]);
        assert_eq!(
            cfg.known_sha1,
            vec!["3d37fe4288a83b01f1a0edbf78e76e0fede6bc22"]
        );
        assert_eq!(cfg.known_crc32, vec!["395c0916"]);
    }

    #[test]
    fn rejects_unclosed_array() {
        let bad = "[prepare_disc]\nknown_md5 = [\n\"abc\"\n";
        assert!(parse_game_toml(bad).is_err());
    }
}
