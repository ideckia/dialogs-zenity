package;

import haxe.Exception;

using api.dialog.Dialog;
using api.dialog.Dialog.Progress;
using api.dialog.DialogTypes;

enum abstract QuestionResponse(String) to String {
	var OK;
	var CANCEL;
}

enum abstract WindowIcon(String) to String {
	var info;
	var warning;
	var error;
	var question;
	var password;
}

typedef Options = {
	var ?height:UInt;
	var ?width:UInt;
	var ?windowIcon:WindowIcon;
	var ?dialogIcon:String;
	var ?okLabel:String;
	var ?cancelLabel:String;
	var ?parent:Any;
}

@:expose('Dialog')
class Zenity implements Dialog {
	static var executablePath:String;

	var defaultOptions:Options;
	var options:Options;

	public function new() {
		var exceptionMessage = 'Download "zenity" and put it in the lib folder, please. You can get it here: https://github.com/ncruces/zenity';
		function checkInstalation() {
			trace('Checking zenity is installed.');
			var status = Sys.command(executablePath, ['--version']);
			if (status != 0)
				throw new haxe.Exception(exceptionMessage);
		}

		var filename;
		switch (Sys.systemName()) {
			case 'Mac':
				filename = 'zenity';
			case 'Windows':
				filename = 'zenity.exe';
			default:
				executablePath = 'zenity';
				exceptionMessage = 'Download "zenity" from your package manager, please.';
				checkInstalation();
				return;
		}

		executablePath = haxe.io.Path.join([js.Node.__dirname, 'lib', filename]);
		checkInstalation();
		defaultOptions = {
			height: 200,
			width: 300,
			windowIcon: WindowIcon.info,
			dialogIcon: '',
			parent: null
		};
		options = defaultOptions;
	}

	public function setOptions(newOptions:Any) {
		if (newOptions == null)
			newOptions = defaultOptions;

		Macros.assign(Options, options, cast newOptions);
	}

	public function notify(title:String, text:String) {
		runZenity(buildBaseArgs('notification', title, text));
	}

	public function info(title:String, text:String) {
		runZenity(buildBaseArgs('info', title, text));
	}

	public function error(title:String, text:String) {
		runZenity(buildBaseArgs('error', title, text));
	}

	public function question(title:String, text:String) {
		return new js.lib.Promise<Bool>((resolve, reject) -> {
			runZenity(buildBaseArgs('question', title, text)).then(response -> resolve(response == OK)).catchError(reject);
		});
	}

	public function selectFile(title:String, isDirectory:Bool = false, multiple:Bool = false, ?fileFilter:FileFilter):js.lib.Promise<Array<String>> {
		return new js.lib.Promise<Array<String>>((resolve, reject) -> {
			var args = buildBaseArgs('file-selection', title, '');
			if (isDirectory)
				args.push('--directory');
			if (multiple != null && multiple)
				args.push('--multiple');
			runZenity(args).then(response -> resolve(responseToArray(response))).catchError(reject);
		});
	}

	public function saveFile(title:String, ?saveName:String, ?fileFilter:FileFilter):js.lib.Promise<String> {
		var args = buildBaseArgs('file-selection', title, '');
		args.push('--save');
		args.push('-confirm-overwrite');
		if (saveName != null)
			args.push('--filename="${saveName}"');
		if (fileFilter != null) {
			var patterns = fileFilter.patterns.join(', ');
			var name = if (fileFilter.name != null && fileFilter.name != '') '${fileFilter.name} ($patterns)' else patterns;
			args.push('--file-filter=$name | ${fileFilter.patterns.join(' | ')}');
		}
		return runZenity(args);
	}

	public function entry(title:String, text:String, ?placeholder:String):js.lib.Promise<String> {
		var args = buildBaseArgs('entry', title, text);
		if (placeholder != null)
			args.push('--entry-text=${placeholder}');
		return runZenity(args);
	}

	public function password(title:String, text:String, showUsername:Bool = false):api.IdeckiaApi.Promise<Array<String>> {
		return new js.lib.Promise<Array<String>>((resolve, reject) -> {
			var args = buildBaseArgs('password', title, text);
			if (showUsername)
				args.push('--username');
			runZenity(args).then(response -> resolve(responseToArray(response))).catchError(reject);
		});
	}

	public function progress(title:String, text:String, pulsate:Bool = false, autoClose:Bool = true):Progress {
		var args = buildBaseArgs('progress', title, text);
		if (autoClose)
			args.push('--auto-close');
		if (pulsate)
			args.push('-pulsate');
		return new ZenityProgress(args);
	}

	public function color(title:String, initialColor:String = "#FFFFFF", palette:Bool = false):js.lib.Promise<Color> {
		return new js.lib.Promise<Color>((resolve, reject) -> {
			var args = buildBaseArgs('color-selection', title, '');
			args.push('--color=$initialColor');
			if (palette)
				args.push('--show-palette');
			runZenity(args).then(colorString -> resolve(colorString)).catchError(reject);
		});
	}

	public function calendar(title:String, text:String, ?year:UInt, ?month:UInt, ?day:UInt, ?dateFormat:String):js.lib.Promise<String> {
		var args = buildBaseArgs('calendar', title, text);
		if (year != null)
			args.push('--year=$year');
		if (month != null)
			args.push('--month=$month');
		if (day != null)
			args.push('--day=$day');
		if (dateFormat != null)
			args.push('--date-format=$dateFormat');

		return runZenity(args);
	}

	public function list(title:String, text:String, columnHeader:String, values:Array<String>, multiple:Bool = false):js.lib.Promise<Array<String>> {
		return new js.lib.Promise<Array<String>>((resolve, reject) -> {
			var args = buildBaseArgs('list', title, text);
			if (multiple)
				args.push('--multiple');
			args.push('--column="$columnHeader" ${values.map(v -> '"$v"').join(' ')}');
			runZenity(args).then(response -> resolve(responseToArray(response))).catchError(reject);
		});
	}

	function runZenity(args:Array<String>):js.lib.Promise<String> {
		return new js.lib.Promise<String>((resolve, reject) -> {
			var cp = js.node.ChildProcess.spawn(executablePath, args, {shell: true});

			var data = '';
			cp.stdout.on('data', d -> data += d);
			cp.stdout.on('end', d -> {
				var cleanData = cleanResponse(data);
				if (cleanData != '')
					resolve(cleanData);
			});
			var error = '';
			cp.stderr.on('data', e -> error += e);
			cp.stderr.on('end', e -> {
				if (error != '')
					reject(error);
			});

			cp.on('exit', (code) -> resolve(code == 0 ? OK : ''));
			cp.on('error', (error) -> reject(error));
		});
	}

	function buildBaseArgs(type:String, title:String, text:String, ?options:Options) {
		return ['--$type', '--title="$title"', '--text="$text"'].concat(buildWindowOptionArgs());
	}

	function buildWindowOptionArgs() {
		var args = [];

		args = args.concat(writeArgument('height', options.height))
			.concat(writeArgument('width', options.width))
			.concat(writeArgument('window-icon', options.windowIcon))
			.concat(writeArgument('icon-name', options.dialogIcon))
			.concat(writeArgument('ok-label', options.okLabel))
			.concat(writeArgument('cancel-label', options.cancelLabel))
			.concat(writeArgument('attach', options.parent));

		return args;
	}

	function writeArgument(argumentName:String, value:Any) {
		if (value == null)
			return [];
		return ['--$argumentName=$value'];
	}

	function cleanResponse(response:String) {
		return ~/\r?\n/g.replace(response, '');
	}

	function responseToArray(response:String) {
		return cleanResponse(response).split('|').filter(e -> e != '');
	}
}

@:access(Zenity)
class ZenityProgress implements Progress {
	var process:js.node.child_process.ChildProcess;

	public function new(args:Array<String>) {
		process = js.node.ChildProcess.spawn(Zenity.executablePath, args, {shell: true});
	}

	@:keep
	public function progress(percentage:UInt) {
		process.stdin.write('$percentage\n');
	}
}
