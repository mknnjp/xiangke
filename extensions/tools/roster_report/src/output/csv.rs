use std::fs;
use std::path::Path;

fn escape_csv(cell: &str) -> String {
    if cell.contains([',', '"', '\n']) {
        format!("\"{}\"", cell.replace('"', "\"\""))
    } else {
        cell.to_string()
    }
}

/// Render headers + rows as CSV text.
pub fn render_csv(headers: &[String], rows: &[Vec<String>]) -> String {
    let mut out = String::new();
    out.push_str(
        &headers
            .iter()
            .map(|h| escape_csv(h))
            .collect::<Vec<_>>()
            .join(","),
    );
    out.push('\n');
    for row in rows {
        out.push_str(
            &row.iter()
                .map(|c| escape_csv(c))
                .collect::<Vec<_>>()
                .join(","),
        );
        out.push('\n');
    }
    out
}

/// Print CSV to stdout, or write to `output` when non-empty.
/// Returns `false` on I/O failure.
pub fn emit_csv(headers: Vec<String>, rows: Vec<Vec<String>>, output: &str) -> bool {
    let text = render_csv(&headers, &rows);
    if output.is_empty() {
        print!("{text}");
        true
    } else {
        fs::write(Path::new(output), text).is_ok()
    }
}
