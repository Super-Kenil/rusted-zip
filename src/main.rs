use std::env;
use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::time::Instant;

use rayon::prelude::*;
use walkdir::WalkDir;
use zip::write::SimpleFileOptions;
use zip::{ZipWriter, ZipArchive};
use zip::CompressionMethod;

fn collect_files(root: &Path) -> Vec<PathBuf> {
    WalkDir::new(root)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().is_file())
        .map(|e| e.path().to_path_buf())
        .collect()
}

fn zip_path(input: &Path) -> io::Result<()> {
    let start = Instant::now();

    let output_name = if input.is_dir() {
        format!("{}.zip", input.file_name().unwrap().to_string_lossy())
    } else {
        format!("{}.zip", input.file_stem().unwrap().to_string_lossy())
    };

    let parent = input.parent().unwrap_or_else(|| Path::new("."));
    let output_path = parent.join(&output_name);

    let file = File::create(&output_path)?;
    let writer = BufWriter::with_capacity(1024 * 1024, file);
    let mut zip = ZipWriter::new(writer);

    if input.is_file() {
        let options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Deflated)
            .compression_level(Some(6));

        let name = input.file_name().unwrap().to_string_lossy().to_string();
        zip.start_file(&name, options)?;

        let f = File::open(input)?;
        let mut reader = BufReader::with_capacity(512 * 1024, f);
        let mut buf = Vec::new();
        reader.read_to_end(&mut buf)?;
        zip.write_all(&buf)?;
    } else {
        let files = collect_files(input);
        let root_parent = input.parent().unwrap_or_else(|| Path::new("."));

        // Parallel read phase — collect all file contents into memory
        let file_data: Vec<(String, Vec<u8>)> = files
            .par_iter()
            .filter_map(|path| {
                let rel = path.strip_prefix(root_parent).ok()?;
                let rel_str = rel.to_string_lossy().replace('\\', "/");

                let f = File::open(path).ok()?;
                let mut reader = BufReader::with_capacity(512 * 1024, f);
                let mut buf = Vec::new();
                reader.read_to_end(&mut buf).ok()?;

                Some((rel_str, buf))
            })
            .collect();

        // Sequential write phase — ZipWriter is not Send
        for (name, data) in &file_data {
            let options = SimpleFileOptions::default()
                .compression_method(CompressionMethod::Deflated)
                .compression_level(Some(6));

            zip.start_file(name, options)?;
            zip.write_all(data)?;
        }
    }

    zip.finish()
        .map_err(|e| io::Error::new(io::ErrorKind::Other, e))?;

    let elapsed = start.elapsed();
    println!(
        "✓ Created: {} ({:.2?})",
        output_path.display(),
        elapsed
    );

    Ok(())
}

fn unzip_path(input: &Path) -> io::Result<()> {
    let start = Instant::now();

    let stem = input
        .file_stem()
        .unwrap_or_else(|| input.file_name().unwrap())
        .to_string_lossy()
        .to_string();
    let parent = input.parent().unwrap_or_else(|| Path::new("."));
    let out_dir = parent.join(&stem);

    fs::create_dir_all(&out_dir)?;

    let file = File::open(input)?;
    let reader = BufReader::with_capacity(1024 * 1024, file);
    let mut archive = ZipArchive::new(reader)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

    for i in 0..archive.len() {
        let mut entry = archive
            .by_index(i)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        let entry_path = match entry.enclosed_name() {
            Some(p) => out_dir.join(p),
            None => continue,
        };

        if entry.is_dir() {
            fs::create_dir_all(&entry_path)?;
        } else {
            if let Some(parent) = entry_path.parent() {
                fs::create_dir_all(parent)?;
            }
            let out_file = File::create(&entry_path)?;
            let mut writer = BufWriter::with_capacity(512 * 1024, out_file);
            io::copy(&mut entry, &mut writer)?;
        }
    }

    let elapsed = start.elapsed();
    println!(
        "✓ Extracted to: {} ({:.2?})",
        out_dir.display(),
        elapsed
    );

    Ok(())
}

fn print_usage() {
    eprintln!("Rusted ZIP - High-performance zip utility for Windows");
    eprintln!();
    eprintln!("Usage:");
    eprintln!("  rustedzip zip   <file_or_folder>");
    eprintln!("  rustedzip unzip <file.zip>");
    eprintln!();
    eprintln!("Examples:");
    eprintln!("  rustedzip zip   my_project\\");
    eprintln!("  rustedzip zip   report.docx");
    eprintln!("  rustedzip unzip archive.zip");
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 3 {
        print_usage();
        std::process::exit(1);
    }

    let command = args[1].to_lowercase();
    let target = Path::new(&args[2]);

    if !target.exists() {
        eprintln!("Error: '{}' does not exist.", target.display());
        std::process::exit(1);
    }

    let result = match command.as_str() {
        "zip" | "compress" | "z" => zip_path(target),
        "unzip" | "extract" | "x" => unzip_path(target),
        _ => {
            eprintln!("Unknown command: '{}'\n", command);
            print_usage();
            std::process::exit(1);
        }
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}