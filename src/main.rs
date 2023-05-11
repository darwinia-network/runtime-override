// std
use std::{
	env,
	fs::{self, File},
	path::Path,
	process::{self, Command, Stdio},
};
// crates.io
pub use anyhow::Result;
use clap::Parser;
// github.com
use subwasmlib::Subwasm;
use wasm_loader::Source;

#[derive(Debug, Parser)]
struct Cli {
	/// GitHub repository.
	#[clap(value_enum, short, long, required = true, value_name = "URI")]
	github: String,
	/// Specific branch/commit/tag.
	#[clap(short, long, value_name = "VALUE", default_value = "main")]
	target: String,
	/// Runtime manifest path.
	#[clap(value_enum, short, long, required = true, value_name = "PATH")]
	manifest: String,
	/// Runtime name.
	#[clap(value_enum, short, long, required = true, value_name = "NAME")]
	runtime: String,
	/// Specific output path.
	#[clap(short, long, value_name = "PATH", default_value = "overridden-runtimes")]
	output: String,
	/// Whether to cache the build or not.
	///
	/// Don't use this in production environments.
	#[clap(short, long)]
	cache: bool,
}

fn main() -> Result<()> {
	let Cli { github, target, manifest, runtime, output, cache } = Cli::parse();

	if !cache {
		println!("[runtime-override] cleaning up the cache");

		let _ = fs::remove_dir_all("build");
	} else {
		println!("[runtime-override] using the cache");
	}

	let repository = github.rsplit_once('/').expect("unexpected GitHub URI").1;
	let build_path = format!("build/{repository}");

	if !Path::new(&build_path).exists() {
		run("git", &["clone", &github, &build_path], &[])?;
	}

	println!("[runtime-override] setting current working directory to {build_path}");
	env::set_current_dir(build_path)?;

	run("git", &["fetch", "--all"], &[])?;
	run("git", &["checkout", &target], &[])?;
	run("rustup", &["show"], &["RUSTUP_TOOLCHAIN"])?;
	run(
		"cargo",
		&["build", "--release", "--manifest-path", &manifest, "--features", "evm-tracing"],
		&["RUSTUP_TOOLCHAIN"],
	)?;

	env::set_current_dir("../../")?;

	let name_prefix = format!("{runtime}-{target}-tracing-runtime");
	let wasms_dir = format!("{output}/{runtime}/wasms");
	let digests_dir = format!("{output}/{runtime}/digests");

	create_dir_unchecked(&wasms_dir)?;
	create_dir_unchecked(&digests_dir)?;

	let wasm_path = format!("{wasms_dir}/{name_prefix}.compact.compressed.wasm");
	let digest_path = format!("{digests_dir}/{name_prefix}.json");

	fs::rename(
		format!(
			"build/{repository}/target/release/wbuild/{runtime}-runtime/{runtime}_runtime.compact.compressed.wasm",
		),
		&wasm_path,
	)?;

	let wasm = Subwasm::new(&Source::File(wasm_path.clone().into()));
	let runtime_info = File::create(&digest_path)?;

	serde_json::to_writer(runtime_info, wasm.runtime_info())?;

	println!("[runtime-override] generated WASM:   {wasm_path}");
	println!("[runtime-override] generated digest: {digest_path}");

	Ok(())
}

fn create_dir_unchecked(path: &str) -> Result<()> {
	if !Path::new(path).exists() {
		fs::create_dir_all(path)?;
	}

	Ok(())
}

fn run(program: &str, args: &[&str], exclude_envs: &[&str]) -> Result<()> {
	println!("[runtime-override] running `{program} {}`", args.join(" "));

	let mut c = Command::new(program);

	c.args(args);
	exclude_envs.iter().for_each(|e| {
		c.env_remove(e);
	});

	let r = c.stdout(Stdio::inherit()).stderr(Stdio::inherit()).output()?;

	if r.status.success() {
		Ok(())
	} else {
		process::exit(r.status.code().unwrap_or(-1));
	}
}
