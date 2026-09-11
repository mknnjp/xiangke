use std::collections::HashMap;
use std::fs;
use std::path::Path;

use xiangke_core::character::{CharacterData, Stats};
use xiangke_core::moves::MoveData;
use xiangke_core::types::{DamageCategory, EffectType, Stat, StatModTarget, TypeElement};

/// Parse raw `.tres` text into a key/value map.
/// Skips section headers (`[...]`) and blank lines.
pub fn parse_tres_text(text: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('[') || line.starts_with('#') {
            continue;
        }
        if let Some(pos) = line.find('=') {
            let key = line[..pos].trim().to_string();
            let value = line[pos + 1..].trim().to_string();
            map.insert(key, value);
        }
    }
    map
}

/// Read a `.tres` file to a string. Returns `None` on I/O error.
pub fn read_tres_file(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok()
}

fn unquote(value: &str) -> String {
    let v = value.trim();
    if v.len() >= 2 && v.starts_with('"') && v.ends_with('"') {
        v[1..v.len() - 1].to_string()
    } else {
        v.to_string()
    }
}

fn get_string(map: &HashMap<String, String>, key: &str) -> String {
    map.get(key).map(|v| unquote(v)).unwrap_or_default()
}

fn get_u32(map: &HashMap<String, String>, key: &str, default: u32) -> u32 {
    map.get(key)
        .map(|v| unquote(v).parse::<u32>().unwrap_or(default))
        .unwrap_or(default)
}

fn get_i32(map: &HashMap<String, String>, key: &str, default: i32) -> i32 {
    map.get(key)
        .map(|v| unquote(v).parse::<i32>().unwrap_or(default))
        .unwrap_or(default)
}

fn parse_element(value: i32) -> TypeElement {
    match value {
        0 => TypeElement::Wood,
        1 => TypeElement::Fire,
        2 => TypeElement::Earth,
        3 => TypeElement::Metal,
        4 => TypeElement::Water,
        5 => TypeElement::Yang,
        6 => TypeElement::Yin,
        _ => TypeElement::Wood,
    }
}

fn parse_effect(value: u32) -> EffectType {
    match value {
        1 => EffectType::Burn,
        2 => EffectType::Poison,
        3 => EffectType::Confusion,
        4 => EffectType::Chain,
        5 => EffectType::Charm,
        _ => EffectType::None,
    }
}

fn parse_damage_category(value: u32) -> DamageCategory {
    match value {
        1 => DamageCategory::Arts,
        _ => DamageCategory::Physical,
    }
}

fn parse_stat(value: i32) -> Option<Stat> {
    match value {
        0 => Some(Stat::Attack),
        1 => Some(Stat::Defense),
        2 => Some(Stat::Speed),
        3 => Some(Stat::Intelligence),
        4 => Some(Stat::Spirit),
        _ => None,
    }
}

fn parse_stat_mod_target(value: i32) -> StatModTarget {
    match value {
        1 => StatModTarget::Target,
        _ => StatModTarget::Self_,
    }
}

/// Extract quoted strings from `PackedStringArray("a", "b", ...)`.
pub fn parse_moves_array(raw: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut chars = raw.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '"' {
            let mut s = String::new();
            for nc in chars.by_ref() {
                if nc == '"' {
                    break;
                }
                s.push(nc);
            }
            out.push(s);
        }
    }
    out
}

/// Parse one character `.tres` document. Returns `None` when `id` is missing.
pub fn parse_character(text: &str) -> Option<CharacterData> {
    let map = parse_tres_text(text);
    let id = get_string(&map, "id");
    if id.is_empty() {
        return None;
    }
    let secondary_raw = get_i32(&map, "secondary_type", -1);
    let secondary_element = if secondary_raw < 0 {
        None
    } else {
        Some(parse_element(secondary_raw))
    };
    let moves_raw = map.get("moves").map(|s| s.as_str()).unwrap_or("");
    Some(CharacterData {
        id,
        name: get_string(&map, "name"),
        element: parse_element(get_i32(&map, "type", 0)),
        secondary_element,
        base_stats: Stats {
            hp: get_u32(&map, "hp", 1),
            attack: get_u32(&map, "attack", 1),
            defense: get_u32(&map, "defense", 1),
            speed: get_u32(&map, "speed", 1),
            intelligence: get_u32(&map, "intelligence", 1),
            spirit: get_u32(&map, "spirit", 1),
        },
        moves: parse_moves_array(moves_raw),
        description: get_string(&map, "description"),
    })
}

/// Parse one move `.tres` document. Returns `None` when `id` is missing.
pub fn parse_move(text: &str) -> Option<MoveData> {
    let map = parse_tres_text(text);
    let id = get_string(&map, "id");
    if id.is_empty() {
        return None;
    }
    Some(MoveData {
        id,
        name: get_string(&map, "name"),
        element: parse_element(get_i32(&map, "type", 0)),
        power: get_u32(&map, "power", 0),
        accuracy: get_u32(&map, "accuracy", 100),
        effect: parse_effect(get_u32(&map, "effect", 0)),
        effect_chance: get_u32(&map, "effect_chance", 0),
        stat_mod_stat: parse_stat(get_i32(&map, "stat_mod_stat", -1)),
        stat_mod_stage: get_i32(&map, "stat_mod_stage", 0),
        stat_mod_target: parse_stat_mod_target(get_i32(&map, "stat_mod_target", 0)),
        hit_count: get_u32(&map, "hit_count", 1),
        recoil: get_u32(&map, "recoil", 0),
        healing: get_u32(&map, "healing", 0),
        damage_category: parse_damage_category(get_u32(&map, "damage_category", 0)),
        description: get_string(&map, "description"),
    })
}

fn load_tres_dir(dir: &Path) -> Vec<String> {
    let mut texts = Vec::new();
    let Ok(entries) = fs::read_dir(dir) else {
        return texts;
    };
    let mut paths: Vec<_> = entries
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().is_some_and(|ext| ext == "tres"))
        .collect();
    paths.sort();
    for path in paths {
        if let Some(text) = read_tres_file(&path) {
            texts.push(text);
        }
    }
    texts
}

/// Load all character `.tres` files under `<dir>/characters`.
/// Returns parsed characters plus non-fatal diagnostic messages.
pub fn load_characters(dir: &Path) -> (Vec<CharacterData>, Vec<String>) {
    let mut characters = Vec::new();
    let mut diagnostics = Vec::new();
    for text in load_tres_dir(&dir.join("characters")) {
        match parse_character(&text) {
            Some(c) => characters.push(c),
            None => diagnostics.push("Skipped character file with missing id".to_string()),
        }
    }
    characters.sort_by(|a, b| a.id.cmp(&b.id));
    (characters, diagnostics)
}

/// Load all move `.tres` files under `<dir>/moves`.
pub fn load_moves(dir: &Path) -> (Vec<MoveData>, Vec<String>) {
    let mut moves = Vec::new();
    let mut diagnostics = Vec::new();
    for text in load_tres_dir(&dir.join("moves")) {
        match parse_move(&text) {
            Some(m) => moves.push(m),
            None => diagnostics.push("Skipped move file with missing id".to_string()),
        }
    }
    moves.sort_by(|a, b| a.id.cmp(&b.id));
    (moves, diagnostics)
}

/// Human-readable element label.
pub fn element_label(element: TypeElement) -> &'static str {
    match element {
        TypeElement::Wood => "WOOD",
        TypeElement::Fire => "FIRE",
        TypeElement::Earth => "EARTH",
        TypeElement::Metal => "METAL",
        TypeElement::Water => "WATER",
        TypeElement::Yang => "YANG",
        TypeElement::Yin => "YIN",
    }
}

/// `PRIMARY` or `PRIMARY+SECONDARY` label.
pub fn type_label(data: &CharacterData) -> String {
    match data.secondary_element {
        Some(sec) => format!("{}+{}", element_label(data.element), element_label(sec)),
        None => element_label(data.element).to_string(),
    }
}
