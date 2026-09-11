use std::collections::HashMap;
use std::path::Path;

use xiangke_core::character::CharacterData;
use xiangke_core::moves::MoveData;

use crate::output::csv::emit_csv;
use crate::output::html::{emit_html, html_table};
use crate::output::table::Table;
use crate::parser::{element_label, load_characters, load_moves, type_label};

fn move_power_map(moves: &[MoveData]) -> HashMap<String, u32> {
    moves.iter().map(|m| (m.id.clone(), m.power)).collect()
}

fn move_list(character: &CharacterData, powers: &HashMap<String, u32>) -> String {
    character
        .moves
        .iter()
        .map(|id| match powers.get(id) {
            Some(p) => format!("{id}({p})"),
            None => format!("{id}(?)"),
        })
        .collect::<Vec<_>>()
        .join(", ")
}

/// Run the roster report. Returns `false` on output failure.
pub fn run_with(dir: &Path, format: &str, output: &str) -> bool {
    let (characters, char_diags) = load_characters(dir);
    let (moves, move_diags) = load_moves(dir);
    for d in char_diags.iter().chain(move_diags.iter()) {
        eprintln!("warning: {d}");
    }
    if characters.is_empty() {
        println!("No characters found.");
        return true;
    }
    let powers = move_power_map(&moves);
    match format {
        "csv" => {
            let headers = [
                "id",
                "name",
                "type",
                "secondary",
                "sum",
                "hp",
                "attack",
                "defense",
                "speed",
                "intelligence",
                "spirit",
                "moves",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect();
            let rows = characters
                .iter()
                .map(|c| {
                    let secondary = c
                        .secondary_element
                        .map(element_label)
                        .unwrap_or("")
                        .to_string();
                    vec![
                        c.id.clone(),
                        c.name.clone(),
                        element_label(c.element).to_string(),
                        secondary,
                        c.get_stat_sum().to_string(),
                        c.base_stats.hp.to_string(),
                        c.base_stats.attack.to_string(),
                        c.base_stats.defense.to_string(),
                        c.base_stats.speed.to_string(),
                        c.base_stats.intelligence.to_string(),
                        c.base_stats.spirit.to_string(),
                        move_list(c, &powers),
                    ]
                })
                .collect();
            emit_csv(headers, rows, output)
        }
        "html" => {
            let headers = [
                "ID", "Name", "Type", "Sum", "HP", "ATK", "DEF", "SPD", "INT", "SPR", "Moves",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect::<Vec<_>>();
            let rows = characters
                .iter()
                .map(|c| {
                    vec![
                        c.id.clone(),
                        c.name.clone(),
                        type_label(c),
                        c.get_stat_sum().to_string(),
                        c.base_stats.hp.to_string(),
                        c.base_stats.attack.to_string(),
                        c.base_stats.defense.to_string(),
                        c.base_stats.speed.to_string(),
                        c.base_stats.intelligence.to_string(),
                        c.base_stats.spirit.to_string(),
                        move_list(c, &powers),
                    ]
                })
                .collect::<Vec<_>>();
            let mut body = format!(
                "<h1>Character Roster</h1>\n<p>Total: {} characters</p>\n",
                characters.len()
            );
            body.push_str(&html_table(&headers, &rows));
            emit_html("Character Roster", &body, output)
        }
        _ => {
            let mut table = Table::new(
                vec![
                    "ID", "Name", "Type", "Sum", "HP", "ATK", "DEF", "SPD", "INT", "SPR",
                ],
                vec![18, 6, 12, 4, 3, 3, 3, 3, 3, 3],
            );
            for c in &characters {
                table.add_row(vec![
                    c.id.clone(),
                    c.name.clone(),
                    type_label(c),
                    c.get_stat_sum().to_string(),
                    c.base_stats.hp.to_string(),
                    c.base_stats.attack.to_string(),
                    c.base_stats.defense.to_string(),
                    c.base_stats.speed.to_string(),
                    c.base_stats.intelligence.to_string(),
                    c.base_stats.spirit.to_string(),
                ]);
            }
            if output.is_empty() {
                table.print();
                println!("\nTotal: {} characters", characters.len());
                true
            } else {
                table.write_file(Path::new(output))
            }
        }
    }
}
