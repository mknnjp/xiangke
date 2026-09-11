use std::fs;
use std::path::Path;

use xiangke_core::character::CharacterData;

use crate::output::html::{emit_html, html_footer, html_header};
use crate::parser::load_characters;

const CHART_SIZE: f64 = 400.0;
const CHART_CENTER: f64 = CHART_SIZE / 2.0;
const CHART_RADIUS: f64 = 150.0;
const MAX_STAT: f64 = 200.0;
const GRID_LEVELS: usize = 4;
const CHARACTER_COLORS: [&str; 10] = [
    "#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c", "#e67e22", "#34495e",
    "#e91e63", "#00bcd4",
];
const STAT_LABELS: [&str; 6] = ["HP", "ATK", "DEF", "SPD", "INT", "SPR"];

fn stat_values(c: &CharacterData) -> [f64; 6] {
    [
        c.base_stats.hp as f64,
        c.base_stats.attack as f64,
        c.base_stats.defense as f64,
        c.base_stats.speed as f64,
        c.base_stats.intelligence as f64,
        c.base_stats.spirit as f64,
    ]
}

fn point(axis: usize, value: f64) -> (f64, f64) {
    // Start at the top (-90deg), one axis per stat.
    let angle = -std::f64::consts::FRAC_PI_2 + axis as f64 * std::f64::consts::TAU / 6.0;
    let r = (value / MAX_STAT).min(1.0) * CHART_RADIUS;
    (
        CHART_CENTER + r * angle.cos(),
        CHART_CENTER + r * angle.sin(),
    )
}

fn radar_svg(characters: &[CharacterData]) -> String {
    let mut svg = format!(
        "<svg width=\"{0}\" height=\"{0}\" viewBox=\"0 0 {0} {0}\" \
         xmlns=\"http://www.w3.org/2000/svg\">\n",
        CHART_SIZE as u32
    );
    // Grid circles + axis lines + labels.
    for level in 1..=GRID_LEVELS {
        let r = CHART_RADIUS * level as f64 / GRID_LEVELS as f64;
        svg.push_str(&format!(
            "<circle cx=\"{CHART_CENTER}\" cy=\"{CHART_CENTER}\" r=\"{r}\" \
             fill=\"none\" stroke=\"#ccc\"/>\n"
        ));
    }
    for (axis, label) in STAT_LABELS.iter().enumerate() {
        let (x, y) = point(axis, MAX_STAT);
        svg.push_str(&format!(
            "<line x1=\"{CHART_CENTER}\" y1=\"{CHART_CENTER}\" x2=\"{x:.1}\" y2=\"{y:.1}\" \
             stroke=\"#ccc\"/>\n"
        ));
        let (lx, ly) = point(axis, MAX_STAT + 22.0);
        svg.push_str(&format!(
            "<text x=\"{lx:.1}\" y=\"{ly:.1}\" text-anchor=\"middle\" \
             font-size=\"12\">{label}</text>\n"
        ));
    }
    // One polygon per character (up to palette size, then cycle).
    for (i, c) in characters.iter().enumerate() {
        let color = CHARACTER_COLORS[i % CHARACTER_COLORS.len()];
        let pts = stat_values(c)
            .iter()
            .enumerate()
            .map(|(axis, v)| {
                let (x, y) = point(axis, *v);
                format!("{x:.1},{y:.1}")
            })
            .collect::<Vec<_>>()
            .join(" ");
        svg.push_str(&format!(
            "<polygon points=\"{pts}\" fill=\"{color}\" fill-opacity=\"0.25\" \
             stroke=\"{color}\" stroke-width=\"2\"/>\n"
        ));
    }
    svg.push_str("</svg>\n");
    svg
}

/// Run the radar chart report (HTML with inline SVG).
/// Returns `false` on output failure.
pub fn run_with(dir: &Path, _format: &str, output: &str) -> bool {
    let (characters, diags) = load_characters(dir);
    for d in &diags {
        eprintln!("warning: {d}");
    }
    if characters.is_empty() {
        println!("No characters found.");
        return true;
    }
    // Keep the chart readable: top 10 by stat total.
    let mut top = characters.clone();
    top.sort_by_key(|a| std::cmp::Reverse(a.get_stat_sum()));
    top.truncate(10);

    let mut body = format!(
        "<h1>Stat Radar Chart</h1>\n<p>Top {} of {} characters by stat total</p>\n",
        top.len(),
        characters.len()
    );
    body.push_str(&radar_svg(&top));
    body.push_str("<ul>\n");
    for (i, c) in top.iter().enumerate() {
        let color = CHARACTER_COLORS[i % CHARACTER_COLORS.len()];
        body.push_str(&format!(
            "<li><span style=\"color:{color}\">■</span> {} ({}) — sum {}</li>\n",
            c.id,
            c.name,
            c.get_stat_sum()
        ));
    }
    body.push_str("</ul>\n");

    if output.is_empty() {
        let mut html = html_header("Stat Radar Chart");
        html.push_str(&body);
        html.push_str(&html_footer());
        print!("{html}");
        true
    } else {
        emit_html("Stat Radar Chart", &body, output)
    }
}

#[allow(dead_code)]
pub fn write_svg_file(characters: &[CharacterData], path: &Path) -> bool {
    fs::write(path, radar_svg(characters)).is_ok()
}
