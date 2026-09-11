use std::collections::HashSet;
use std::path::Path;

use xiangke_core::validator::{validate_character, validate_move};

use crate::output::csv::emit_csv;
use crate::output::html::{emit_html, html_table};
use crate::output::table::Table;
use crate::parser::{load_characters, load_moves};

struct Anomaly {
    severity: String,
    entity: String,
    message: String,
}

/// Run anomaly detection. Returns `(report_ok, error_count)`.
pub fn run_with(dir: &Path, format: &str, output: &str) -> (bool, usize) {
    let (characters, char_diags) = load_characters(dir);
    let (moves, move_diags) = load_moves(dir);
    let mut anomalies: Vec<Anomaly> = Vec::new();
    for d in char_diags.iter().chain(move_diags.iter()) {
        anomalies.push(Anomaly {
            severity: "warning".to_string(),
            entity: "-".to_string(),
            message: d.clone(),
        });
    }

    // Duplicate ID checks.
    let mut seen_moves = HashSet::new();
    for m in &moves {
        if !seen_moves.insert(m.id.clone()) {
            anomalies.push(Anomaly {
                severity: "error".to_string(),
                entity: m.id.clone(),
                message: format!("Duplicate move ID: {}", m.id),
            });
        }
    }
    let mut seen_chars = HashSet::new();
    for c in &characters {
        if !seen_chars.insert(c.id.clone()) {
            anomalies.push(Anomaly {
                severity: "error".to_string(),
                entity: c.id.clone(),
                message: format!("Duplicate character ID: {}", c.id),
            });
        }
    }

    // Core rule validation (MR-*/CR-*).
    for m in &moves {
        if let Err(errs) = validate_move(m) {
            for e in errs {
                anomalies.push(Anomaly {
                    severity: "error".to_string(),
                    entity: m.id.clone(),
                    message: format!("[{}] {}", e.code, e.message),
                });
            }
        }
    }
    for c in &characters {
        if let Err(errs) = validate_character(c, &moves) {
            for e in errs {
                anomalies.push(Anomaly {
                    severity: "error".to_string(),
                    entity: c.id.clone(),
                    message: format!("[{}] {}", e.code, e.message),
                });
            }
        }
    }

    // Cross-entity checks: unknown move references + unreferenced moves.
    let move_ids: HashSet<&str> = moves.iter().map(|m| m.id.as_str()).collect();
    let mut referenced: HashSet<&str> = HashSet::new();
    for c in &characters {
        for mid in &c.moves {
            referenced.insert(mid.as_str());
            if !move_ids.contains(mid.as_str()) {
                anomalies.push(Anomaly {
                    severity: "error".to_string(),
                    entity: c.id.clone(),
                    message: format!("Unknown move reference: {mid}"),
                });
            }
        }
    }
    for m in &moves {
        if !referenced.contains(m.id.as_str()) {
            anomalies.push(Anomaly {
                severity: "warning".to_string(),
                entity: m.id.clone(),
                message: "Move is not referenced by any character".to_string(),
            });
        }
    }

    let error_count = anomalies.iter().filter(|a| a.severity == "error").count();
    let ok = match format {
        "csv" => {
            let headers = ["severity", "entity", "message"]
                .iter()
                .map(|s| s.to_string())
                .collect();
            let rows = anomalies
                .iter()
                .map(|a| vec![a.severity.clone(), a.entity.clone(), a.message.clone()])
                .collect();
            emit_csv(headers, rows, output)
        }
        "html" => {
            let headers = ["Severity", "Entity", "Message"]
                .iter()
                .map(|s| s.to_string())
                .collect::<Vec<_>>();
            let rows = anomalies
                .iter()
                .map(|a| vec![a.severity.clone(), a.entity.clone(), a.message.clone()])
                .collect::<Vec<_>>();
            let mut body = format!(
                "<h1>Data Anomalies</h1>\n<p>Errors: {error_count}, Total: {} findings</p>\n",
                anomalies.len()
            );
            body.push_str(&html_table(&headers, &rows));
            emit_html("Data Anomalies", &body, output)
        }
        _ => {
            if anomalies.is_empty() {
                println!("No anomalies found.");
                true
            } else {
                let mut table = Table::new(vec!["Severity", "Entity", "Message"], vec![9, 18, 60]);
                for a in &anomalies {
                    table.add_row(vec![
                        a.severity.clone(),
                        a.entity.clone(),
                        a.message.clone(),
                    ]);
                }
                if output.is_empty() {
                    table.print();
                    println!(
                        "\nErrors: {error_count}, Total: {} findings",
                        anomalies.len()
                    );
                    true
                } else {
                    table.write_file(Path::new(output))
                }
            }
        }
    };
    (ok, error_count)
}
