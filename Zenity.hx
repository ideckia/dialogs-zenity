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

@:expose('Dialog')
class Zenity implements Dialog {
	static var executablePath:String;

	var defaultOptions:WindowOptions;

	public function new() {
		var exceptionMessage = 'To use dialogs you must download "zenity" and put it in the lib folder. You can get it here: https://github.com/ncruces/zenity';
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
				exceptionMessage = 'To use dialogs you must download "zenity" from your package manager.';
				checkInstalation();
				return;
		}

		executablePath = haxe.io.Path.join([js.Node.__dirname, 'lib', filename]);
		checkInstalation();
		setDefaultOptions({
			height: 200,
			width: 300,
			windowIcon: '',
			dialogIcon: '',
			extraData: null
		});
	}

	public function setDefaultOptions(newOptions:WindowOptions) {
		defaultOptions = newOptions;
	}

	public function notify(title:String, text:String, ?options:WindowOptions) {
		runZenity(buildBaseArgs('notification', title, text, setDefaultWindowIcon(options, WindowIcon.info)));
	}

	public function info(title:String, text:String, ?options:WindowOptions) {
		runZenity(buildBaseArgs('info', title, text, setDefaultWindowIcon(options, WindowIcon.info)));
	}

	public function warning(title:String, text:String, ?options:WindowOptions) {
		runZenity(buildBaseArgs('warning', title, text, setDefaultWindowIcon(options, WindowIcon.warning)));
	}

	public function error(title:String, text:String, ?options:WindowOptions) {
		runZenity(buildBaseArgs('error', title, text, setDefaultWindowIcon(options, WindowIcon.error)));
	}

	public function question(title:String, text:String, ?options:WindowOptions) {
		return new js.lib.Promise<Bool>((resolve, reject) -> {
			runZenity(buildBaseArgs('question', title, text,
				setDefaultWindowIcon(options, WindowIcon.question))).then(response -> resolve(response == OK)).catchError(reject);
		});
	}

	public function selectFile(title:String, isDirectory:Bool = false, multiple:Bool = false, ?fileFilter:FileFilter,
			?options:WindowOptions):js.lib.Promise<Array<String>> {
		return new js.lib.Promise<Array<String>>((resolve, reject) -> {
			var args = buildBaseArgs('file-selection', title, '', options);
			if (isDirectory)
				args.push('--directory');
			if (multiple != null && multiple)
				args.push('--multiple');
			runZenity(args).then(response -> resolve(responseToArray(response))).catchError(reject);
		});
	}

	public function saveFile(title:String, ?saveName:String, ?fileFilter:FileFilter, ?options:WindowOptions):js.lib.Promise<String> {
		var args = buildBaseArgs('file-selection', title, '', options);
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

	public function entry(title:String, text:String, ?placeholder:String, ?options:WindowOptions):js.lib.Promise<String> {
		var args = buildBaseArgs('entry', title, text, options);
		if (placeholder != null)
			args.push('--entry-text=${placeholder}');
		return runZenity(args);
	}

	public function password(title:String, text:String, showUsername:Bool = false, ?options:WindowOptions):api.IdeckiaApi.Promise<Array<String>> {
		return new js.lib.Promise<Array<String>>((resolve, reject) -> {
			var args = buildBaseArgs('password', title, text, setDefaultWindowIcon(options, WindowIcon.password));
			if (showUsername)
				args.push('--username');
			runZenity(args).then(response -> resolve(responseToArray(response))).catchError(reject);
		});
	}

	public function progress(title:String, text:String, pulsate:Bool = false, autoClose:Bool = true, ?options:WindowOptions):Progress {
		var args = buildBaseArgs('progress', title, text, options);
		if (autoClose)
			args.push('--auto-close');
		if (pulsate)
			args.push('-pulsate');
		return new ZenityProgress(args);
	}

	public function color(title:String, initialColor:String = "#FFFFFF", palette:Bool = false, ?options:WindowOptions):js.lib.Promise<Color> {
		return new js.lib.Promise<Color>((resolve, reject) -> {
			var args = buildBaseArgs('color-selection', title, '', options);
			args.push('--color=$initialColor');
			if (palette)
				args.push('--show-palette');
			runZenity(args).then(colorString -> resolve(colorString)).catchError(reject);
		});
	}

	public function calendar(title:String, text:String, ?year:UInt, ?month:UInt, ?day:UInt, ?dateFormat:String,
			?options:WindowOptions):js.lib.Promise<String> {
		var args = buildBaseArgs('calendar', title, text, options);
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

	public function list(title:String, text:String, columnHeader:String, values:Array<String>, multiple:Bool = false,
			?options:WindowOptions):js.lib.Promise<Array<String>> {
		return new js.lib.Promise<Array<String>>((resolve, reject) -> {
			var args = buildBaseArgs('list', title, text, options);
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

	function buildBaseArgs(type:String, title:String, text:String, ?options:WindowOptions) {
		return ['--$type', '--title="$title"', '--text="$text"'].concat(buildWindowOptionArgs(options));
	}

	function buildWindowOptionArgs(?options:WindowOptions) {
		return [].concat(writeArgument('height', options, 'height'))
			.concat(writeArgument('width', options, 'width'))
			.concat(writeArgument('window-icon', options, 'windowIcon'))
			.concat(writeArgument('icon-name', options, 'dialogIcon'))
			.concat(writeArgument('ok-label', options, 'okLabel'))
			.concat(writeArgument('cancel-label', options, 'cancelLabel'));
	}

	function writeArgument(argumentName:String, options:WindowOptions, fieldName:String) {
		var value = Reflect.field(options, fieldName);
		var defValue = Reflect.field(defaultOptions, fieldName);
		inline function isBlank(s:String)
			return s == null || StringTools.trim(s) == '';
		if (isBlank(value) && isBlank(defValue))
			return [];
		else if (isBlank(value))
			return ['--$argumentName=$defValue'];
		else
			return ['--$argumentName=$value'];
	}

	function setDefaultWindowIcon(?options:WindowOptions, defaultIcon:WindowIcon):WindowOptions {
		if (options == null)
			return {windowIcon: defaultIcon};

		// If it is null, this will not override with default. We assume that the user wants to be empty
		if (options.windowIcon == '')
			options.windowIcon = defaultIcon;

		return options;
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
