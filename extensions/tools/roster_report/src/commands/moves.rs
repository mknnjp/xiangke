use std::path::Path;

use crate::output::csv::emit_csv;
use crate::output::html::{emit_html, html_table};
use crate::output::table::Table;
use crate::parser::{element_label, load_moves};

/// Run the move assignment list. Returns `false` on output failure.
pub fn run_with(dir: &Path, format: &str, output: &str) -> bool {
    let (moves, diags) = load_moves(dir);
    for d in &diags {
        eprintln!("warning: {d}");
    }
    if moves.is_empty() {
        println!("No moves found.");
        return true;
    }
    match format {
        "csv" => {
            let headers = [
                "id", "name", "type", "power", "accuracy", "effect", "healing",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect();
            let rows = moves
                .iter()
                .map(|m| {
                    vec![
                        m.id.clone(),
                        m.name.clone(),
                        element_label(m.element).to_string(),
                        m.power.to_string(),
                        m.accuracy.to_string(),
                        format!("{:?}({})", m.effect, m.effect_chance),
                        m.healing.to_string(),
                    ]
                })
                .collect();
            emit_csv(headers, rows, output)
        }
        "html" => {
            let headers = ["ID", "Name", "Type", "Power", "Acc", "Effect", "Heal"]
                .iter()
                .map(|s| s.to_string())
                .collect::<Vec<_>>();
            let rows = moves
                .iter()
                .map(|m| {
                    vec![
                        m.id.clone(),
                        m.name.clone(),
                        element_label(m.element).to_string(),
                        m.power.to_string(),
                        m.accuracy.to_string(),
                        format!("{:?}({})", m.effect, m.effect_chance),
                        m.healing.to_string(),
                    ]
                })
                .collect::<Vec<_>>();
            let mut body = format!("<h1>Move List</h1>\n<p>Total: {} moves</p>\n", moves.len());
            body.push_str(&html_table(&headers, &rows));
            emit_html("Move List", &body, output)
        }
        _ => {
            let mut table = Table::new(
                vec!["ID", "Name", "Type", "Pow", "Acc", "Effect", "Heal"],
                vec![16, 6, 8, 4, 4, 14, 5],
            );
            for m in &moves {
                table.add_row(vec![
                    m.id.clone(),
                    m.name.clone(),
                    element_label(m.element).to_string(),
                    m.power.to_string(),
                    m.accuracy.to_string(),
                    format!("{:?}({})", m.effect, m.effect_chance),
                    m.healing.to_string(),
                ]);
            }
            if output.is_empty() {
                table.print();
                println!("\nTotal: {} moves", moves.len());
                true
            } else {
                table.write_file(Path::new(output))
            }
        }
    }
}
