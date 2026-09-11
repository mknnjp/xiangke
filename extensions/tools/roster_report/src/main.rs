mod commands;
mod output;
mod parser;

use std::path::PathBuf;

const VERSION: &str = "0.1.0";

fn usage() {
    println!(
        "Usage: roster-report <command> [options]\n\
         \n\
         Commands:\n\
         \x20 roster      Show character roster table\n\
         \x20 types       Show type distribution analysis\n\
         \x20 moves       Show move assignment list\n\
         \x20 anomalies   Detect data anomalies\n\
         \x20 ranking     Show stat total ranking\n\
         \x20 radar       Generate HTML radar chart\n\
         \n\
         Options:\n\
         \x20 --format=<fmt>   Output format: table (default), csv, html\n\
         \x20 --dir=<path>     Resource directory (default: ../../resources)\n\
         \x20 --output=<path>  Write the report to a file (table/csv/html)\n\
         \x20 --help           Show this help message\n\
         \x20 --version        Show version\n\
         \n\
         Examples:\n\
         \x20 roster-report roster\n\
         \x20 roster-report roster --format=csv\n\
         \x20 roster-report types\n\
         \x20 roster-report radar --format=html --output=report.html"
    );
}

fn default_resource_dir() -> PathBuf {
    std::env::current_dir()
        .unwrap_or_default()
        .join("..")
        .join("..")
        .join("resources")
}

fn main() {
    let mut cmd = String::new();
    let mut format = "table".to_string();
    let mut dir = default_resource_dir();
    let mut output = String::new();
    let mut show_help = false;
    let mut show_version = false;

    for arg in std::env::args().skip(1) {
        if let Some(rest) = arg.strip_prefix("--format=") {
            format = rest.to_string();
        } else if let Some(rest) = arg.strip_prefix("--dir=") {
            dir = PathBuf::from(rest);
        } else if let Some(rest) = arg.strip_prefix("--output=") {
            output = rest.to_string();
        } else if arg == "--help" || arg == "-h" {
            show_help = true;
        } else if arg == "--version" || arg == "-v" {
            show_version = true;
        } else if arg.starts_with('-') {
            eprintln!("Error: Unknown option: {arg}");
            std::process::exit(1);
        } else if cmd.is_empty() {
            cmd = arg;
        } else {
            eprintln!("Error: Unexpected argument: {arg}");
            std::process::exit(1);
        }
    }

    if show_help {
        usage();
        return;
    }
    if show_version {
        println!("roster-report version {VERSION}");
        return;
    }
    if !matches!(format.as_str(), "table" | "csv" | "html") {
        eprintln!("Error: Unknown format: {format} (expected table, csv, or html)");
        std::process::exit(1);
    }
    if !dir.is_dir() {
        eprintln!("Error: Resource directory not found: {}", dir.display());
        std::process::exit(1);
    }

    let ok = match cmd.as_str() {
        "roster" => commands::roster::run_with(&dir, &format, &output),
        "types" => commands::types::run_with(&dir, &format, &output),
        "moves" => commands::moves::run_with(&dir, &format, &output),
        "anomalies" => {
            let (report_ok, error_count) = commands::anomalies::run_with(&dir, &format, &output);
            if report_ok && error_count > 0 {
                eprintln!("anomalies: {error_count} error(s) found");
            }
            report_ok && error_count == 0
        }
        "ranking" => commands::ranking::run_with(&dir, &format, &output),
        "radar" => commands::radar::run_with(&dir, &format, &output),
        "" => {
            eprintln!("Error: No command specified.");
            eprintln!("Run with --help for usage information.");
            std::process::exit(1);
        }
        other => {
            eprintln!("Error: Unknown command: {other}");
            eprintln!("Run with --help for usage information.");
            std::process::exit(1);
        }
    };
    if !ok {
        std::process::exit(1);
    }
}
