use std::fs;

fn escape_html(cell: &str) -> String {
    cell.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

pub fn html_header(title: &str) -> String {
    format!(
        "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"><title>{}</title>\n\
         <style>table{{border-collapse:collapse}}th,td{{border:1px solid #999;padding:4px 8px}}</style>\n\
         </head><body>\n",
        escape_html(title)
    )
}

pub fn html_footer() -> String {
    "</body></html>\n".to_string()
}

pub fn html_table(headers: &[String], rows: &[Vec<String>]) -> String {
    let mut out = String::from("<table>\n<thead><tr>");
    for h in headers {
        out.push_str(&format!("<th>{}</th>", escape_html(h)));
    }
    out.push_str("</tr></thead>\n<tbody>\n");
    for row in rows {
        out.push_str("<tr>");
        for cell in row {
            out.push_str(&format!("<td>{}</td>", escape_html(cell)));
        }
        out.push_str("</tr>\n");
    }
    out.push_str("</tbody></table>\n");
    out
}

/// Print HTML to stdout, or write to `output` when non-empty.
/// Returns `false` on I/O failure.
pub fn emit_html(title: &str, body: &str, output: &str) -> bool {
    let mut html = html_header(title);
    html.push_str(body);
    html.push_str(&html_footer());
    if output.is_empty() {
        print!("{html}");
        true
    } else {
        fs::write(output, html).is_ok()
    }
}
