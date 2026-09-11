use std::collections::BTreeMap;
use std::path::Path;

use xiangke_core::types::TypeElement;

use crate::output::csv::emit_csv;
use crate::output::html::{emit_html, html_table};
use crate::output::table::Table;
use crate::parser::{element_label, load_characters};

/// Run the type distribution report. Returns `false` on output failure.
pub fn run_with(dir: &Path, format: &str, output: &str) -> bool {
    let (characters, diags) = load_characters(dir);
    for d in &diags {
        eprintln!("warning: {d}");
    }
    let mut counts: BTreeMap<u8, usize> = BTreeMap::new();
    for c in &characters {
        *counts.entry(c.element as u8).or_insert(0) += 1;
    }
    let total = characters.len().max(1) as f64;
    match format {
        "csv" => {
            let headers = ["type", "count", "share"]
                .iter()
                .map(|s| s.to_string())
                .collect();
            let rows = TypeElement::ALL
                .iter()
                .map(|t| {
                    let n = counts.get(&(*t as u8)).copied().unwrap_or(0);
                    vec![
                        element_label(*t).to_string(),
                        n.to_string(),
                        format!("{:.1}%", n as f64 / total * 100.0),
                    ]
                })
                .collect();
            emit_csv(headers, rows, output)
        }
        "html" => {
            let headers = ["Type", "Count", "Share"]
                .iter()
                .map(|s| s.to_string())
                .collect::<Vec<_>>();
            let rows = TypeElement::ALL
                .iter()
                .map(|t| {
                    let n = counts.get(&(*t as u8)).copied().unwrap_or(0);
                    vec![
                        element_label(*t).to_string(),
                        n.to_string(),
                        format!("{:.1}%", n as f64 / total * 100.0),
                    ]
                })
                .collect::<Vec<_>>();
            let mut body = format!(
                "<h1>Type Distribution</h1>\n<p>Total: {} characters</p>\n",
                characters.len()
            );
            body.push_str(&html_table(&headers, &rows));
            emit_html("Type Distribution", &body, output)
        }
        _ => {
            let mut table = Table::new(vec!["Type", "Count", "Share"], vec![10, 6, 8]);
            for t in TypeElement::ALL {
                let n = counts.get(&(t as u8)).copied().unwrap_or(0);
                table.add_row(vec![
                    element_label(t).to_string(),
                    n.to_string(),
                    format!("{:.1}%", n as f64 / total * 100.0),
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
