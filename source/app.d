import std.stdio : writeln;
import std.file : write, setTimes;
import std.datetime : SysTime, UTC;
import std.getopt;
import std.process;
import std.string : strip;
import std.format;
import std.exception;
import core.time: TimeException;
import core.stdc.stdlib:abort;
import semver;

enum GIT_DESCR_CMD = ["git", "describe", "--tags", "--always"];
enum GIT_REVLIST_CMD = ["git", "rev-list", "-n", "1"];
enum GIT_SHOW_CMD = ["git", "show", "-s", "--date=format-local:%Y-%m-%dT%H:%M:%S", "--format=%aI"];
enum GIT_SHOW_ENV = ["TZ": "UTC0"];

enum FMT_STR = "// AUTOGENERATED BY GITVER, DO NOT MODIFY
module %s;

%s
enum %s_VERSION = \"%s\";

// trans rights";

enum VER_DOC_STR = "/**
	%s Version, autogenerated with gitver
*/";

void main(string[] args)
{
	bool printOut;
	string prefix = "V";
	string itchFile;
	string file = "source/ver_.d";
	string mod = "ver_";
	string appName = null;
	string preserveMTime = null;
	auto helpInformation = getopt(
		args,
		"prefix", "Prefix to prepend to the version enum", &prefix,
		"appname", "Name of app", &appName,
		"file", "The file to write to", &file,
		"itchfile", "The file (if any) to write itch.io version number to", &itchFile,
		"mod", "The name of the module", &mod,
		"pout", "Print out instead of writing to file", &printOut,
		"preserve-mtime", "Preserve mtime of ver_.d", &preserveMTime
	);

	if (helpInformation.helpWanted) {
		defaultGetoptPrinter(
			"Tool to generate ver_.d files from git tags",
			helpInformation.options
		);
	}

	auto result = execute(GIT_DESCR_CMD);
	string version_ = result.output.strip;
	string versionName = version_;

	// Error out
	// TODO: Take other Git languages in to account and check stderr instead
	if (version_[0..5] == "fatal") {
		writeln(version_);
		return;
	}

	// Prepend commmit+ to commit-only versions
	if (!SemVer(version_).isValid) {
		version_ = "commit+"~version_;
	}

	// PrintOut
	if (printOut) {
		writeln(version_);
		return;
	}

	// Write stuff out
	write(file, FMT_STR.format(
		mod,
		appName ? VER_DOC_STR.format(appName) : "",
		prefix,
		version_
	));

	// write stuff out for itch.io
	if (itchFile.length > 0) {
		write(itchFile, version_);
	}

	if (preserveMTime == "yes") {
		// Get commitId for version name.
		auto commitId = execute(GIT_REVLIST_CMD ~ versionName).output.strip;
		assert(commitId[0..5] != "fatal", "Error: Failed to update mtime.");

		// Get timestamp of the initial commit.
		auto aTimeStr = execute(GIT_SHOW_CMD ~ commitId, GIT_SHOW_ENV).output.strip;
		SysTime aTime;
		try {
		    aTime = SysTime.fromISOExtString(aTimeStr, UTC());
		} catch(TimeException) {
			writeln("Error: failed to get commit time from git.");
			abort();
		}

	    setTimes(file, aTime, aTime);
		if (itchFile.length > 0)
		    setTimes(itchFile, aTime, aTime);
	}
}

unittest {
	assert(!SemVer("587d095").isValid, "Should be invalid!");
	assert(!SemVer("commit+587d095").isValid, "Should be invalid!");
	assert(SemVer("v0.1-1-g787c667").isValid, "Should be invalid!");
}