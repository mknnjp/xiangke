use std::fs;
use std::path::Path;

/// Simple fixed-width table renderer.
pub struct Table {
    headers: Vec<String>,
    widths: Vec<usize>,
    rows: Vec<Vec<String>>,
}

impl Table {
    pub fn new(headers: Vec<&str>, widths: Vec<usize>) -> Self {
        Self {
            headers: headers.into_iter().map(|s| s.to_string()).collect(),
            widths,
            rows: Vec::new(),
        }
    }

    pub fn add_row(&mut self, row: Vec<String>) {
        self.rows.push(row);
    }

    fn width(&self, col: usize) -> usize {
        self.widths.get(col).copied().unwrap_or(10)
    }

    fn format_row(&self, cells: &[String]) -> String {
        cells
            .iter()
            .enumerate()
            .map(|(i, c)| {
                let w = self.width(i);
                if c.len() >= w {
                    c.clone()
                } else {
                    format!("{c:<w$}")
                }
            })
            .collect::<Vec<_>>()
            .join(" | ")
    }

    pub fn render(&self) -> String {
        let mut out = String::new();
        out.push_str(&self.format_row(&self.headers));
        out.push('\n');
        let sep: Vec<String> = (0..self.headers.len())
            .map(|i| "-".repeat(self.width(i)))
            .collect();
        out.push_str(&sep.join("-+-"));
        out.push('\n');
        for row in &self.rows {
            out.push_str(&self.format_row(row));
            out.push('\n');
        }
        out
    }

    pub fn print(&self) {
        print!("{}", self.render());
    }

    pub fn write_file(&self, path: &Path) -> bool {
        fs::write(path, self.render()).is_ok()
    }
}
