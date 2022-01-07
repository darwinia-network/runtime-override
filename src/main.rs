// --- std ---
use std::{
	env,
	fs::{self, File},
	path::Path,
	process::{Command, Stdio},
};
// --- crates.io ---
use anyhow::Result;
use clap::{ArgEnum, Parser};
use wasm_loader::Source;
// --- github ---
use subwasmlib::Subwasm;

macro_rules! match_runtimes {
	($self:ident, $a:expr, $b:expr) => {
		match $self {
			Runtime::Darwinia | Runtime::Crab => $a,
			Runtime::Pangoro | Runtime::Pangolin => $b,
		}
	};
}

#[derive(Clone, Debug, ArgEnum)]
pub enum Runtime {
	Darwinia,
	Crab,
	Pangoro,
	Pangolin,
}
impl Runtime {
	fn name(&self) -> String {
		format!("{:?}", self)
	}

	fn lowercase_name(&self) -> String {
		self.name().to_ascii_lowercase()
	}

	fn github(&self) -> String {
		format!("https://github.com/darwinia-network/{}", self.repository())
	}
	fn repository(&self) -> &str {
		match_runtimes!(self, "darwinia", "darwinia-common")
	}

	fn path(&self) -> String {
		format!(
			"{}/{}",
			match_runtimes!(self, "runtime", "node/runtime"),
			self.lowercase_name()
		)
	}
}

#[derive(Debug, Parser)]
struct Cli {
	#[clap(
		help = "Specific runtime (non case sensitive)",
		arg_enum,
		short,
		long,
		ignore_case = true,
		required = true,
		takes_value = true,
		value_name = "CHAIN"
	)]
	runtime: Runtime,
	#[clap(
		help = "Specific branch/commit/tag",
		short,
		long,
		takes_value = true,
		value_name = "VALUE",
		default_value = "main"
	)]
	target: String,
}

fn main() -> Result<()> {
	let Cli { runtime, target } = Cli::parse();

	create_dir_unchecked("build")?;

	let runtime_repository = runtime.repository();

	if !Path::new(runtime_repository).is_dir() {
		run(
			"git",
			&[
				"clone",
				&runtime.github(),
				&format!("build/{}", runtime_repository),
			],
		)?;
	}

	env::set_current_dir(format!("build/{}", runtime_repository))?;

	let runtime_manifest = format!("{}/Cargo.toml", runtime.path());
	let runtime_lowercase_name = runtime.lowercase_name();

	run("git", &["fetch", "--all"])?;
	run("git", &["checkout", &target])?;
	run(
		"cargo",
		&[
			"clean",
			"--release",
			"--manifest-path",
			&runtime_manifest,
			"-p",
			&format!("{}-runtime", runtime_lowercase_name),
		],
	)?;
	run(
		"cargo",
		&[
			"b",
			"--release",
			"--manifest-path",
			&runtime_manifest,
			"--features",
			"evm-tracing",
		],
	)?;

	env::set_current_dir("../../")?;

	let name_prefix = format!(
		"{}-runtime-{}-tracing-runtime",
		runtime_lowercase_name, target
	);

	create_dir_unchecked("wasms")?;
	create_dir_unchecked("wasm-digests")?;

	let wasm = format!("wasms/{}.compact.wasm", name_prefix);

	fs::rename(
		format!(
			"build/{}/target/release/wbuild/{}-runtime/{}_runtime.compact.wasm",
			runtime_repository, runtime_lowercase_name, runtime_lowercase_name,
		),
		&wasm,
	)?;

	let wasm = Subwasm::new(&Source::File(wasm.into()));
	let runtime_info = File::create(format!("wasm-digests/{}.json", name_prefix))?;

	serde_json::to_writer(runtime_info, wasm.runtime_info())?;

	Ok(())
}

fn create_dir_unchecked(path: &str) -> Result<()> {
	if !Path::new(path).exists() {
		fs::create_dir_all(path)?;
	}

	Ok(())
}

fn run(program: &str, args: &[&str]) -> Result<()> {
	Command::new(program)
		.args(args)
		.stderr(Stdio::inherit())
		.output()?;

	Ok(())
}
