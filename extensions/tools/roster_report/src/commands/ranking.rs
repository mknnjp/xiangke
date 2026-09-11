use std::path::Path;

use crate::output::csv::emit_csv;
use crate::output::html::{emit_html, html_table};
use crate::output::table::Table;
use crate::parser::{load_characters, type_label};

/// Run the stat-total ranking report. Returns `false` on output failure.
pub fn run_with(dir: &Path, format: &str, output: &str) -> bool {
    let (mut characters, diags) = load_characters(dir);
    for d in &diags {
        eprintln!("warning: {d}");
    }
    characters.sort_by_key(|a| std::cmp::Reverse(a.get_stat_sum()));
    match format {
        "csv" => {
            let headers = ["rank", "id", "name", "type", "sum"]
                .iter()
                .map(|s| s.to_string())
                .collect();
            let rows = characters
                .iter()
                .enumerate()
                .map(|(i, c)| {
                    vec![
                        (i + 1).to_string(),
                        c.id.clone(),
                        c.name.clone(),
                        type_label(c),
                        c.get_stat_sum().to_string(),
                    ]
                })
                .collect();
            emit_csv(headers, rows, output)
        }
        "html" => {
            let headers = ["Rank", "ID", "Name", "Type", "Sum"]
                .iter()
                .map(|s| s.to_string())
                .collect::<Vec<_>>();
            let rows = characters
                .iter()
                .enumerate()
                .map(|(i, c)| {
                    vec![
                        (i + 1).to_string(),
                        c.id.clone(),
                        c.name.clone(),
                        type_label(c),
                        c.get_stat_sum().to_string(),
                    ]
                })
                .collect::<Vec<_>>();
            let body = format!(
                "<h1>Stat Total Ranking</h1>\n<p>Total: {} characters</p>\n{}",
                characters.len(),
                html_table(&headers, &rows)
            );
            emit_html("Stat Total Ranking", &body, output)
        }
        _ => {
            let mut table = Table::new(
                vec!["Rank", "ID", "Name", "Type", "Sum"],
                vec![5, 18, 6, 12, 5],
            );
            for (i, c) in characters.iter().enumerate() {
                table.add_row(vec![
                    (i + 1).to_string(),
                    c.id.clone(),
                    c.name.clone(),
                    type_label(c),
                    c.get_stat_sum().to_string(),
                ]);
            }
            if output.is_empty() {
                table.print();
                true
            } else {
                table.write_file(Path::new(output))
            }
        }
    }
}
